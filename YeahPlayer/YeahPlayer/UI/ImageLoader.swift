//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import os
import UIKit

fileprivate let log = Logger(category: ImageLoader.self)

actor ImageLoader {
    private let cache = NSCache<NSURL, UIImage>()
    
    func loadImage(from url: URL) async -> UIImage? {
        // check cache first
        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }
        
        // download image
        let imageTask = Task { () -> UIImage? in
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                return image
            }
            return nil
        }
        
        // cache success
        do {
            if let image = try await imageTask.value {
                cache.setObject(image, forKey: url as NSURL)
                return image
            }
            // TODO: cache unrecoverable failures
        } catch {
            log.error("Image loading: \(error)")
        }
        
        return nil
    }
}
