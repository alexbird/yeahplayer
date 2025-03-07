//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation
import os

fileprivate let log = Logger(category: EpisodeParser.self)

struct EpisodeInfo: Sendable {
    let pID: String
    let versionID: String
    let title: String
    let subtitle: String?
    let description: String
    let thumb: String
}

struct SeriesInfo {
    struct Episode {
        let pID: String
        let subtitle: String
    }
    
    struct Slice {
        let id: String
        let title: String
    }
    
//    let pID: String
    let title: String
    let description: String
    let slices: [Slice]
//    let thumb: String
    let episodes: [Episode]
}

struct ChannelInfo {
    let id: String
    let title: String
    let liveHREF: String
}

struct LiveChannelInfo: Sendable {
    struct Show {
        let title: String
        let subtitle: String?
        let startTime: String
        let endTime: String
    }
        
    let versionID: String
    let title: String
    let shows: [Show]
}

final class EpisodeParser: Sendable {
    
    struct Navigation: Codable {
        let items: [NavigationItem]
    }

    struct NavigationItem: Codable {
        let id: String?
        let title: String
        let active: Bool?
        let subItems: [Channel]?
        let href: String?
        let ariaLabel: String?
    }

    struct Channel: Codable {
        let title: String
        let href: String
        let liveHref: String?
        let active: Bool
        let icon: String?
        let id: String
    }
    
    struct LiveChannel: Codable {
        let id: String
        let title: String
    }
    
    struct Broadcasts: Codable {
        let items: [BroadcastItem]
    }
    
    struct BroadcastItem: Codable {
        let title: String
        let subtitle: String?
        let startTime: String
        let endTime: String
    }
    
    struct Episode: Codable {
        let id: String
        let title: String
        let subtitle: String?
        let synopses: Synopses
        let images: Images
        
        struct Synopses: Codable {
            let large: String?
            let small: String?
            let medium: String?
        }
        
        struct Images: Codable {
            let standard: String
        }
    }
    
    struct Version: Codable {
        let id: String
    }
    
    struct Bundle: Codable {
        let entities: [Entity]
    }
    
    struct Entity: Codable {
        let episode: BundleEpisode?
    }
    
    struct BundleEpisode: Codable {
        let id: String
        let live: Bool
        let title: StringWithDefault
        let subtitle: StringWithDefault?
        let image: ImageWithDefault?
        
        var imageURL: URL? {
            let recipe = "464x261"
            guard let thumb = image?.defaultString.replacingOccurrences(of: "{recipe}", with: recipe) else { return nil }
            return URL(string: thumb)
        }
        
        struct Synopses: Codable {
            let large: String?
            let small: String?
            let medium: String?
        }
        
        struct ImageWithDefault: Codable {
            let defaultString: String
            
            enum CodingKeys: String, CodingKey {
                case defaultString = "default"
            }
        }
        
        struct StringWithDefault: Codable {
            let defaultString: String?
            
            enum CodingKeys: String, CodingKey {
                case defaultString = "default"
            }
        }
    }

    struct IPlayerState: Codable {
        let navigation: Navigation
        let versions: [Version]?
        let episode: Episode?
        let channel: LiveChannel?
        let broadcasts: Broadcasts?
        let bundles: [Bundle]?
    }
    
    struct SeriesState: Codable {
        struct Header: Codable {
            struct Slice: Codable {
                let id: String
                let title: String
            }
            
//            let currentSliceId: String
            let title: String
            let subtitle: String?
            let availableSlices: [Slice]
        }
        
        struct Entities: Codable {
            struct Result: Codable {
                struct Episode: Codable {
                    struct StringWithDefault: Codable {
                        let defaultString: String
                        
                        enum CodingKeys: String, CodingKey {
                            case defaultString = "default"
                        }
                    }
                    
                    let id: String
                    let subtitle: StringWithDefault
                }
                
                let episode: Episode
            }
            
            let results: [Result]
        }
        
        let header: Header
        let entities: Entities
    }
    
    func extractBundleSuggestions(from htmlString: String) -> [SearchItem]? {
        do {
            guard let jsonData = reduxStateData(from: htmlString) else {
                log.error("Error parsing JSON: no redux state") // TODO: move errors down
                return nil
            }
            
            let decoder = JSONDecoder()
            let state = try decoder.decode(IPlayerState.self, from: jsonData)
            
            var items: [SearchItem] = []
            if let bundles = state.bundles {
                for bundle in bundles {
                    let entities = bundle.entities
                    for entity in entities {
                        if let episode = entity.episode,
                           let title = episode.title.defaultString,
                           !episode.live // we don't want live events in suggestions, easiest not to deal with them for now
                        {
                            let subtitle = episode.subtitle?.defaultString
                            let type = "episode"
                            let item = SearchItem(id: episode.id,
                                                  type: type,
                                                  title: title,
                                                  subtitle: subtitle,
                                                  imageURL: episode.imageURL)
                            
                            items.append(item)
                        }
                    }
                }
            }
            return items
            
        } catch {
            log.error("Error parsing JSON: \(error)")
        }
        
        return nil
    }
    
    func extractEpisodeInfo(from htmlString: String) -> EpisodeInfo? {
        do {
            guard let jsonData = reduxStateData(from: htmlString) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let state = try decoder.decode(IPlayerState.self, from: jsonData)
            
            // Return the first version ID
            if let versionID = state.versions?.first?.id,
               let episode = state.episode {
                return EpisodeInfo(pID: episode.id,
                                   versionID: versionID,
                                   title: episode.title,
                                   subtitle: episode.subtitle,
                                   description: episode.synopses.large ?? episode.synopses.medium ?? episode.synopses.small ?? episode.subtitle ?? "",
                                   thumb: episode.images.standard)
            }
            
        } catch {
            log.error("Error parsing JSON: \(error)")
        }
        
        return nil
    }
    
    func extractSeriesInfo(from htmlString: String) -> SeriesInfo? {
        do {
            guard let jsonData = reduxStateData(from: htmlString) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let state = try decoder.decode(SeriesState.self, from: jsonData)

            let episodes = state.entities.results.map { result in
                SeriesInfo.Episode(pID: result.episode.id,
                                   subtitle: result.episode.subtitle.defaultString)
            }
            return SeriesInfo(title: state.header.title,
                              description: state.header.subtitle ?? "",
                              slices: state.header.availableSlices
                .compactMap({
                    guard $0.id != "more-like-this" else { return nil }
                    guard $0.id != "unsliced" else { return nil }
                    return SeriesInfo.Slice(id: $0.id, title: $0.title)
                }),
                              episodes: episodes)
            
        } catch {
            log.error("Error parsing JSON: \(error)")
        }
        
        return nil
    }
    
    func extractChannelsInfo(from htmlString: String) -> [ChannelInfo]? {
        do {
            guard let jsonData = reduxStateData(from: htmlString) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let state = try decoder.decode(IPlayerState.self, from: jsonData)
            
            if let items = state.navigation.items.first(where: {
                $0.id == "channels"
            }) {
                return items.subItems?.compactMap({ item in
                    guard let liveHref = item.liveHref else { return nil }
                    return ChannelInfo(id: item.id, title: item.title, liveHREF: liveHref)
                })
            }
            return nil
            
        } catch {
            log.error("Error parsing JSON: \(error)")
        }
        
        return nil
    }
    
    func extractLiveChannelInfo(from htmlString: String) -> LiveChannelInfo? {
        do {
            guard let jsonData = reduxStateData(from: htmlString) else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let state = try decoder.decode(IPlayerState.self, from: jsonData)
            
            // Return the first version ID
            if let channel = state.channel {
                var shows: [LiveChannelInfo.Show] = []
                if let broadcasts = state.broadcasts {
                    broadcasts.items.forEach { item in
                        shows.append(LiveChannelInfo.Show(title: item.title,
                                                          subtitle: item.subtitle,
                                                          startTime: item.startTime,
                                                          endTime: item.endTime))
                    }
                }
                return LiveChannelInfo(versionID: channel.id, title: channel.title, shows: shows)
            }
            
        } catch {
            log.error("Error parsing JSON: \(error)")
        }
        
        return nil
    }
    
    func reduxStateData(from htmlString: String) -> Data? {
        guard let stateStart = htmlString.range(of: "window.__IPLAYER_REDUX_STATE__ = "),
              let stateEnd = htmlString.range(of: ";</script>", range: stateStart.upperBound..<htmlString.endIndex) else {
            return nil
        }
        
        let jsonRange = stateStart.upperBound..<stateEnd.lowerBound
        let jsonString = String(htmlString[jsonRange])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        
        return jsonData
    }

}
