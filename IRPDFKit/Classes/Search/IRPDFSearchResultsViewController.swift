//
//  Created by Михайлов Алексей on 18.10.16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit

private let searchResultCellIdentifier = "searchResultCell"
private let loadingCellIdentifier = "loadingCell"
private let infoCellIdentifier = "infoCell"

protocol IRPDFSearchResultsDelegate: class {
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   receiveResults: [IRPDFSearchResult]?)
  
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   didSelectResult: IRPDFSearchResult)
  
  func searchResultsViewController(viewController: IRPDFSearchResultsViewController,
                                   queryChanged: String?)
}

class IRPDFSearchResultsViewController: UITableViewController {
  let searchController = UISearchController(searchResultsController: nil)
  
  weak var searchEngine: IRPDFSearchEngine?
  var data: [IRPDFSearchResult]? {
    didSet {
      tableView.reloadData()
      
      searchDelegate?.searchResultsViewController(self, receiveResults: data)
    }
  }
  var searchQuery: String?
  
  weak var searchDelegate: IRPDFSearchResultsDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    searchController.searchBar.delegate = self
    searchController.searchBar.showsCancelButton = true
    searchController.searchResultsUpdater = self
    searchController.dimsBackgroundDuringPresentation = false
    searchController.delegate = self
    searchController.searchBar.text = searchQuery
    
    definesPresentationContext = true
    tableView.tableHeaderView = searchController.searchBar
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    searchController.active = true
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1 + (data?.count ?? 0)
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    var cell: UITableViewCell
    
    if let data = data {
      if indexPath.row == data.count {
        cell = tableView.dequeueReusableCellWithIdentifier(infoCellIdentifier) ??
          UITableViewCell(style: .Default, reuseIdentifier: infoCellIdentifier)
        
        cell.textLabel?.textAlignment = .Center
        cell.textLabel?.text = "\(data.count) results"
      } else {
        let result = data[indexPath.row]
        cell = tableView.dequeueReusableCellWithIdentifier(searchResultCellIdentifier) ??
          UITableViewCell(style: .Subtitle, reuseIdentifier: searchResultCellIdentifier)
        
        let contextString = result.contextString
        let queryRange = result.queryInContextRange
        let range = NSMakeRange(contextString.startIndex.distanceTo(queryRange.startIndex), queryRange.count)
        
        if let textLabel = cell.textLabel {
          var context = NSMutableAttributedString(string: contextString)
          context.addAttribute(NSFontAttributeName,
                               value: UIFont.boldSystemFontOfSize(textLabel.font.pointSize),
                               range: range)
          
          textLabel.attributedText = context
        }
        
        cell.detailTextLabel?.text = "Page: \(result.page)"
      }
    } else {
      cell = tableView.dequeueReusableCellWithIdentifier(loadingCellIdentifier) ??
        IRPDFLoadingTableViewCell(reuseIdentifier: loadingCellIdentifier)
    }
    
    return cell
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    guard let data = data where indexPath.row != data.count else {
      return
    }
    
    let result = data[indexPath.row]
    
    searchController.dismissViewControllerAnimated(false, completion: nil)
    
    dismissViewControllerAnimated(true) {
      self.searchDelegate?.searchResultsViewController(self, didSelectResult: result)
    }
  }
  
  override func prefersStatusBarHidden() -> Bool {
    return true
  }
}

extension IRPDFSearchResultsViewController: UISearchResultsUpdating {
  func updateSearchResultsForSearchController(searchController: UISearchController) {
    let text = searchController.searchBar.text ?? ""
    
    searchQuery = text
    
    if text.characters.count > 0 {
      self.data = nil
      
      searchEngine?.search(text) {
        [weak self] (query, results) in
        
        if let `self` = self {
          self.data = results
          self.searchDelegate?.searchResultsViewController(self, queryChanged: query)
        }
      }
    } else {
      self.data = []
      
      self.searchDelegate?.searchResultsViewController(self, queryChanged: nil)
    }
  }
}

extension IRPDFSearchResultsViewController: UISearchBarDelegate {
  public func searchBarCancelButtonClicked(searchBar: UISearchBar) {
    dismissViewControllerAnimated(true, completion: nil)
  }
}

extension IRPDFSearchResultsViewController: UISearchControllerDelegate {
  func didPresentSearchController(searchController: UISearchController) {
    searchController.searchBar.becomeFirstResponder()
  }
}
