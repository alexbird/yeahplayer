//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

class PlaylistWriter {
    
    static func addSubtitles(toMasterPlaylist original: String) -> String {
        var lines = original.components(separatedBy: "\n")
        
        for (n, line) in lines.enumerated() {
            if line.starts(with: "#EXT-X-STREAM-INF") {
                lines[n] = line + ",SUBTITLES=\"subs\""
            }
        }
        
        lines.append("""
    
    #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",DEFAULT=YES,AUTOSELECT=YES,FORCED=NO,LANGUAGE="en",CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog, public.accessibility.describes-music-and-sound",URI="yeah/subtitles/eng/prog_index.m3u8"
    """)
        
        let withSubs = lines.joined(separator: "\n")
        
        return withSubs
    }
        
    static func generatePlainSubtitlesPlaylist(lastTime: Int, proxyHost: String) -> String {
        let playlist = """
    #EXTM3U,
    #EXT-X-TARGETDURATION: \(lastTime),
    #EXT-X-VERSION:3,
    #EXT-X-MEDIA-SEQUENCE:0,
    #EXT-X-PLAYLIST-TYPE:VOD,
    #EXTINF: \(lastTime),
    \(schemePrefix)http://\(proxyHost)/subtitles/plain.webvtt
    #EXT-X-ENDLIST
    """
        
        return playlist
    }
    
    static func generateDASHSubtitlesPlaylist(videoPlaylist: String, proxyHost: String) -> (String, String) {
        var lines = videoPlaylist.components(separatedBy: .newlines)
        var lastNumber: String?
        for (index, line) in lines.enumerated() {
            // check if the line contains a .ts file
            if line.hasSuffix(".ts") {
                // extract the number from the .ts filename
                if let number = line.components(separatedBy: ".").first {
                    // create the new subtitle URL
                    let subtitleURL = "\(schemePrefix)http://\(proxyHost)/subtitles/dash/\(number).webvtt"
                    // replace the line
                    lines[index] = subtitleURL
                    // track last segment for logging
                    lastNumber = number
                }
            }
        }
        
        return (lines.joined(separator: "\n"), lastNumber ?? "")
    }
}
