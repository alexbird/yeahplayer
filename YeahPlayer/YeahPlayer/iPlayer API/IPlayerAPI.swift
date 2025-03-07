//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation
import os

fileprivate let log = Logger(category: IPlayerAPI.self)

enum IPlayerError: String, Error {
    case urlFormatting
    case parsing
}

actor IPlayerAPI {
    static let shared = IPlayerAPI()
    
    let session = URLSession(configuration: .default)
    let searchParser = SearchParser()
    let episodeParser = EpisodeParser()
    let mediaParser = OpenLiveParser()
    
    func search(text: String) async throws -> [SearchParser.SearchResult] {
        guard let searchURL = URL(string: "https://ibl.api.bbc.co.uk/ibl/v1/new-search?q=\(text)&rights=web&age_bracket=o18&mixin=live") else { return [] }
                
        let (data, _) = try await URLSession.shared.data(from: searchURL)
        
        let results = try searchParser.extractSearchResults(jsonData: data)
        
        return results
    }
    
    func episode(pid: String) async throws -> EpisodeInfo {
        guard let episodePageURL = URL(string: "https://www.bbc.co.uk/iplayer/episode/\(pid)/yeah") else {
            throw IPlayerError.urlFormatting
        }
        log.info("\(episodePageURL)")
        
        let (data, _) = try await URLSession.shared.data(from: episodePageURL)
            
        guard let pageString = String(data: data, encoding: .utf8),
              let info = episodeParser.extractEpisodeInfo(from: pageString) else {
            throw IPlayerError.parsing
        }

        return info
    }
    
    func series(pid: String, sliceID: String? = nil) async throws -> SeriesInfo {
        var suffix: String = ""
        if let sliceID {
            suffix = "?seriesId=\(sliceID)"
        }
        guard let seriesPageURL = URL(string: "https://www.bbc.co.uk/iplayer/episodes/\(pid)/yeah\(suffix)") else {
            throw IPlayerError.urlFormatting
        }
        log.info("\(seriesPageURL)")
        
        let (data, _) = try await URLSession.shared.data(from: seriesPageURL)
            
        guard let pageString = String(data: data, encoding: .utf8),
              let info = episodeParser.extractSeriesInfo(from: pageString) else {
            throw IPlayerError.parsing
        }

        return info
    }
    
    func media(versionID: String) async throws -> BBCMedia {
        guard let openLiveURL = URL(string: "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/iptv-all/vpid/\(versionID)/format/json/cors/1") else {
            throw IPlayerError.urlFormatting
        }
        log.info("\(openLiveURL)")
        
        let (data, _) = try await URLSession.shared.data(from: openLiveURL)
        
        guard let media = mediaParser.extractMediaUrls(from: data) else {
            throw IPlayerError.parsing
        }
        
        return media
    }
    
    func channels() async throws -> [ChannelInfo] {
        let pageString = try await iPlayerHome()
        guard let info = episodeParser.extractChannelsInfo(from: pageString) else {
            throw IPlayerError.parsing
        }

        return info
    }
    
    func publicSuggestions() async throws -> [SearchItem] {
        let pageString = try await iPlayerHome()
        guard let info = episodeParser.extractBundleSuggestions(from: pageString) else {
            throw IPlayerError.parsing
        }

        return info
    }
    
    private func iPlayerHome() async throws -> String {
        let task = try await iPlayerHomeDataTask()
        let data = try await task.value
        
        guard let pageString = String(data: data, encoding: .utf8) else {
            throw IPlayerError.parsing
        }
        
        return pageString
    }
    private var _iPlayerHomeDataTask: Task<Data, Error>?
    private func iPlayerHomeDataTask() async throws -> Task<Data, Error> {
        // return existing task result if a fetch is in progress
        if let existingTask = _iPlayerHomeDataTask {
            return existingTask
        }
        
        guard let PageURL = URL(string: "https://www.bbc.co.uk/iplayer/") else {
            throw IPlayerError.urlFormatting
        }
        log.info("\(PageURL)")
        
        // create new task
        let task = Task<Data, Error> {
            let (fetchedData, _) = try await URLSession.shared.data(from: PageURL)
            return fetchedData
        }
        
        _iPlayerHomeDataTask = task
        return task
    }
    
    func liveChannel(channelHREF: String) async throws -> LiveChannelInfo {
        guard let pageURL = URL(string: "https://www.bbc.co.uk\(channelHREF)") else {
            throw IPlayerError.urlFormatting
        }
        log.info("\(pageURL)")
        
        let (data, _) = try await URLSession.shared.data(from: pageURL)
            
        guard let pageString = String(data: data, encoding: .utf8),
              let info = episodeParser.extractLiveChannelInfo(from: pageString) else {
            throw IPlayerError.parsing
        }        
        
        return info
    }
}
