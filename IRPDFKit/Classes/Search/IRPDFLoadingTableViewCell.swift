//
//  Created by Aleksey Mikhailov on 19/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import Foundation

class IRPDFLoadingTableViewCell: UITableViewCell {
  let activityIndicator: UIActivityIndicatorView
  
  init(reuseIdentifier identifier: String?) {
    activityIndicator = UIActivityIndicatorView()
    activityIndicator.hidesWhenStopped = false
    activityIndicator.isHidden = false
    activityIndicator.color = UIColor.black
    
    super.init(style: .default, reuseIdentifier: identifier)
    
    contentView.addSubview(activityIndicator)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let rect = contentView.bounds
    let itemSize = activityIndicator.bounds.size
    let halfItemSize = CGSize(width: itemSize.width / 2.0, height: itemSize.height / 2.0)
    
    activityIndicator.frame = CGRect(x: rect.width / 2.0 - halfItemSize.width,
                                         y: rect.height / 2.0 - halfItemSize.height,
                                         width: itemSize.width,
                                         height: itemSize.height)
  }
  
  override func didMoveToSuperview() {
    if let _ = superview {
      activityIndicator.startAnimating()
    } else {
      activityIndicator.stopAnimating()
    }
  }
}
