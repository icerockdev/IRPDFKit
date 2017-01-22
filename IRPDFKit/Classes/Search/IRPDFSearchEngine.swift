//
//  Created by Михайлов Алексей on 18.10.16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation
import JASON

open class IRPDFSearchEngine {
  internal lazy var workQueue:OperationQueue = {
    var queue = OperationQueue()
    queue.name = "IRPDF search engine queue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  internal var readContentOperation: Operation?
  internal var searchOperation: Operation?
  
  internal var pages: [IRPDFPageData]?
  
  internal let documentUrl: URL
  
  public init(documentUrl: URL) {
    self.documentUrl = documentUrl
  }
  
  deinit {
    searchOperation?.cancel()
    readContentOperation?.cancel()
  }
  
  open func search(_ query: String, closure: @escaping ((String, [IRPDFSearchResult]) -> Void)) {
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

class IRPDFReadContentOperation: Operation {
  weak var searchEngine: IRPDFSearchEngine?
  
  init(searchEngine: IRPDFSearchEngine) {
    self.searchEngine = searchEngine
  }
  
  override func main() {
    if isCancelled {
      return
    }
    
    var results: String? = nil
    var webView: UIWebView!
    
    DispatchQueue.main.sync {
      webView = UIWebView()
      let bundle = Bundle(for: IRPDFReadContentOperation.self)
      let pdfJsIndexUrl = bundle.url(forResource: "index",
                                                withExtension: "html",
                                                subdirectory: "IRPDFKit.bundle")!
      
      guard let searchEngine = self.searchEngine else {
        return
      }
      
      let pdfFilePath = searchEngine.documentUrl
        .absoluteString
        .replacingOccurrences(of: "file://", with: "")
      
      let urlWithFile = "\(pdfJsIndexUrl.absoluteString)?file=\(pdfFilePath)"
      webView.loadRequest(URLRequest(url: URL(string: urlWithFile)!))
    }
    
    if searchEngine == nil {
      return
    }
    
    while results == nil && !isCancelled  {
      DispatchQueue.main.sync {
        let result = webView.stringByEvaluatingJavaScript(from: "documentData")
        if let result = result, result != "" {
          results = result
        }
      }
      
      Thread.sleep(forTimeInterval: 0.1)
    }
    
    if isCancelled {
      return
    }
    
    let json = JSON(results!.data(using: String.Encoding.utf8))
    
    searchEngine?.pages = json.map { return IRPDFPageData($0) }
    searchEngine?.readContentOperation = nil
  }
}

class IRPDFSearchOperation: Operation {
  weak var searchEngine: IRPDFSearchEngine?
  let query: String
  let closure: ((String, [IRPDFSearchResult]) -> Void)
  
  init(searchEngine: IRPDFSearchEngine, query: String, closure: @escaping ((String, [IRPDFSearchResult]) -> Void)) {
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
          .range(of: query,
                         options: NSString.CompareOptions.caseInsensitive,
                         range: start..<str.endIndex,
                         locale: nil)
        
        guard let resultRange = range else {
          break
        }
        
        start = resultRange.upperBound
        
        let startPosition = str.characters.distance(from: str.startIndex, to: resultRange.lowerBound)
        let endPosition = str.characters.distance(from: str.startIndex, to: resultRange.upperBound)
        
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
          
          let rangeLen = endPosition - startPosition
          
          if endInRange && startInRange {
            end = start + rangeLen
          } else if endInRange {
            end = rangeLen - (textData.startPosition - startPosition)
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
          start = str.index(resultRange.lowerBound, offsetBy: -10)
        } else {
          start = resultRange.lowerBound
        }
        
        let contextString = page.textContent.substring(from: start)
        let queryRange = contextString.range(of: query, options: NSString.CompareOptions.caseInsensitive, locale: nil)!
        
        let searchResult = IRPDFSearchResult(page: page.number,
                                             contextString: contextString,
                                             queryInContextRange: queryRange,
                                             startPosition: startPosition,
                                             endPosition: endPosition,
                                             parts: parts)
        
        searchResults.append(searchResult)
      }
    }
    
    if isCancelled {
      return
    }
    
    DispatchQueue.main.sync {
      self.closure(query, searchResults)
    }
  }
}
