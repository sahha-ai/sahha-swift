// Copyright © 2022 Sahha. All rights reserved.

import Foundation

enum SleepStage: String {
    case unknown = "unknown"
    case inBed = "in_bed"
    case awake = "awake"
    case asleepREM = "rem"
    case asleepCore = "light"
    case asleepDeep = "deep"
    case asleepUnspecified = "sleeping"
}

struct SleepRequest: Encodable, Hashable {
    var sleepStage: String
    var durationInMinutes: Int
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    
    init(stage: SleepStage, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date) {
        self.sleepStage = stage.rawValue
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.durationInMinutes = difference.minute ?? 0
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
