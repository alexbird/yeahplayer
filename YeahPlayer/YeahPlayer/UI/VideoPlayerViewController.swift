//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import AVKit
import os

fileprivate let log = Logger(category: VideoPlayerViewController.self)

class VideoPlayerViewController: UIViewController {
    
    var info: VideoPlayerInfo
    
    private var coordinator: AVPlayerSubtitleCoordinator?
    private var avPlayerViewController: AVPlayerViewController?
    
    init(info: VideoPlayerInfo) {
        log.debug("VideoPlayerViewController init")
        self.info = info
        
        super.init(nibName: nil, bundle: nil)
    }
    
    deinit {
        log.debug("VideoPlayerViewController DEinit")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.coordinator = AVPlayerSubtitleCoordinator(info: info,
                                                       captionProxyHost: CaptionProxy.shared.hostWithPort)
        
        // attach subtitled player to AVPlayerViewController
        let childVC = AVPlayerViewController()
        childVC.player = coordinator?.player

        // add AVPlayerViewController as full-screen child view controller
        addChild(childVC)
        childVC.view.frame = view.bounds
        view.addSubview(childVC.view)
        childVC.didMove(toParent: self)
    
        self.avPlayerViewController = childVC
    }
}
