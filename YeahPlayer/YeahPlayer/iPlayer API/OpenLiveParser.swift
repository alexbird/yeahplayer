//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation

struct BBCMedia: Sendable {
    struct PlainCaptions: Equatable {
        let href: String
    }
    
    struct DASHCaptions: Equatable {
        let hrefFormat: String
        
        func href(number: String) -> URL? {
            // e.g. https://vs-cmaf-push-uk-live.akamaized.net/x=4/i=urn:bbc:pips:service:bbc_one_london/t=3840/s=caption1/b=64000/$Number$.m4s
            let href = hrefFormat.replacingOccurrences(of: "$Number$", with: number)
            return URL(string: href)
        }
    }
    
    enum Captions: Equatable {
        case none
        case plain(source: PlainCaptions)
        case dash(source: DASHCaptions)
        
        var isCaptioned: Bool {
            if case .none = self { return false }
            else { return true }
        }
        
        var isDASH: Bool {
            if case .dash(_) = self { return true }
            else { return false }
        }
    }
    
    let video: String
    let captions: Captions
}

final class OpenLiveParser: Sendable {
    
    struct MediaConnection: Codable {
        let priority: String
        let scheme: String
        let transferFormat: String
        let href: String
        
        enum CodingKeys: String, CodingKey {
            case priority
            case scheme = "protocol"
            case transferFormat
            case href
        }
    }
    
    struct MediaItem: Codable {
        let kind: String
        let connection: [MediaConnection]
    }
    
    struct MediaResponse: Codable {
        let media: [MediaItem]
    }
    
    func extractMediaUrls(from jsonData: Data) -> BBCMedia? {
        guard let response = try? JSONDecoder().decode(MediaResponse.self, from: jsonData) else {
            return nil
        }
        
        // extract HLS URLs from video section
        let hlsUrls = response.media
            .first(where: { $0.kind == "video" })?
            .connection
            .filter { connection in
                connection.scheme == "https" &&
                connection.transferFormat == "hls"
            }
            .sorted {
                Int($0.priority) ?? 0 < Int($1.priority) ?? 0
            }
            .map { $0.href } ?? []
        
        // extract URLs from captions section
        let captionConnections = response.media
            .first(where: { $0.kind == "captions" })?
            .connection
            .filter { connection in
                connection.scheme == "https"
            }
            .sorted {
                Int($0.priority) ?? 0 < Int($1.priority) ?? 0
            } ?? []
        
        guard let video = hlsUrls.first else { return nil }

        if let captionConnection = captionConnections.first {
            if captionConnection.transferFormat == "dash" {
                return BBCMedia(video: video,
                                captions: .dash(source: BBCMedia.DASHCaptions(hrefFormat: captionConnection.href)))
            } else {
                return BBCMedia(video: video,
                                captions: .plain(source: BBCMedia.PlainCaptions(href: captionConnection.href)))
            }
        } else {
            return BBCMedia(video: video,
                            captions: .none)
        }
    }
}
