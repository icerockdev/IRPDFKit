//
//  Created by Михайлов Алексей on 18.10.16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation
import JASON

public class IRPDFSearchEngine {
  internal lazy var workQueue:NSOperationQueue = {
    var queue = NSOperationQueue()
    queue.name = "IRPDF search engine queue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  internal var readContentOperation: NSOperation?
  internal var searchOperation: NSOperation?
  
  internal var pages: [IRPDFPageData]?
  
  internal let documentUrl: NSURL
  
  public init(documentUrl: NSURL) {
    self.documentUrl = documentUrl
  }
  
  deinit {
    searchOperation?.cancel()
    readContentOperation?.cancel()
  }
  
  public func search(_ query: String, closure: ((String, [IRPDFSearchResult]) -> Void)) {
    searchOperation?.cancel()
    
    searchOperation = IRPDFSearchOperation(searchEngine: self, query: query, closure: closure)
    
    if pages == nil {
      if readContentOperation == nil {
        readContentOperation = IRPDFReadContentOperation(searchEngine: self)
        workQueue.addOperation(readContentOperation!)
      }
      
      searchOperation!.addDependency(readContentOperation!)
    }
    
    workQueue.addOperation(searchOperation!)
  }
}

class IRPDFReadContentOperation: NSOperation {
  weak var searchEngine: IRPDFSearchEngine?
  
  init(searchEngine: IRPDFSearchEngine) {
    self.searchEngine = searchEngine
  }
  
  override func main() {
    if cancelled {
      return
    }
    
    var results: String? = nil
    var webView: UIWebView!
    
    dispatch_sync(dispatch_get_main_queue()) {
      webView = UIWebView()
      let bundle = NSBundle(forClass: IRPDFReadContentOperation.self)
      let pdfJsIndexUrl = bundle.URLForResource("index",
                                                withExtension: "html",
                                                subdirectory: "IRPDFKit.bundle")!
      
      guard let searchEngine = self.searchEngine else {
        return
      }
      
      let pdfFilePath = searchEngine.documentUrl
        .absoluteString!
        .stringByReplacingOccurrencesOfString("file://", withString: "")
      
      let urlWithFile = "\(pdfJsIndexUrl.absoluteString!)?file=\(pdfFilePath)"
      webView.loadRequest(NSURLRequest(URL: NSURL(string: urlWithFile)!))
    }
    
    if searchEngine == nil {
      return
    }
    
    while results == nil && !cancelled  {
      dispatch_sync(dispatch_get_main_queue()) {
        let result = webView.stringByEvaluatingJavaScriptFromString("documentData")
        if let result = result where result != "" {
          results = result
        }
      }
      
      NSThread.sleepForTimeInterval(0.1)
    }
    
    if cancelled {
      return
    }
    
    let json = JSON(results!.dataUsingEncoding(NSUTF8StringEncoding))
    
    searchEngine?.pages = json.map { return IRPDFPageData($0) }
    searchEngine?.readContentOperation = nil
  }
}

class IRPDFSearchOperation: NSOperation {
  weak var searchEngine: IRPDFSearchEngine?
  let query: String
  let closure: ((String, [IRPDFSearchResult]) -> Void)
  
  init(searchEngine: IRPDFSearchEngine, query: String, closure: ((String, [IRPDFSearchResult]) -> Void)) {
    self.searchEngine = searchEngine
    self.query = query
    self.closure = closure
  }
  
  override func main() {
    guard let pages = searchEngine?.pages else {
      return
    }
    
    var searchResults = [IRPDFSearchResult]()
    
    for page in pages {
      let str = page.textContent
      var start = str.startIndex
      
      while true {
        if start == str.endIndex {
          break
        }
        
        let range = str
          .rangeOfString(query,
                         options: NSStringCompareOptions.CaseInsensitiveSearch,
                         range: start ... str.endIndex.advancedBy(-1),
                         locale: nil)
        
        guard let resultRange = range else {
          break
        }
        
        start = resultRange.endIndex
        
        let startPosition = str.startIndex.distanceTo(resultRange.startIndex)
        let endPosition = str.startIndex.distanceTo(resultRange.endIndex)
        
        var parts = [IRPDFSearchResultPart]()
        
        for textData in page.textData {
          if textData.startPosition > endPosition {
            break
          }
          
          // check if text in range
          let textDataEndPosition = textData.startPosition + textData.length
          
          let startInRange = startPosition >= textData.startPosition &&
            startPosition < textDataEndPosition
          let endInRange = endPosition > textData.startPosition &&
            endPosition <= textDataEndPosition
          let fullInRange = startPosition < textData.startPosition && endPosition > textDataEndPosition
          
          if !startInRange && !endInRange && !fullInRange {
            continue
          }
          
          var startX: Float = 0
          var endX: Float = textData.width
          var width: Float = textData.width
          var height: Float = textData.height
          var transform: [Float] = textData.transform
          
          let text = textData.text
          let start: Int
          let end: Int
          
          if startInRange {
            start = startPosition - textData.startPosition
          } else {
            start = 0
          }
          
          if endInRange && startInRange {
            end = start + range!.count
          } else if endInRange {
            end = range!.count - (textData.startPosition - startPosition)
          } else {
            end = textData.length
          }

          if start > 0 {
            for i in (0 ... start - 1) {
              startX += textData.charsWidths[i]
            }
          }
          
          endX = startX
          
          if start < end {
            for i in (start ... end - 1) {
              endX += textData.charsWidths[i]
            }
          }
          
          let charWidth: Float = width / Float(textData.length)
          
          parts.append(IRPDFSearchResultPart(startX: startX,
            endX: endX, width: width, height: height, transform: transform))
        }
        
        let start: String.Index
        if startPosition > 10 {
          start = resultRange.startIndex.advancedBy(-10)
        } else {
          start = resultRange.startIndex
        }
        
        let contextString = page.textContent.substringFromIndex(start)
        let queryRange = contextString.rangeOfString(query, options: NSStringCompareOptions.CaseInsensitiveSearch, locale: nil)!
        
        let searchResult = IRPDFSearchResult(page: page.number,
                                             contextString: contextString,
                                             queryInContextRange: queryRange,
                                             startPosition: startPosition,
                                             endPosition: endPosition,
                                             parts: parts)
        
        searchResults.append(searchResult)
      }
    }
    
    if cancelled {
      return
    }
    
    dispatch_sync(dispatch_get_main_queue()) {
      self.closure(query, searchResults)
    }
  }
}
