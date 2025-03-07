//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import Foundation

struct SearchItem: CustomDebugStringConvertible {
    let id: String
    let type: String
    let title: String
    let subtitle: String?
    let imageURL: URL?
    
    var debugDescription: String {
        let type_code = type == "episode" ? "E" : "S"
        return "\(type_code) \(id): \(title), \(String(describing: subtitle)), \(String(describing: imageURL))"
    }
    
    var isEpisode: Bool {
        type == "episode"
    }
}

final class SearchParser: Sendable {
    
    struct SearchResponse: Codable {
        let version: String
        let schema: String
        let newSearch: NewSearch
        
        enum CodingKeys: String, CodingKey {
            case version, schema
            case newSearch = "new_search"
        }
    }

    struct NewSearch: Codable {
        let query: String
        let results: [SearchResult]
    }

    struct SearchResult: Codable, Hashable {
        let id: String
        let type: String
        let title: String
        let subtitle: String?
        let images: Images
        let lexicalSortLetter: String
        let count: Int?
        
        enum CodingKeys: String, CodingKey {
            case id, type, title, subtitle, images
            case lexicalSortLetter = "lexical_sort_letter"
            case count
        }
        
        var image: URL? {
            let recipe = "464x261"
            let thumb = images.standard.replacingOccurrences(of: "{recipe}", with: recipe)
            return URL(string: thumb)
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
            return lhs.id == rhs.id
        }
    }

    struct Images: Codable {
        let type: String
        let standard: String
        let promotional: String?
        let promotionalWithLogo: String?
        
        enum CodingKeys: String, CodingKey {
            case type, standard, promotional
            case promotionalWithLogo = "promotional_with_logo"
        }
    }

    func extractSearchResults(jsonData: Data) throws -> [SearchResult] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SearchResponse.self, from: jsonData)
        return response.newSearch.results
    }
}
