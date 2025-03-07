//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import os

fileprivate let log = Logger(category: SeriesViewController.self)

class SeriesViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var sliceLabel: UILabel!
    @IBOutlet weak var episodesTableView: UITableView!
    
    var pid: String?
    var sliceID: String?
    
    var info: SeriesInfo? {
        didSet {
            updateValues()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        episodesTableView.dataSource = self
        episodesTableView.delegate = self

        updateValues()
        
        guard let pid else {
            log.error("pid must be set")
            return
        }
        
        Task {
            self.info = try await IPlayerAPI.shared.series(pid: pid, sliceID: sliceID)
        }
    }
    
    func updateValues() {
        episodesTableView.reloadData()
        
        guard let info else {
            titleLabel.text = nil
            descriptionLabel.text = nil
            sliceLabel.text = nil
            return
        }
        
        titleLabel.text = info.title
        descriptionLabel.text = info.description
        if let currentSlice {
            sliceLabel.text = currentSlice.title
        } else {
            sliceLabel.text = nil
        }
        
    }
    
    enum Mode {
        case slices
        case episodes
    }
    
    var mode: Mode {
        if info?.slices.count == 0 || sliceID != nil {
            return .episodes
        } else {
            return .slices
        }
    }
    
    var currentSlice: SeriesInfo.Slice? {
        if let info,
            let sliceID {
            let slice = info.slices.first {
                $0.id == sliceID
            }
            return slice
        }
        return nil
    }
}

extension SeriesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let info else { return 0 }
        if mode == .slices {
            return info.slices.count
        } else {
            return info.episodes.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let info else {
            return UITableViewCell()
        }
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "series.episode")
        if mode == .slices {
            let slice = info.slices[indexPath.row]
            cell.textLabel?.text = slice.title
            cell.detailTextLabel?.text = slice.id
        } else {
            let episode = info.episodes[indexPath.row]
            cell.textLabel?.text = episode.subtitle
            cell.detailTextLabel?.text = episode.pID
        }
        return cell
    }
}

extension SeriesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let info else { return }
        if mode == .slices {
            let slice = info.slices[indexPath.row]
            log.info("selected slice \(slice.id)")
            let vc = SeriesViewController()
            vc.pid = pid
            vc.sliceID = slice.id
            navController.pushViewController(vc, animated: true)
        } else {
            let episode = info.episodes[indexPath.row]
            let pid = episode.pID
            log.info("selected \(pid)")
            let vc = EpisodeViewController()
            vc.pid = pid
            navController.pushViewController(vc, animated: true)
        }
    }
}
