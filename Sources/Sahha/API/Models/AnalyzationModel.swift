// 

import Foundation

struct AnalyzationRequest: Encodable {
    var startDateTime: String?
    var endDateTime: String?
    var includeSourceData: Bool
    
    init(startDate: Date?, endDate: Date?, includeSourceData: Bool) {
        self.startDateTime = startDate?.toTimezoneFormat
        self.endDateTime = endDate?.toTimezoneFormat
        self.includeSourceData = includeSourceData
    }
}

struct AnalyzationResponse: Codable {
    var id: String
    var createdAt: String
    var state: String
    var subState: String
    var range: Int
    var confidence: Double
    var phenotypes: [String]
}
