//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import AVKit
import os

fileprivate let log = Logger(category: AVPlayerSubtitleCoordinator.self)

protocol VideoPlayerInfo: Sendable {
    var versionID: String { get }
    var title: String { get }
    var subtitle: String? { get }
}

extension VideoPlayerInfo {
    var titleMetadata: AVMutableMetadataItem {
        var suffix = ""
        if let subtitle = subtitle {
            suffix = "\n\(subtitle)"
        }
        let mediaTitle = "\(title)\(suffix)"
        
        let titleMetadata = AVMutableMetadataItem()
        titleMetadata.identifier = .commonIdentifierTitle
        titleMetadata.value = mediaTitle as NSString
        titleMetadata.extendedLanguageTag = "und"  // undefined language tag
        return titleMetadata
    }
}

extension EpisodeInfo: VideoPlayerInfo { }

extension LiveChannelInfo: VideoPlayerInfo {
    var subtitle: String? { nil }
}

let schemePrefix = "yeah"

actor AVPlayerSubtitleCoordinator: NSObject, AVAssetResourceLoaderDelegate {
    
    let info: VideoPlayerInfo
    let captionProxyHost: String
    
    private var media: BBCMedia?
    private func updateMedia(_ newValue: BBCMedia?) async {
        self.media = newValue
    }
    
    private var vodDurationSeconds: Int?
    private func updateVODDurationSeconds(_ newValue: Int?) async {
        self.vodDurationSeconds = newValue
    }
    
    @MainActor
    var item: AVPlayerItem?
 
    @MainActor
    lazy var player: AVPlayer = AVPlayer()
    
    init(info: VideoPlayerInfo, captionProxyHost: String) {
        self.info = info
        self.captionProxyHost = captionProxyHost
        
        super.init()
        
        let versionID = info.versionID
        Task {
            let media = try await IPlayerAPI.shared.media(versionID: versionID)
            await self.updateMedia(media)
            
            guard let videoURL = URL(string: schemePrefix + media.video) else { return }
            let metadata = info.titleMetadata

            Task { @MainActor in
                CaptionProxy.shared.updateMedia(newValue: media)
                let asset = AVURLAsset(url: videoURL)
                asset.resourceLoader.setDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
                                
                let duration = try await asset.load(.duration)
                if !duration.isIndefinite {
                    await updateVODDurationSeconds(Int(duration.seconds))
                    log.debug("VOD length: \(duration.seconds)s")
                }
                                
                item = AVPlayerItem(asset: asset)
                item?.externalMetadata.append(metadata)
                player.replaceCurrentItem(with: item)
                player.play()
            }
        }
    }
    
    deinit {
        log.debug("VideoPlayerCoordinator DEinit")
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    nonisolated func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                                    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        Task {
            await handleLoadingRequest(loadingRequest)
        }
        return true
    }
    
    enum ResourceLoaderDelegateStrategy: String {
        case redirect
        case fetchMasterAndAddSubs
        case repeatMainAndCacheSegmentRange
        case serveGeneratedPlainSubsPlaylist
        case serveGeneratedDASHSubsPlaylist
    }
    
    private let session = URLSession(configuration: .default)
    private var lastPlaylist: String?
    private func updateLastPlaylist(_ newValue: String?) async {
        self.lastPlaylist = newValue
    }
    
    private func handleLoadingRequest(_ loadingRequest: AVAssetResourceLoadingRequest) async {
        
        guard let media else { return }
        guard let realURL = extractRealURL(for: loadingRequest) else { return }
        let dataRequest = loadingRequest.dataRequest
        log.debug("handling URL: \(realURL)")
        
        // sniff request
        let mediaHasDASHSubtitles = media.captions.isDASH
        let mediaHasSubtitles = media.captions.isCaptioned
        let isFirstMasterPlaylistProbe = dataRequest != nil && dataRequest?.requestedOffset == 0 && dataRequest?.requestedLength == 2
        let isMasterPlaylistRequest = realURL.absoluteString == media.video
        let isSubsPlaylistRequest = realURL.absoluteString.contains("yeah/subtitles/eng/prog_index.m3u8")
        let isMainPlaylistRequest = realURL.lastPathComponent.hasSuffix(".m3u8") && !isMasterPlaylistRequest && !isSubsPlaylistRequest
        
        log.debug("    | mediaHasSubtitles: \(mediaHasSubtitles)")
        log.debug("    | mediaHasDASHSubtitles: \(mediaHasDASHSubtitles)")
        log.debug("    | isFirstMasterPlaylistProbe: \(isFirstMasterPlaylistProbe)")
        log.debug("    | isMasterPlaylistRequest: \(isMasterPlaylistRequest)")
        log.debug("    | isMainPlaylistRequest: \(isMainPlaylistRequest)")
        log.debug("    | isSubsPlaylistRequest: \(isSubsPlaylistRequest)")
        
        // strategise
        var strategy: ResourceLoaderDelegateStrategy = .redirect
        if isMasterPlaylistRequest && !isFirstMasterPlaylistProbe && mediaHasSubtitles {
            strategy = .fetchMasterAndAddSubs
        } else if isMainPlaylistRequest && mediaHasDASHSubtitles {
            strategy = .repeatMainAndCacheSegmentRange
        } else if isSubsPlaylistRequest {
            switch media.captions {
                case .plain(_):
                    strategy = .serveGeneratedPlainSubsPlaylist
                case .dash(_):
                    strategy = .serveGeneratedDASHSubsPlaylist
                default:
                    log.warning("unexpected caption playlist request when media has no captions")
            }
        }
        log.debug("    — > strategy: \(strategy.rawValue)")
        
        let requestID = String(describing: CACurrentMediaTime()) // for logging only
        switch strategy {
            case .redirect:
                // rewrite URL without our dummy scheme
                redirectToRealResource(loadingRequest: loadingRequest, realURL: realURL)
            case .fetchMasterAndAddSubs:
                // rewrite master playlist to add subs
                getRealMasterPlaylistAndAddSubs(loadingRequest: loadingRequest, realURL: realURL)
            case .repeatMainAndCacheSegmentRange:
                // keep the segment numbers for our DASH main subtitle playlists
                log.info("\(requestID): cache main playlist...")
                relayMainPlaylistAndCache(loadingRequest: loadingRequest, realURL: realURL, requestID: requestID)
            case .serveGeneratedPlainSubsPlaylist:
                // serve generated plain subs playlist
                serveGeneratedPlainCaptionPlaylist(loadingRequest: loadingRequest)
            case .serveGeneratedDASHSubsPlaylist:
                // serve generated DASH subs playlist
                log.info("\(requestID): generate DASH captions playlist...")
                serveGeneratedDASHCaptionPlaylist(loadingRequest: loadingRequest, requestID: requestID)
        }
    }
    
    private func redirectToRealResource(loadingRequest: AVAssetResourceLoadingRequest, realURL: URL) {
        let redirectRequest = URLRequest(url: realURL)
        let redirectResponse = HTTPURLResponse(url: realURL, statusCode: 302, httpVersion: nil, headerFields: nil)
        loadingRequest.redirect = redirectRequest
        loadingRequest.response = redirectResponse
        log.info("responded with redirect to ...\(realURL.absoluteString.suffix(25))")
        loadingRequest.finishLoading()
    }
    
    private func getRealMasterPlaylistAndAddSubs(loadingRequest: AVAssetResourceLoadingRequest, realURL: URL) {
        let remoteRequest = URLRequest(url: realURL)
        let fetchRealResourceTask = session.dataTask(with: remoteRequest) { data, URLResponse, error in
            if error == nil {
                if let data,
                   let originalPlaylist = String(data: data, encoding: .utf8) {
                    let modifiedPlaylist = PlaylistWriter.addSubtitles(toMasterPlaylist: originalPlaylist)
                    if let modifiedData = modifiedPlaylist.data(using: .utf8) {
                        loadingRequest.dataRequest?.respond(with: modifiedData)
                        log.info("responded with modified master playlist")
                        loadingRequest.finishLoading()
                    } else {
                        log.error("getRealMasterPlaylistAndAddSubs error returning modified playlist")
                        loadingRequest.finishLoading(with: error)
                    }
                } else {
                    log.error("getRealMasterPlaylistAndAddSubs error extracting original playlist")
                    loadingRequest.finishLoading(with: error)
                }
            } else {
                log.error("getRealMasterPlaylistAndAddSubs data task error: \(String(describing: error))")
                loadingRequest.finishLoading(with: error)
            }
        }
        fetchRealResourceTask.resume()
    }
    
    private var _mainPlaylistDataTask: Task<Data, Error>?
    private func mainPlaylistData(url: URL) async throws -> Data {
        // create new task
        let task = Task<Data, Error> {
            let (fetchedData, _) = try await URLSession.shared.data(from: url)
            return fetchedData
        }
        
        _mainPlaylistDataTask = task
        return try await task.value
    }
    private func latestMainPlaylistData() async throws -> Data {
        // return existing task result if a fetch is in progress
        if let existingTask = _mainPlaylistDataTask {
            return try await existingTask.value
        }
        
        log.error("no main playlist cached")
        throw NSError(domain: NSURLErrorDomain, code: 500)
    }
    
    private func relayMainPlaylistAndCache(loadingRequest: AVAssetResourceLoadingRequest, realURL: URL, requestID: String) {
        Task {
            do {
                let data = try await mainPlaylistData(url: realURL)
                // send unmodified
                loadingRequest.dataRequest?.respond(with: data)
                // logging
                if let originalPlaylist = String(data: data, encoding: .utf8) {
                    let lines = originalPlaylist.components(separatedBy: .newlines)
                    let lastSegment: String
                    if lines.count > 2 {
                        lastSegment = lines[lines.count-2] // last line is blank
                    } else {
                        lastSegment = ""
                    }
                    if let lastSegmentURL = URL(string: lastSegment) {
                        log.info("\(requestID): responded with unmodified main playlist - UP TO: \(lastSegmentURL.lastPathComponent)")
                    }
                }
                // send
                loadingRequest.finishLoading()
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }
    }
    
    private func serveGeneratedPlainCaptionPlaylist(loadingRequest: AVAssetResourceLoadingRequest) {
        let lastTime: Int = vodDurationSeconds ?? 60*60
        let playlist = PlaylistWriter.generatePlainSubtitlesPlaylist(lastTime: lastTime, proxyHost: captionProxyHost)
        loadingRequest.dataRequest?.respond(with: playlist.data(using: .utf8)!)
        log.info("responded with generated plain captions playlist - last time: \(lastTime)s ")
        loadingRequest.finishLoading()
    }

    var latestDASHPlaylistSegment: String?
    var latestDASHPlaylist: String?
    private func serveGeneratedDASHCaptionPlaylist(loadingRequest: AVAssetResourceLoadingRequest, requestID: String) {
        Task {
            do {
                let data = try await latestMainPlaylistData()
                guard let originalPlaylist = String(data: data, encoding: .utf8) else {
                    log.error("main playlist data was not a string")
                    loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: 500))
                    return
                }
                let (playlist, lastSegment) = PlaylistWriter.generateDASHSubtitlesPlaylist(videoPlaylist: originalPlaylist, proxyHost: captionProxyHost)
                
                if lastSegment >= latestDASHPlaylistSegment ?? "" {
                    // last segment must increase monotonically
                    // or AVPlayer will start to request every single segment in the playlist
                    loadingRequest.dataRequest?.respond(with: playlist.data(using: .utf8)!)
                    log.info("\(requestID): responded with generated DASH captions playlist - UP TO: \(lastSegment)")
                    latestDASHPlaylistSegment = lastSegment
                    latestDASHPlaylist = playlist
                } else if let latestDASHPlaylist {
                    // previous playlist is better than going backwards
                    loadingRequest.dataRequest?.respond(with: latestDASHPlaylist.data(using: .utf8)!)
                    log.info("\(requestID): responded with *stored* DASH captions playlist - UP TO: \(self.latestDASHPlaylistSegment ?? "")")
                    log.info("\(requestID): instead of latest recieved (going backwards?!) - UP TO: \(lastSegment)")
                } else {
                    log.error("very unexpected latestDASHPlaylist == nil")
                    loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: 500))
                    return
                }

                loadingRequest.finishLoading()
            } catch {
                loadingRequest.finishLoading(with: error)
            }
        }
    }
    
    private func extractRealURL(for loadingRequest: AVAssetResourceLoadingRequest) -> URL? {
        guard let requestURL = loadingRequest.request.url,
              requestURL.absoluteString.hasPrefix(schemePrefix) else { return nil }
        let realScheme = requestURL.scheme?.replacingOccurrences(of: schemePrefix, with: "")
        guard var realURLComponents = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else { return nil }
        realURLComponents.scheme = realScheme
        guard let realURL = realURLComponents.url else { return nil }
        return realURL
    }
}
