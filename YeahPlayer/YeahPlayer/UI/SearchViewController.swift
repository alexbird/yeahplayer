//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import TVUIKit
import os

fileprivate let log = Logger(category: SearchViewController.self)

class SearchViewController: UIViewController, UISearchResultsUpdating, GridSearchResultsDelegate {
    private let appData: IPlayerAPI
    private let searchController: UISearchController
    private let searchContainerViewController: UISearchContainerViewController
    private let searchResultsController: GridSearchResultsViewController
    
    var publicSuggestions: [SearchItem]?

    init(appData: IPlayerAPI) {
        self.appData = appData
                
        self.searchResultsController = GridSearchResultsViewController()
        self.searchController = UISearchController(searchResultsController: self.searchResultsController)        
        self.searchContainerViewController = UISearchContainerViewController(searchController: searchController)
        
        super.init(nibName: nil, bundle: nil)
        
        // use the system standard search tab bar item
        tabBarItem = UITabBarItem(tabBarSystemItem: UITabBarItem.SystemItem.search, tag: 1)
        
        searchResultsController.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        addChild(searchContainerViewController)
        
        searchContainerViewController.view.frame = view.bounds
        view.addSubview(searchContainerViewController.view)
        searchContainerViewController.didMove(toParent: self)
        searchController.searchResultsUpdater = self
        // scroll search controller allong with results collection view
        searchController.searchControllerObservedScrollView = searchResultsController.collectionView
        
        Task {
            let suggestions = try await IPlayerAPI.shared.publicSuggestions()
            self.publicSuggestions = suggestions
            updateSearchResults(for: searchController)
        }
    }
    
    // MARK: - UISearchResultsUpdating
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            log.info("searchText: '\(searchText)'")
            Task {
                // TODO: throttle searches
                let results = try await appData.search(text: searchText)
                
                let items = results.map({ item in
                    SearchItem(id: item.id,
                               type: item.type,
                               title: item.title,
                               subtitle: item.subtitle,
                               imageURL: item.image)
                })
                
                searchResultsController.items = items
            }
        } else {
            // no search text, show public suggestions
            searchResultsController.items = publicSuggestions ?? []
        }
    }
    
    // MARK: - GridSearchResultsDelegate
    
    func itemSelected(pid: String, pidType: String) {
        log.info("selected \(pid)")
        
        if pidType == "episode" {
            let vc = EpisodeViewController()
            vc.pid = pid
            navController.pushViewController(vc, animated: true)
        } else if pidType == "series" || pidType == "programme" {
            let vc = SeriesViewController()
            vc.pid = pid
            navController.pushViewController(vc, animated: true)
        } else {
            log.error("unhandled PID type in search results: \(pidType)")
        }
    }
}
