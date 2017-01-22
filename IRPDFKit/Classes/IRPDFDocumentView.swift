//
//  Created by Aleksey Mikhailov on 10/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit
import CoreGraphics

open class IRPDFDocumentView: UIView {

  open var pdfDocument: CGPDFDocument? {
    didSet {
      calculatePageFrames()
    }
  }
  open var highlightedSearchResults: [IRPDFSearchResult]? {
    didSet {
      let old = oldValue ?? []
      let new = highlightedSearchResults ?? []
      
      if old == new {
        return
      }
      
      if let tiledLayer = layer as? CATiledLayer {
        tiledLayer.setNeedsDisplay()
      }
    }
  }
  internal var pageFrames: [CGRect]?
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    
    if let tiledLayer = layer as? CATiledLayer {
      tiledLayer.tileSize = CGSize(width: 1024, height: 1024)
      tiledLayer.levelsOfDetail = 5
      tiledLayer.levelsOfDetailBias = 4
    }
  }
  
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  open override class var layerClass : AnyClass {
    return IRPDFTiledLayer.self
  }
  
  open override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext(), let pageFrames = pageFrames else {
      return
    }
    
    let scale = context.ctm.a
    
    for pageRectIdx in (0 ... (pageFrames.count - 1)) {
      let pageRect = pageFrames[pageRectIdx]
      
      if pageRect.intersects(rect) {
        drawPage(context, page: UInt(pageRectIdx), scale: scale)
      }
    }
  }
  
  func drawPage(_ context: CGContext, page: UInt, scale: CGFloat) {
    guard let pageFrames = pageFrames, let pdfDocument = pdfDocument else {
      return
    }
    
    let rect = pageFrames[Int(page)]
    
    let pdfPage = pdfDocument.page(at: Int(page + 1))!
    
    renderPDFPage(pdfPage, frame: rect, context: context, scale: scale, pageNumber: Int(page))
  }
  
  func calculatePageFrames() {
    guard let pdfDocument = pdfDocument else {
      pageFrames = nil
      return
    }
    
    var currentY: CGFloat = 0
    
    pageFrames = []
    
    for pageIdx in (1 ... pdfDocument.numberOfPages) {
      let page = pdfDocument.page(at: pageIdx)!
      
      let cropBox = page.getBoxRect(CGPDFBox.cropBox)
      let rotate = abs(page.rotationAngle)
      
      let pageRect: CGRect
      if rotate == 90 || rotate == 270 {
        pageRect = CGRect(x: cropBox.origin.x, y: cropBox.origin.y, width: cropBox.height, height: cropBox.width)
      } else {
        pageRect = cropBox
      }
      
      let mpl = bounds.width / pageRect.width
      
      let rect = CGRect(x: 0, y: currentY, width: bounds.width, height: pageRect.height * mpl)
      
      currentY += rect.height
      
      pageFrames?.append(rect)
    }
    
    invalidateIntrinsicContentSize()
  }
  
  func renderPDFPage(_ page: CGPDFPage, frame: CGRect, context: CGContext, scale: CGFloat, pageNumber: Int) {
    let cropBox = page.getBoxRect(CGPDFBox.cropBox)
    let rotate = page.rotationAngle
    
    context.interpolationQuality = CGInterpolationQuality.high
    context.setRenderingIntent(CGColorRenderingIntent.defaultIntent)
    
    context.saveGState()
    
    let baseScale: CGFloat
    if abs(rotate) == 90 || abs(rotate) == 270 {
      baseScale = (bounds.width / cropBox.height)
    } else {
      baseScale = (bounds.width / cropBox.width)
    }
    
    context.translateBy(x: frame.origin.x, y: frame.origin.y)
    
    context.scaleBy(x: baseScale, y: baseScale);
    
    switch (rotate) {
    case 0:
      context.translateBy(x: 0, y: cropBox.size.height);
      context.scaleBy(x: 1, y: -1);
    case 90:
      context.scaleBy(x: 1, y: -1);
      context.rotate(by: -CGFloat(M_PI) / 2.0);
    case 180, -180:
      context.scaleBy(x: 1, y: -1);
      context.translateBy(x: cropBox.size.width, y: 0);
      context.rotate(by: CGFloat(M_PI) * 1.0);
    case 270, -90:
      context.translateBy(x: cropBox.size.height, y: cropBox.size.width);
      context.rotate(by: CGFloat(M_PI) / 2.0);
      context.scaleBy(x: -1, y: 1);
    default:
      break
    }
    
    let clipRect = CGRect(x: 0, y: 0, width: cropBox.size.width, height: cropBox.size.height);
    context.addRect(clipRect);
    context.clip();
    
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1);
    context.fill(clipRect);
    
    context.translateBy(x: -cropBox.origin.x, y: -cropBox.origin.y)
    
    context.drawPDFPage(page);
    
    // draw highlights
    if let highlights = highlightedSearchResults {
      let highlightColor = UIColor.yellow.cgColor
      
      context.setFillColor(highlightColor)
      context.setBlendMode(CGBlendMode.multiply)
      
      if highlights.count > 0 {
        for i in (0 ... highlights.count - 1) {
          let searchResult = highlights[i]
          if searchResult.page != (pageNumber + 1) {
            continue
          }
          
          for part in searchResult.parts {
            let transform = CGAffineTransform(a: CGFloat(part.transform[0]),
                                                  b: CGFloat(part.transform[1]),
                                                  c: CGFloat(part.transform[2]),
                                                  d: CGFloat(part.transform[3]),
                                                  tx: CGFloat(part.transform[4]),
                                                  ty: CGFloat(part.transform[5]))
            
            context.saveGState()
            
            context.concatenate(transform)
            
            let partScale = (1.0 / part.height)
            let startX = CGFloat(part.startX * partScale)
            let width = CGFloat((part.endX - part.startX) * partScale)
            
            context.fill(CGRect(x: startX, y: 0, width: width, height: 1))
            context.restoreGState()
          }
        }
      }
    }
    
    context.restoreGState();
  }
  
  open override var intrinsicContentSize : CGSize {
    
    var maxY: CGFloat = 0
    
    for rect in (pageFrames ?? []) {
      if maxY < rect.maxY {
        maxY = rect.maxY
      }
    }
    
    return CGSize(width: bounds.width, height: maxY)
  }
  
  open override func layoutSubviews() {
    super.layoutSubviews()
    
    calculatePageFrames()
    
    if let tiledLayer = layer as? CATiledLayer {
      tiledLayer.contents = nil
      tiledLayer.setNeedsDisplay()
    }
  }
}
