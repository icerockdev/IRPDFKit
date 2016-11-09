//
//  Created by Aleksey Mikhailov on 10/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit
import CoreGraphics

public class IRPDFDocumentView: UIView {

  public var pdfDocument: CGPDFDocument? {
    didSet {
      calculatePageFrames()
    }
  }
  public var highlightedSearchResults: [IRPDFSearchResult]? {
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
      tiledLayer.tileSize = CGSizeMake(1024, 1024)
      tiledLayer.levelsOfDetail = 5
      tiledLayer.levelsOfDetailBias = 4
    }
  }
  
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override class func layerClass() -> AnyClass {
    return IRPDFTiledLayer.self
  }
  
  public override func drawRect(rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext(), let pageFrames = pageFrames else {
      return
    }
    
    let scale = CGContextGetCTM(context).a
    
    for pageRectIdx in (0 ... (pageFrames.count - 1)) {
      let pageRect = pageFrames[pageRectIdx]
      
      if pageRect.intersects(rect) {
        drawPage(context, page: UInt(pageRectIdx), scale: scale)
      }
    }
  }
  
  func drawPage(context: CGContext, page: UInt, scale: CGFloat) {
    guard let pageFrames = pageFrames, let pdfDocument = pdfDocument else {
      return
    }
    
    let rect = pageFrames[Int(page)]
    
    let pdfPage = CGPDFDocumentGetPage(pdfDocument, Int(page + 1))!
    
    renderPDFPage(pdfPage, frame: rect, context: context, scale: scale, pageNumber: Int(page))
  }
  
  func calculatePageFrames() {
    guard let pdfDocument = pdfDocument else {
      pageFrames = nil
      return
    }
    
    var currentY: CGFloat = 0
    
    pageFrames = []
    
    for pageIdx in (1 ... CGPDFDocumentGetNumberOfPages(pdfDocument)) {
      let page = CGPDFDocumentGetPage(pdfDocument, pageIdx)!
      
      let cropBox = CGPDFPageGetBoxRect(page, CGPDFBox.CropBox)
      let rotate = abs(CGPDFPageGetRotationAngle(page))
      
      let pageRect: CGRect
      if rotate == 90 || rotate == 270 {
        pageRect = CGRectMake(cropBox.origin.x, cropBox.origin.y, cropBox.height, cropBox.width)
      } else {
        pageRect = cropBox
      }
      
      let mpl = bounds.width / pageRect.width
      
      let rect = CGRectMake(0, currentY, bounds.width, pageRect.height * mpl)
      
      currentY += rect.height
      
      pageFrames?.append(rect)
    }
    
    invalidateIntrinsicContentSize()
  }
  
  func renderPDFPage(page: CGPDFPageRef, frame: CGRect, context: CGContext, scale: CGFloat, pageNumber: Int) {
    let cropBox = CGPDFPageGetBoxRect(page, CGPDFBox.CropBox)
    let rotate = CGPDFPageGetRotationAngle(page)
    
    CGContextSetInterpolationQuality(context, CGInterpolationQuality.High)
    CGContextSetRenderingIntent(context, CGColorRenderingIntent.RenderingIntentDefault)
    
    CGContextSaveGState(context)
    
    let baseScale: CGFloat
    if abs(rotate) == 90 || abs(rotate) == 270 {
      baseScale = (bounds.width / cropBox.height)
    } else {
      baseScale = (bounds.width / cropBox.width)
    }
    
    CGContextTranslateCTM(context, frame.origin.x, frame.origin.y)
    
    CGContextScaleCTM(context, baseScale, baseScale);
    
    switch (rotate) {
    case 0:
      CGContextTranslateCTM(context, 0, cropBox.size.height);
      CGContextScaleCTM(context, 1, -1);
    case 90:
      CGContextScaleCTM(context, 1, -1);
      CGContextRotateCTM(context, -CGFloat(M_PI) / 2.0);
    case 180, -180:
      CGContextScaleCTM(context, 1, -1);
      CGContextTranslateCTM(context, cropBox.size.width, 0);
      CGContextRotateCTM(context, CGFloat(M_PI) * 1.0);
    case 270, -90:
      CGContextTranslateCTM(context, cropBox.size.height, cropBox.size.width);
      CGContextRotateCTM(context, CGFloat(M_PI) / 2.0);
      CGContextScaleCTM(context, -1, 1);
    default:
      break
    }
    
    let clipRect = CGRectMake(0, 0, cropBox.size.width, cropBox.size.height);
    CGContextAddRect(context, clipRect);
    CGContextClip(context);
    
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, clipRect);
    
    CGContextTranslateCTM(context, -cropBox.origin.x, -cropBox.origin.y)
    
    CGContextDrawPDFPage(context, page);
    
    // draw highlights
    if let highlights = highlightedSearchResults {
      let highlightColor = UIColor.yellowColor().CGColor
      
      CGContextSetFillColorWithColor(context, highlightColor)
      CGContextSetBlendMode(context, CGBlendMode.Multiply)
      
      if highlights.count > 0 {
        for i in (0 ... highlights.count - 1) {
          let searchResult = highlights[i]
          if searchResult.page != (pageNumber + 1) {
            continue
          }
          
          for part in searchResult.parts {
            let transform = CGAffineTransformMake(CGFloat(part.transform[0]),
                                                  CGFloat(part.transform[1]),
                                                  CGFloat(part.transform[2]),
                                                  CGFloat(part.transform[3]),
                                                  CGFloat(part.transform[4]),
                                                  CGFloat(part.transform[5]))
            
            CGContextSaveGState(context)
            
            CGContextConcatCTM(context, transform)
            
            let partScale = (1.0 / part.height)
            let startX = CGFloat(part.startX * partScale)
            let width = CGFloat((part.endX - part.startX) * partScale)
            
            CGContextFillRect(context, CGRectMake(startX, 0, width, 1))
            CGContextRestoreGState(context)
          }
        }
      }
    }
    
    CGContextRestoreGState(context);
  }
  
  public override func intrinsicContentSize() -> CGSize {
    
    var maxY: CGFloat = 0
    
    for rect in (pageFrames ?? []) {
      if maxY < rect.maxY {
        maxY = rect.maxY
      }
    }
    
    return CGSizeMake(bounds.width, maxY)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    calculatePageFrames()
    
    if let tiledLayer = layer as? CATiledLayer {
      tiledLayer.contents = nil
      tiledLayer.setNeedsDisplay()
    }
  }
}
