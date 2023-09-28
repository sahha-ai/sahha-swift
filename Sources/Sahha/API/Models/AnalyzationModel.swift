// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct AnalysisRequest: Encodable {
    var startDateTime: String?
    var endDateTime: String?
    
    init(startDate: Date?, endDate: Date?) {
        self.startDateTime = startDate?.toTimezoneFormat
        self.endDateTime = endDate?.toTimezoneFormat
    }
}
