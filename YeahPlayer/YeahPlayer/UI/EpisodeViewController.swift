//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import os

fileprivate let log = Logger(category: EpisodeViewController.self)

class EpisodeViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var licenceWarningLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    private let imageLoader = ImageLoader()
    
    var pid: String?
    
    var info: EpisodeInfo? {
        didSet {
            updateValues()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateValues()
        
        guard let pid else {
            log.error("pid must be set")
            return
        }
        
        Task {
            self.info = try await IPlayerAPI.shared.episode(pid: pid)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        log.warning("viewDidAppear")
    }
    
    @IBAction func playButtonPressed(_ sender: Any) {
        log.info("play versionID: \(String(describing: self.info?.versionID))")
        
        guard let info else { return }
        let vc = VideoPlayerViewController(info: info)
        navController.pushViewController(vc, animated: true)
    }
    
    func updateValues() {
        guard let info else {
            titleLabel.text = nil
            subtitleLabel.text = nil
            descriptionLabel.text = nil
            thumbImageView.image = nil
            playButton.isHidden = true
            licenceWarningLabel.isHidden = true
            loadingIndicator.startAnimating()
            return
        }
        
        titleLabel.text = info.title
        subtitleLabel.text = info.subtitle
        descriptionLabel.text = info.description
        let recipe = "960x540"
        let thumb = info.thumb.replacingOccurrences(of: "{recipe}", with: recipe)
        if let thumbURL = URL(string: thumb) {
            Task { [weak thumbImageView] in
                let image = await imageLoader.loadImage(from: thumbURL)
                thumbImageView?.image = image
            }
        }
        playButton.isHidden = false
        licenceWarningLabel.isHidden = false
        loadingIndicator.stopAnimating()
        
        setNeedsFocusUpdate()
    }
    
    override var preferredFocusedView: UIView? {
        guard playButton.isEnabled else { return nil }
        return playButton
    }
}
