//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//
import UIKit

class LiveTVViewController: UIViewController {
    private let appData: IPlayerAPI

    @IBOutlet weak var channelsTableView: UITableView!
    
    init(appData: IPlayerAPI) {
        self.appData = appData
                
        super.init(nibName: nil, bundle: nil)
        
        tabBarItem = UITabBarItem(title: "Live", image: nil, tag: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        channelsTableView.delegate = self
        channelsTableView.dataSource = self
        
        Task {
            self.info = try await IPlayerAPI.shared.channels()
        }
        
        updateValues()
    }
    
    var info: [ChannelInfo]? {
        didSet {
            updateValues()
        }
    }
    
    func updateValues() {
        channelsTableView.reloadData()
    }
}

extension LiveTVViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let info else { return 0 }
        return info.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let info else { return UITableViewCell() }
        let channel = info[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "series.episode")
        cell.textLabel?.text = channel.title
        cell.detailTextLabel?.text = channel.id
        return cell
    }
}

extension LiveTVViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let info else { return }
        let channel = info[indexPath.row]
        let vc = LiveChannelViewController()
        vc.channelHREF = channel.liveHREF
        navController.pushViewController(vc, animated: false)
    }
}
