// 

import Foundation

struct AnalyzationResponse: Codable {
    var id: String
    var createdAt: String
    var state: String
    var subState: String
    var range: Int
    var confidence: Double
    var phenotypes: [String]
}
