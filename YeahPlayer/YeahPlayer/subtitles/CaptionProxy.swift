//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import os

fileprivate let log = Logger(category: CaptionProxy.self)

@preconcurrency
final class CaptionProxy {
    
    @MainActor
    static let shared = CaptionProxy()
    
    private var media: BBCMedia?
    private var mediaQueue = DispatchQueue(label: "captionProxyMedia", attributes: .concurrent)
    func updateMedia(newValue: BBCMedia?) {
        mediaQueue.sync(flags: .barrier) {
            media = newValue
        }
    }
    
    private static let defaultPort: UInt16 = 8080
    private var port: UInt = 0
    var hostWithPort: String {
        assert(port != 0, "port not set - server not started?")
        return "127.0.0.1:\(port)"
    }
    
    var isRunning: Bool {
        webServer.isRunning
    }
 
    private let webServer = GCDWebServer()
    
    private let session = URLSession(configuration: .default)
    
    func startWebServer() {
        let firstFreePort = try? reservePort()
        self.port = UInt(firstFreePort ?? CaptionProxy.defaultPort)
        addPlainCaptionHandler()
        addDASHCaptionHandler()
        GCDWebServer.setLogLevel(4) // 4 = kGCDWebServerLoggingLevel_Error but is private 🙈
        webServer.start(withPort: self.port, bonjourName: nil)
        log.info("web server started on port \(self.port)")
    }
    
    private func addPlainCaptionHandler() {
        self.webServer.addHandler(forMethod: "GET",
                                  pathRegex: "\\/subtitles\\/plain\\.webvtt",
                                  request: GCDWebServerRequest.self) { [weak self] request, completion in
            guard let self else {
                log.error("self deallocated?!")
                return
            }
            replacePlainCaptions(completion: completion)
        }
    }
    
    private func addDASHCaptionHandler() {
        self.webServer.addHandler(forMethod: "GET",
                                  pathRegex: "\\/subtitles\\/dash\\/", // /subtitles/dash/\(number).webvtt
                                  request: GCDWebServerRequest.self) { [weak self] request, completion in
            guard let self else {
                log.error("self deallocated?!")
                return
            }
            replaceDASHCaptions(request: request, completion: completion)
        }
    }
    
    private func replacePlainCaptions(completion: @escaping GCDWebServerCompletionBlock ) {
        mediaQueue.sync {
            guard case .plain(let captions) = self.media?.captions,
               let captionsURL = URL(string: captions.href) else {
                log.error("cannot convert plain captions: missing or invalid URL")
                completion(GCDWebServerErrorResponse(statusCode: 500))
                return
            }
            let task = self.session.dataTask(with: captionsURL) { data, response, error in
                guard let data = data, let response = response else {
                    log.error("error: \(String(describing: error))")
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                
                log.info("proxy converting plain captions (VOD)")
                let parser = TTMLCaptionParser()
                let subs_if = parser.parse(xmlData: data)
                let formatter = WebVTTCaptionFormatter()
                let webVTT = formatter.format(input: subs_if)
                let webVTTString = webVTT.joined(separator: "\n")
                let outData = webVTTString.data(using: .utf8)!
                // TODO: cache this, it gets requested every time we seek
                let contentType = response.mimeType ?? "binary/octet-stream"
                let proxyResp = GCDWebServerDataResponse(data: outData, contentType: contentType)
                completion(proxyResp)
            }
            
            task.resume()
        }
    }
    
    private func replaceDASHCaptions(request: GCDWebServerRequest, completion: @escaping GCDWebServerCompletionBlock ) {
        guard let segmentID = request.url.lastPathComponent.components(separatedBy: ".").first else {
            log.error("URL parsing error")
            return completion(GCDWebServerErrorResponse(statusCode: 500))
        }
        
        mediaQueue.sync {
            guard case .dash(let captions) = self.media?.captions,
                  let realCaptionSegmentURL = captions.href(number: segmentID) else {
                log.error("URL formatting error")
                return completion(GCDWebServerErrorResponse(statusCode: 500))
            }
            
            log.debug("\(request.url.absoluteString)")
            log.debug("\(realCaptionSegmentURL)")
            
            let task = self.session.dataTask(with: realCaptionSegmentURL) { data, response, error in
                guard let data = data, let response = response else {
                    log.error("error: \(String(describing: error))")
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                
                // search for XML start marker
                let xmlStart = "<?xml".data(using: .utf8)!
                guard let xmlStartRange = data.range(of: xmlStart) else {
                    log.error("XML (TTML) not found in segment")
                    return completion(GCDWebServerErrorResponse(statusCode: 500))
                }
                // extract XML data
                let xmlData = data.subdata(in: xmlStartRange.lowerBound..<data.count)
                
                log.info("proxy converting subs from ...\(realCaptionSegmentURL.lastPathComponent)")
                let parser = TTMLCaptionParser()
                let subs_if = parser.parse(xmlData: xmlData)
                let formatter = WebVTTCaptionFormatter()
                let webVTT = formatter.format(input: subs_if, tsOffset: "200000")
                let webVTTString = webVTT.joined(separator: "\n")
                let outData = webVTTString.data(using: .utf8)!
                let contentType = response.mimeType ?? "binary/octet-stream"
                let proxyResp = GCDWebServerDataResponse(data: outData, contentType: contentType)
                completion(proxyResp)
            }
            
            task.resume()
        }
    }
    
    
}
