// Copyright © 2022 Sahha. All rights reserved.

import Foundation

struct DataLogRequest: Encodable {
    var logType: String
    var dataType: String
    var value: Double
    var unit: String
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    var additionalProperties: [String: String]?
    var childLogs: [DataLogRequest]?
    
    init(logType: SahhaSensor, dataType: String, value: Double, unit: String, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, childLogs: [DataLogRequest]? = nil) {
        self.logType = logType.rawValue
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
        self.additionalProperties = additionalProperties
        self.childLogs = childLogs
    }
}

enum DataLogPropertyIdentifier: String {
    case bodyPosition
    case measurementLocation
    case measurementMethod
    case motionContext
    case relationToMeal
}

enum SleepStage: String {
    case unknown = "sleep_stage_unknown"
    case inBed = "sleep_stage_in_bed"
    case awake = "sleep_stage_awake"
    case asleepREM = "sleep_stage_rem"
    case asleepCore = "sleep_stage_light"
    case asleepDeep = "sleep_stage_deep"
    case asleepUnspecified = "sleep_stage_sleeping"
}

enum BloodRelationToMeal: String {
    case unknown = "unknown"
    case beforeMeal = "before_meal"
    case afterMeal = "after_meal"
}
