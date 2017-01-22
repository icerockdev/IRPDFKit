//
//  Created by Aleksey Mikhailov on 10/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit
import CoreGraphics
import JASON

open class IRPDFDocumentViewController: UIViewController {
  @IBOutlet weak var pdfPagesScrollView: UIScrollView!
  
  open var pdfDocumentUrl: URL? {
    didSet {
      if let url = pdfDocumentUrl {
        pdfDocument = CGPDFDocument(url as CFURL)
        searchEngine = IRPDFSearchEngine(documentUrl: url)
      } else {
        pdfDocument = nil
        searchEngine = nil
      }
    }
  }
  
  var pdfDocument: CGPDFDocument? {
    didSet {
      reloadData()
    }
  }
  var pdfView: IRPDFDocumentView!
  var searchEngine: IRPDFSearchEngine?
  var lastSearchQuery: String?
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    
    if pdfPagesScrollView == nil {
      let scrollView = UIScrollView(frame: view.bounds)
      view.addSubview(scrollView)
      
      pdfPagesScrollView = scrollView
      
      pdfPagesScrollView.isScrollEnabled = true
      pdfPagesScrollView.bounces = true
      pdfPagesScrollView.alwaysBounceVertical = true
      pdfPagesScrollView.backgroundColor = UIColor.groupTableViewBackground
      pdfPagesScrollView.showsVerticalScrollIndicator = true
      pdfPagesScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      pdfPagesScrollView.maximumZoomScale = 8
      pdfPagesScrollView.minimumZoomScale = 1
    }
    
    pdfPagesScrollView.delegate = self
    
    let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(doubleTapGesture))
    doubleTapGestureRecognizer.numberOfTapsRequired = 2
    
    pdfPagesScrollView.addGestureRecognizer(doubleTapGestureRecognizer)
  }
  
  open func reloadData() {
    guard let _ = pdfPagesScrollView else {
      return
    }
    
    for view in pdfPagesScrollView.subviews {
      view.removeFromSuperview()
    }
    
    guard let pdfDocument = pdfDocument else {
      return
    }
    
    pdfView = IRPDFDocumentView(frame: pdfPagesScrollView.bounds)
    pdfView.pdfDocument = pdfDocument
    pdfView.translatesAutoresizingMaskIntoConstraints = false
    
    pdfPagesScrollView.addSubview(pdfView)
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .top, relatedBy: .equal, toItem: pdfView,
      attribute: .top, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .bottom, relatedBy: .equal, toItem: pdfView,
      attribute: .bottom, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .centerX, relatedBy: .equal, toItem: pdfView,
      attribute: .centerX, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .leading, relatedBy: .equal, toItem: pdfView,
      attribute: .leading, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .trailing, relatedBy: .equal, toItem: pdfView,
      attribute: .trailing, multiplier: 1, constant: 0))
  }

  open func search(_ query: String) {
    searchEngine?.search(query) {
      [weak self] (_, searchResults) in
      
      self?.pdfView.highlightedSearchResults = searchResults
    }
  }
  
  open func presentSearchViewController(_ anchor: UIBarButtonItem) {
    guard let _ = searchEngine else {
      return
    }
    
    let searchViewController = IRPDFSearchResultsViewController()
    searchViewController.searchDelegate = self
    searchViewController.searchEngine = searchEngine
    searchViewController.searchQuery = lastSearchQuery
    searchViewController.modalPresentationStyle = .popover
    searchViewController.popoverPresentationController?.barButtonItem = anchor
    
    present(searchViewController, animated: true, completion: nil)
  }
}

extension IRPDFDocumentViewController {
  func doubleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
    
    let zoomScale: CGFloat
    if pdfPagesScrollView.zoomScale > pdfPagesScrollView.minimumZoomScale {
      zoomScale = pdfPagesScrollView.minimumZoomScale
    } else {
      zoomScale = pdfPagesScrollView.maximumZoomScale
    }
    
    pdfPagesScrollView.setZoomScale(zoomScale, animated: true)
  }
}

extension IRPDFDocumentViewController: UIScrollViewDelegate {
  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return scrollView.subviews[0]
  }
}

extension IRPDFDocumentViewController: IRPDFSearchResultsDelegate {
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
                                   receiveResults results: [IRPDFSearchResult]?) {
    pdfView.highlightedSearchResults = results
  }
  
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
                                   didSelectResult result: IRPDFSearchResult) {
    pdfView.highlightedSearchResults = [result]
    
    if let frame = pdfView.pageFrames?[result.page - 1] {
      pdfPagesScrollView.zoomScale = 1.0
      pdfPagesScrollView.contentOffset = frame.origin
    }
  }
  
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
                                   queryChanged query: String?) {
    lastSearchQuery = query
  }
}
