//
//  Created by Aleksey Mikhailov on 11/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation
import JASON

public struct IRPDFPageData {
  public let number: Int
  public let textData: [IRPDFTextData]
  public let textContent: String
  
  init(_ json: JSON) {
    number = json["page"].intValue
    
    var content = ""
    if let items = json["content"].jsonDictionary?["items"]?.jsonArray {
      textData = items.map { (json: JSON) -> IRPDFTextData in
        let result = IRPDFTextData(json, startPosition: content.characters.count)
        content += result.text
        return result
      }
    } else {
      textData = []
    }
    
    textContent = content
  }
}
