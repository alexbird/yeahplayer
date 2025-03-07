//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation

class TTMLCaptionParser: NSObject, XMLParserDelegate {
    
    // MARK: - data models
    
    struct Style: Codable {
        let id: String
        let color: String?
        let backgroundColor: String?
        let textAlign: String?
        let fontSize: String?
        let lineHeight: String?
        let fontFamily: String?
        let linePadding: String?
        let fillLineGap: String?
    }

    struct Region: Codable {
        let id: String
        let displayAlign: String?
        let overflow: String?
        let extent: String?
        let origin: String?
    }

    struct Subtitle: Codable {
        let id: String
        let region: String
        let begin: String
        let end: String
        let text: [Subsubtitle]
        let styleIds: [String]
    }
    
    struct Subsubtitle: Codable {
        let text: String
        let styleID: String?
    }
    
    struct Output: Codable {
        let styles: [Style]
        let regions: [Region]
        let subtitles: [Subtitle]
    }
    
    // storage
    private var subtitles: [Subtitle] = []
    private var styles: [Style] = []
    private var regions: [Region] = []
    
    // current parsing state
    private var currentElement: String = ""
    private var inStyling = false
    private var inLayout = false
    
    // current subtitle data
    private var currentId: String = ""
    private var currentRegion: String = ""
    private var currentBegin: String = ""
    private var currentEnd: String = ""
    private var currentSpans: [Subsubtitle] = []
    private var currentText: String = ""
    private var currentStyles: [String] = []
    private var currentSpanStyle: String?
    
    // text collection state
    private var isCollectingText = false
    
    // MARK: - 
    
    func parse(xmlData: Data) -> Output {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        parser.parse()
        return Output(styles: styles, regions: regions, subtitles: subtitles)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        
        switch elementName {
            case "styling":
                inStyling = true
                
            case "layout":
                inLayout = true
                
            case "style":
                if let id = attributeDict["xml:id"] {
                    let style = Style(
                        id: id,
                        color: attributeDict["tts:color"],
                        backgroundColor: attributeDict["tts:backgroundColor"],
                        textAlign: attributeDict["tts:textAlign"],
                        fontSize: attributeDict["tts:fontSize"],
                        lineHeight: attributeDict["tts:lineHeight"],
                        fontFamily: attributeDict["tts:fontFamily"],
                        linePadding: attributeDict["ebutts:linePadding"],
                        fillLineGap: attributeDict["itts:fillLineGap"]
                    )
                    styles.append(style)
                }
                
            case "region":
                if let id = attributeDict["xml:id"] {
                    let region = Region(
                        id: id,
                        displayAlign: attributeDict["tts:displayAlign"],
                        overflow: attributeDict["tts:overflow"],
                        extent: attributeDict["tts:extent"],
                        origin: attributeDict["tts:origin"]
                    )
                    regions.append(region)
                }
                
            case "p":
                currentId = attributeDict["xml:id"] ?? ""
                currentRegion = attributeDict["region"] ?? ""
                currentBegin = attributeDict["begin"] ?? ""
                currentEnd = attributeDict["end"] ?? ""
                currentSpans = []
                currentStyles = []
                currentSpanStyle = nil
                
                // add paragraph style if present
                if let style = attributeDict["style"] {
                    currentStyles.append(style)
                }
                
                currentText = ""
                isCollectingText = true
                
            case "span":
                // add span style if present
                if let style = attributeDict["style"] {
                    if currentSpanStyle == nil {
                        currentSpanStyle = style
                    } else if style != currentSpanStyle {
                        // close span/style
                        let sst = Subsubtitle(text: currentText, styleID: currentSpanStyle)
                        currentSpans.append(sst)                        
                        // new span/style
                        currentSpanStyle = style
                        currentText = ""
                    }
                }
                isCollectingText = true
                
            case "div":
                // add div styles if present
                if let style = attributeDict["style"] {
                    // split space-separated style IDs
                    let styles = style.components(separatedBy: " ")
                    currentStyles.append(contentsOf: styles)
                }
                
            default:
                break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
            case "styling":
                inStyling = false
                
            case "layout":
                inLayout = false
                
            case "p":
                // close span/style
                let sst = Subsubtitle(text: currentText, styleID: currentSpanStyle)
                currentSpans.append(sst)
                // add p group
                let subtitle = Subtitle(
                    id: currentId,
                    region: currentRegion,
                    begin: currentBegin,
                    end: currentEnd,
                    text: currentSpans,
                    styleIds: currentStyles
                )
                subtitles.append(subtitle)
                isCollectingText = false
                currentStyles = []
                currentSpanStyle = nil
                
            case "span":
                isCollectingText = false
                
            case "br":
                currentText += "\n"
                
            default:
                break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isCollectingText {
            let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedString.isEmpty {
                currentText += trimmedString
            }
        }
    }
}
