//
//  Created by Aleksey Mikhailov on 11/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation
import JASON

public struct IRPDFTextData {
  public let text: String
  public let direction: String
  public let width: Float
  public let height: Float
  public let transform: [Float]
  public let startPosition: Int
  public let charsWidths: [Float]
  
  public var length: Int {
    get {
      return text.characters.count
    }
  }
  
  init(_ json: JSON, startPosition: Int) {
    text = json["str"].stringValue
    direction = json["dir"].stringValue
    width = json["width"].floatValue
    height = json["height"].floatValue
    
    // https://github.com/mozilla/pdf.js/blob/7f381c8064f7f67668892130f5f7f818658098ca/src/core/evaluator.js#L1139
    if let trfm = json["transform"].jsonArray {
      transform = trfm.map { return $0.floatValue }
    } else {
      transform = [1, 0, 0, 1, 0, 0]
    }
    
    if let widths = json["strCharsWidths"].jsonArray {
      charsWidths = widths.map{ return $0.floatValue }
    } else {
      charsWidths = []
    }
    
    self.startPosition = startPosition
  }
}
