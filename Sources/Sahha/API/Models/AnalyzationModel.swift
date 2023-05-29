// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct AnalyzationRequest: Encodable {
    var startDateTime: String?
    var endDateTime: String?
    
    init(startDate: Date?, endDate: Date?) {
        self.startDateTime = startDate?.toTimezoneFormat
        self.endDateTime = endDate?.toTimezoneFormat
    }
}

struct AnalyzationResponse: Codable {
    var id: String
    var state: String
    var subState: String
    var range: Int
    var confidence: Double
    var phenotypes: [String]
}
