// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct HealthRequest: Encodable {
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    
    init(dataType: String, value: Double, unit: String, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date) {
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
