//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import os

fileprivate let log = Logger(category: LiveChannelViewController.self)

class LiveChannelViewController: UIViewController {
    @IBOutlet weak var channelLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var licenceWarningLabel: UILabel!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    var channelHREF: String?
    
    var info: LiveChannelInfo? {
        didSet {
            updateValues()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let channelHREF else {
            log.error("channelHREF must be set")
            return
        }
        
        Task {
            self.info = try await IPlayerAPI.shared.liveChannel(channelHREF: channelHREF)
        }

        updateValues()
    }
    
    func updateValues() {
        guard let info else {
            channelLabel.text = nil
            titleLabel.text = nil
            subtitleLabel.text = nil
            playButton.isHidden = true
            licenceWarningLabel.isHidden = true
            loadingIndicator.startAnimating()
            return
        }
        
        channelLabel.text = info.title
        titleLabel.text = info.shows.first?.title
        subtitleLabel.text = info.shows.first?.subtitle
        playButton.isHidden = false
        licenceWarningLabel.isHidden = false
        loadingIndicator.stopAnimating()
        setNeedsFocusUpdate()
    }
    
    override var preferredFocusedView: UIView? {
        guard playButton.isEnabled else { return nil }
        return playButton
    }
    
    @IBAction func playButtonPressed(_ sender: Any) {
        guard let info else { return }
        log.info("play live \(info.versionID)")
        let vc = VideoPlayerViewController(info: info)
        navController.pushViewController(vc, animated: true)
    }
}
