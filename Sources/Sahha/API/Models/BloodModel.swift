// Copyright © 2023 Sahha. All rights reserved.

import Foundation

enum BloodRelationToMeal: String {
    case unknown = "Unknown"
    case beforeMeal = "Before Meal"
    case afterMeal = "After Meal"
}

struct BloodRequest: Encodable {
    var dataType: String
    var count: Double
    var unit: String?
    var relationToMeal: String?
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    
    init(dataType: String, count: Double, unit: String?, relationToMeal: BloodRelationToMeal?, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date) {
        self.dataType = dataType
        self.count = count
        if let string = unit {
            self.unit = string
        }
        if let string = relationToMeal?.rawValue {
            self.relationToMeal = string
        }
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
