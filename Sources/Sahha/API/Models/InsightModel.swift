// Copyright © 2023 Sahha. All rights reserved.

import Foundation

public struct SahhaInsight: Codable {
    public var name: String
    public var value: Double
    public var unit: String?
    public var startDateTime: String
    public var endDateTime: String
    
    public init(name: String, value: Double, unit: String?, startDate: Date, endDate: Date) {
        self.name = name
        self.value = value
        self.unit = unit
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
