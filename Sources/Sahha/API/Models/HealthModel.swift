// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct HealthRequest: Encodable {
    var dataType: String
    var count: Double
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    
    init(dataType: String, count: Double, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date) {
        self.dataType = dataType
        self.count = count
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}

