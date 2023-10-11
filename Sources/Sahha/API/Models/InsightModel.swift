// Copyright © 2023 Sahha. All rights reserved.

import Foundation

public struct SahhaInsight: Codable {
    public var name: String
    public var value: Double
    public var unit: String
    public var startDate: Date
    public var endDate: Date
}

public struct SahhaInsightRequest: Codable {
    public var name: String
    public var value: Double
    public var unit: String
    public var startDateTime: String
    public var endDateTime: String
    
    public init(_ insight: SahhaInsight) {
        self.name = insight.name
        self.value = insight.value
        self.unit = insight.unit
        self.startDateTime = insight.startDate.toTimezoneFormat
        self.endDateTime = insight.endDate.toTimezoneFormat
    }
}
