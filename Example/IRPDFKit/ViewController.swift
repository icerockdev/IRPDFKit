//
//  ViewController.swift
//  PdfViewer
//
//  Created by Aleksey Mikhailov on 11/10/16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit
import IRPDFKit

class ViewController: UIViewController {
  @IBOutlet weak var contentView: UIView!

  var number = 1
  var documentViewController: IRPDFDocumentViewController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    documentViewController = IRPDFDocumentViewController()
    
    addChildViewController(documentViewController)
    
    documentViewController.view.frame = contentView.bounds
    documentViewController.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    contentView.addSubview(documentViewController.view)
    
    documentViewController.didMoveToParentViewController(self)
    
    let dtGesture = UISwipeGestureRecognizer(target: self, action: #selector(changeDocumentGesture))
    dtGesture.direction = .Right
    
    documentViewController.view.addGestureRecognizer(dtGesture)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  func changeDocumentGesture(sender: UISwipeGestureRecognizer) {
    number += 1
    if number > 6 {
      number = 1
    }
    
    let url = NSBundle.mainBundle().URLForResource("document\(number)", withExtension: "pdf")!
    
    documentViewController.pdfDocumentUrl = url
  }
  
  @IBAction func searchButtonPressed(sender: UIBarButtonItem) {
    documentViewController.presentSearchViewController(sender)
  }
}
