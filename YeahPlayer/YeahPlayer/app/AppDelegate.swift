//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit

@MainActor
var navController: UINavigationController {
    ((UIApplication.shared.delegate as! AppDelegate).window?.rootViewController as! UINavigationController)
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        configureLocalProxy()
        configureWindow()
        
        return true
    }

    func configureLocalProxy() {
        CaptionProxy.shared.startWebServer()
    }
    
    func configureWindow() {
        let liveTVViewController = LiveTVViewController(appData: IPlayerAPI.shared)
        let searchViewController = SearchViewController(appData: IPlayerAPI.shared)

        let tabBarController = UITabBarController ()
        tabBarController.viewControllers = [searchViewController, liveTVViewController]
        let navController = UINavigationController(rootViewController: tabBarController)
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
    }
}

