// Copyright © 2022 Sahha. All rights reserved.

import Foundation

enum SleepStage: String {
    case unknown = "STAGE_TYPE_UNKNOWN"
    case inBed = "STAGE_TYPE_IN_BED"
    case awake = "STAGE_TYPE_AWAKE"
    case asleepREM = "STAGE_TYPE_SLEEPING_REM"
    case asleepCore = "STAGE_TYPE_SLEEPING_LIGHT"
    case asleepDeep = "STAGE_TYPE_SLEEPING_DEEP"
    case asleepUnspecified = "STAGE_TYPE_SLEEPING"
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
