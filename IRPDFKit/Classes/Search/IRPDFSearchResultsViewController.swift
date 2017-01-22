//
//  Created by Михайлов Алексей on 18.10.16.
//  Copyright © 2016 IceRock Development. All rights reserved.
//

import UIKit

private let searchResultCellIdentifier = "searchResultCell"
private let loadingCellIdentifier = "loadingCell"
private let infoCellIdentifier = "infoCell"

protocol IRPDFSearchResultsDelegate: class {
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
                                   receiveResults: [IRPDFSearchResult]?)
  
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
                                   didSelectResult: IRPDFSearchResult)
  
  func searchResultsViewController(_ viewController: IRPDFSearchResultsViewController,
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
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    searchController.isActive = true
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1 + (data?.count ?? 0)
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var cell: UITableViewCell
    
    if let data = data {
      if indexPath.row == data.count {
        cell = tableView.dequeueReusableCell(withIdentifier: infoCellIdentifier) ??
          UITableViewCell(style: .default, reuseIdentifier: infoCellIdentifier)
        
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.text = "\(data.count) results"
      } else {
        let result = data[indexPath.row]
        cell = tableView.dequeueReusableCell(withIdentifier: searchResultCellIdentifier) ??
          UITableViewCell(style: .subtitle, reuseIdentifier: searchResultCellIdentifier)
        
        let contextString = result.contextString
        let queryRange = result.queryInContextRange
        let startLocation = contextString.distance(from: contextString.startIndex, to: queryRange.lowerBound) as Int
        let endLocation = contextString.distance(from: contextString.startIndex, to: queryRange.upperBound) as Int
        let range = NSMakeRange(startLocation, (endLocation - startLocation))
        
        if let textLabel = cell.textLabel {
          var context = NSMutableAttributedString(string: contextString)
          context.addAttribute(NSFontAttributeName,
                               value: UIFont.boldSystemFont(ofSize: textLabel.font.pointSize),
                               range: range)
          
          textLabel.attributedText = context
        }
        
        cell.detailTextLabel?.text = "Page: \(result.page)"
      }
    } else {
      cell = tableView.dequeueReusableCell(withIdentifier: loadingCellIdentifier) ??
        IRPDFLoadingTableViewCell(reuseIdentifier: loadingCellIdentifier)
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let data = data, indexPath.row != data.count else {
      return
    }
    
    let result = data[indexPath.row]
    
    searchController.dismiss(animated: false, completion: nil)
    
    dismiss(animated: true) {
      self.searchDelegate?.searchResultsViewController(self, didSelectResult: result)
    }
  }
  
  override var prefersStatusBarHidden : Bool {
    return true
  }
}

extension IRPDFSearchResultsViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
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
  public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    dismiss(animated: true, completion: nil)
  }
}

extension IRPDFSearchResultsViewController: UISearchControllerDelegate {
  func didPresentSearchController(_ searchController: UISearchController) {
    searchController.searchBar.becomeFirstResponder()
  }
}
