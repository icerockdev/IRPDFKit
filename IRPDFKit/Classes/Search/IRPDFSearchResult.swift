//
//  Created by Aleksey Mikhailov on 12/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation

public struct IRPDFSearchResultPart: Equatable {
  public let startX: Float
  public let endX: Float
  public let width: Float
  public let height: Float
  public let transform: [Float]
  
  public init(startX: Float, endX: Float, width: Float, height: Float, transform: [Float]) {
    self.startX = startX
    self.endX = endX
    self.width = width
    self.height = height
    self.transform = transform
  }
}

public struct IRPDFSearchResult: Equatable {
  public let page: Int
  public let contextString: String
  public let queryInContextRange: Range<String.Index>
  public let startPosition: Int
  public let endPosition: Int
  public let parts: [IRPDFSearchResultPart]
  
  public init(page: Int,
              contextString: String,
              queryInContextRange: Range<String.Index>,
              startPosition: Int,
              endPosition: Int,
              parts: [IRPDFSearchResultPart]) {
    self.page = page
    self.contextString = contextString
    self.queryInContextRange = queryInContextRange
    self.startPosition = startPosition
    self.endPosition = endPosition
    self.parts = parts
  }
}

public func ==(lhs: IRPDFSearchResult, rhs: IRPDFSearchResult) -> Bool {
  if lhs.page != rhs.page {
    return false
  }
  
  if lhs.contextString != rhs.contextString {
    return false
  }
  
  if lhs.queryInContextRange != rhs.queryInContextRange {
    return false
  }
  
  if lhs.startPosition != rhs.startPosition {
    return false
  }
  
  if lhs.endPosition != rhs.endPosition {
    return false
  }
  
  if lhs.parts.count != rhs.parts.count {
    return false
  }
  
  if lhs.parts.count > 0 {
    for i in (0 ... lhs.parts.count - 1) {
      if lhs.parts[i] != rhs.parts[i] {
        return false
      }
    }
  }

  return true
}

public func ==(lhs: IRPDFSearchResultPart, rhs: IRPDFSearchResultPart) -> Bool {
  if lhs.startX != rhs.startX {
    return false
  }
  
  if lhs.endX != rhs.endX {
    return false
  }
  
  if lhs.width != rhs.width {
    return false
  }
  
  if lhs.height != rhs.height {
    return false
  }
  
  if lhs.transform != rhs.transform {
    return false
  }
  
  return true
}
