//
//  Created by Aleksey Mikhailov on 10/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit
import CoreGraphics
import JASON

public class IRPDFDocumentViewController: UIViewController {
  @IBOutlet weak var pdfPagesScrollView: UIScrollView!
  
  public var pdfDocumentUrl: NSURL? {
    didSet {
      if let url = pdfDocumentUrl {
        pdfDocument = CGPDFDocumentCreateWithURL(url)
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
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    if pdfPagesScrollView == nil {
      let scrollView = UIScrollView(frame: view.bounds)
      view.addSubview(scrollView)
      
      pdfPagesScrollView = scrollView
      
      pdfPagesScrollView.scrollEnabled = true
      pdfPagesScrollView.bounces = true
      pdfPagesScrollView.alwaysBounceVertical = true
      pdfPagesScrollView.backgroundColor = UIColor.groupTableViewBackgroundColor()
      pdfPagesScrollView.showsVerticalScrollIndicator = true
      pdfPagesScrollView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
      pdfPagesScrollView.maximumZoomScale = 8
      pdfPagesScrollView.minimumZoomScale = 1
    }
    
    pdfPagesScrollView.delegate = self
  }
  
  public func reloadData() {
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
      attribute: .Top, relatedBy: .Equal, toItem: pdfView,
      attribute: .Top, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .Bottom, relatedBy: .Equal, toItem: pdfView,
      attribute: .Bottom, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .CenterX, relatedBy: .Equal, toItem: pdfView,
      attribute: .CenterX, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .Leading, relatedBy: .Equal, toItem: pdfView,
      attribute: .Leading, multiplier: 1, constant: 0))
    
    pdfPagesScrollView.addConstraint(NSLayoutConstraint(item: pdfPagesScrollView,
      attribute: .Trailing, relatedBy: .Equal, toItem: pdfView,
      attribute: .Trailing, multiplier: 1, constant: 0))
  }

  public func search(_ query: String) {
    searchEngine?.search(query) {
      [weak self] (_, searchResults) in
      
      self?.pdfView.highlightedSearchResults = searchResults
    }
  }
  
  public func presentSearchViewController(anchor: UIBarButtonItem) {
    guard let _ = searchEngine else {
      return
    }
    
    let searchViewController = IRPDFSearchResultsViewController()
    searchViewController.searchDelegate = self
    searchViewController.searchEngine = searchEngine
    searchViewController.searchQuery = lastSearchQuery
    searchViewController.modalPresentationStyle = .Popover
    searchViewController.popoverPresentationController?.barButtonItem = anchor
    
    presentViewController(searchViewController, animated: true, completion: nil)
  }
}

extension IRPDFDocumentViewController: UIScrollViewDelegate {
  public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
    return scrollView.subviews[0]
  }
}

extension IRPDFDocumentViewController: IRPDFSearchResultsDelegate {
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   receiveResults results: [IRPDFSearchResult]?) {
    pdfView.highlightedSearchResults = results
  }
  
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   didSelectResult result: IRPDFSearchResult) {
    pdfView.highlightedSearchResults = [result]
    
    if let frame = pdfView.pageFrames?[result.page - 1] {
      pdfPagesScrollView.zoomScale = 1.0
      pdfPagesScrollView.contentOffset = frame.origin
    }
  }
  
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   queryChanged query: String?) {
    lastSearchQuery = query
  }
}
