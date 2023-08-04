// Copyright © 2022 Sahha. All rights reserved.

import Foundation

enum SleepStage: String {
    case unknown = "Unknown"
    case inBed = "In Bed"
    case awake = "Awake"
    case asleep = "Asleep"
    case asleepREM = "Asleep REM"
    case asleepCore = "Asleep Core"
    case asleepDeep = "Asleep Deep"
    case asleepUnspecified = "Asleep Unspecified"
}

struct SleepRequest: Encodable, Hashable {
    var sleepStage: String
    var durationInMinutes: Int
    var source: String
    var manuallyEntered: Bool
    var startDateTime: String
    var endDateTime: String
    
    init(stage: SleepStage, source: String, manuallyEntered: Bool, startDate: Date, endDate: Date) {
        self.sleepStage = stage.rawValue
        self.source = source
        self.manuallyEntered = manuallyEntered
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.durationInMinutes = difference.minute ?? 0
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
