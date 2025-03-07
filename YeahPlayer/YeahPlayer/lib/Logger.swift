//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation
import OSLog

extension Logger {
    init(category: Any) {
        self.init(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: category))
    }
}
