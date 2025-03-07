//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

class WebVTTCaptionFormatter {
    
    // MARK: - data models
    
    struct RegionStyle {
        enum VAlign: String {
            case before, center, after
        }
        
        enum Align: String {
            case left, center, right
        }
        
        let id: String
        let originString: String
        let extentString: String
        let displayAlignString: String
        
        var rect: CGRect {
            CGRect(origin: origin, size: size)
        }
        
        var size: CGSize {
            guard let (w, h) = values(input: extentString) else { return .zero }
            return CGSize(width: w, height: h)
        }
        
        var origin: CGPoint {
            guard let (x, y) = values(input: originString) else { return .zero }
            return CGPoint(x: x, y: y)
        }
        
        func values(input: String) -> (CGFloat, CGFloat)? {
            let comp = input.components(separatedBy: " ")
            guard comp.count == 2 else { return nil }
            guard let a = Float(comp[0].replacingOccurrences(of: "%", with: "")),
                  let b = Float(comp[1].replacingOccurrences(of: "%", with: "")) else {
                return nil
            }
            return (CGFloat(a), CGFloat(b))
        }
        
        var vAlign: VAlign? {
            VAlign(rawValue: displayAlignString)
        }
        
        // e.g. line:0 align:left position:0% size:50%
        var webVTTPosition: String {
            return "line:\(pcdp(origin.y)) align:center position:\(pcdp(position)) size:\(pcdp(size.width))"
        }
        
        var position: CGFloat {
            var mid = rect.midX
            if mid > 45 && mid < 55 { mid = 50 } // snap to centre
            return mid
        }
        
        func pcdp(_ number: CGFloat) -> String {
            let suffix = (number.isZero) ? "" : "%"
            return String(format: "%.0f", number) + suffix
        }
    }
    
    struct ColorStyle {
        let id: String
        let color: String
        let backgroundColor: String
    }
    
    // MARK: -
    
    func format(input: TTMLCaptionParser.Output, tsOffset: String = "900000") -> [String] {
        // create cue styles from any styles with colors
        var colorStyles: [String: ColorStyle] = [:]
        for style in input.styles {
            if let color = style.color,
               let backgroundColor = style.backgroundColor {
                colorStyles[style.id] = ColorStyle(id: style.id,
                                                   color: color,
                                                   backgroundColor: backgroundColor)
            }
        }
        
        // create region styles
        var regionStyles: [String: RegionStyle] = [:]
        for region in input.regions {
            if let origin = region.origin,
               let extent = region.extent,
               let displayAlign = region.displayAlign {
                let id = region.id
                regionStyles[id] = RegionStyle(id: id, originString: origin, extentString: extent, displayAlignString: displayAlign)
            }
        }
        
        // webVTT < header
        var out = [
            "WEBVTT",
            "X-TIMESTAMP-MAP=MPEGTS:\(tsOffset),LOCAL:00:00:00.000",
            ""
        ]
        
        // webVTT < cue styles
        var csout: [String] = []
        colorStyles.values.forEach { cs in
            csout.append(contentsOf: [
                "STYLE",
                "::cue(.\(cs.id)) {",
                "  color: \(cs.color);",
                "  background-color: \(cs.backgroundColor);",
                "}",
                "",
            ])
        }
        out.append(contentsOf: csout)

        // webVTT < captions + positions
        for subtitle in input.subtitles {
            var positionSuffix = ""
            if let regionStyle = regionStyles[subtitle.region] {
                // convert region-based style into position params for each subtitle
                positionSuffix = regionStyle.webVTTPosition
            }
            out.append("\(subtitle.begin) --> \(subtitle.end) \(positionSuffix)")
            var inner: [String] = []
            for subsub in subtitle.text {
                if let lineStyle = subsub.styleID {
                    inner.append("<c.\(lineStyle)>\(subsub.text)</c>")
                } else {
                    inner.append(subsub.text)
                }
            }
            out.append(inner.joined(separator: " "))
            out.append("")
        }
        return out
    }
}
