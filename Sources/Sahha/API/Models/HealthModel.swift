// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct HealthRequest: Encodable {
    var dataType: String
    var count: Double
    var source: String
    var manuallyEntered: Bool
    var startDateTime: String
    var endDateTime: String
    
    init(dataType: String, count: Double, source: String, manuallyEntered: Bool, startDate: Date, endDate: Date) {
        self.dataType = dataType
        self.count = count
        self.source = source
        self.manuallyEntered = manuallyEntered
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}

