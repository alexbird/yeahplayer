//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Testing
import Foundation
@testable import YeahPlayer

struct YeahPlayerTests {
    
    @Test func testSubtitleConversion_short() async throws {
        let ttmlData = TestDataLoader.loadBundledData(filename: "ebu-tt-short", ext: "xml")!
        
        let parser = TTMLCaptionParser()
        let subtitles = parser.parse(xmlData: ttmlData)
        
        let formatter = WebVTTCaptionFormatter()
        let webVTT = formatter.format(input: subtitles)
        
        #expect(webVTT.count == 39)
        
        #expect(webVTT.count { $0.contains("STYLE") } == 2)
        
        let whiteStyleOffset = webVTT.enumerated().first {
            $0.element.hasPrefix("::cue(.S3)")
        }!.offset
        #expect(webVTT[whiteStyleOffset + 1].contains("color: #ffffffff"))
        #expect(webVTT[whiteStyleOffset + 2].contains("background-color: #000000ff"))
        
        let yellowStyleOffset = webVTT.enumerated().first {
            $0.element.hasPrefix("::cue(.S4)")
        }!.offset
        #expect(webVTT[yellowStyleOffset + 1].contains("color: #ffff00ff"))
        #expect(webVTT[yellowStyleOffset + 2].contains("background-color: #000000ff"))
        
        let wanderedOffset = webVTT.enumerated().first {
            $0.element.hasPrefix("00:00:02")
        }!.offset
        #expect(webVTT[wanderedOffset].contains("line:79%"))
        #expect(webVTT[wanderedOffset].contains("position:50%"))
        #expect(webVTT[wanderedOffset].contains("size:76%"))
        #expect(webVTT[wanderedOffset + 1].contains("<c.S3>"))
        #expect(webVTT[wanderedOffset + 1].contains("I wandered lonely as a cloud"))
        #expect(webVTT[wanderedOffset + 1].contains("That floats on high o'er vales and hills,"))
        
        let soundToLeftOffset = webVTT.enumerated().first {
            $0.element.hasPrefix("00:00:16.880")
        }!.offset
        #expect(webVTT[soundToLeftOffset].contains("line:87%"))
        #expect(webVTT[soundToLeftOffset].contains("position:26%"))
        #expect(webVTT[soundToLeftOffset].contains("size:27%"))
        #expect(webVTT[soundToLeftOffset + 1].contains("<c.S3>"))
        #expect(webVTT[soundToLeftOffset + 1].contains("LOUD NOISE TO LEFT"))
        
        let inQuotesOffset = webVTT.enumerated().first {
            $0.element.hasPrefix("00:00:08.360")
        }!.offset
        #expect(webVTT[inQuotesOffset].contains("line:79%"))
        #expect(webVTT[inQuotesOffset].contains("position:50%"))
        #expect(webVTT[inQuotesOffset].contains("size:74%"))
        let inQuotesLines = webVTT[inQuotesOffset + 1].split(separator: "\n")
        #expect(inQuotesLines[0].contains("<c.S3>"))
        #expect(inQuotesLines[0].contains("Beside the lake, beneath the trees,"))
        #expect(inQuotesLines[1].contains("Fluttering and dancing in the breeze."))
        #expect(inQuotesLines[2].contains("<c.S4>"))
        #expect(inQuotesLines[2].contains("\"This is in quotes and it is yellow\""))
    }
    
}

private class TestDataLoader {
    static func loadBundledData(filename: String, ext: String = "json") -> Data? {
        let bundle = Bundle(for: TestDataLoader.self)

        guard let fileUrl = bundle.url(forResource: filename, withExtension: ext) else {
            Issue.record("Resource not found in bundle: \(filename).json")
            return nil
        }

        guard let data = try? Data(contentsOf: fileUrl) else {
            Issue.record("Resource could not be loaded: \(filename).json")
            return nil
        }

        return data
    }
}
