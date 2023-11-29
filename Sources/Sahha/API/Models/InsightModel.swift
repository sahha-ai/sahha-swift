// Copyright © 2023 Sahha. All rights reserved.

import Foundation

public enum SahhaInsightIdentifier: String, Codable {
    case TimeInBedDailyTotal
    case TimeAsleepDailyTotal
    case TimeInREMSleepDailyTotal
    case TimeInLightSleepDailyTotal
    case TimeInDeepSleepDailyTotal
    case StepCountDailyTotal
    case StandHoursDailyTotal
    case StandHoursDailyGoal
    case MoveTimeDailyTotal
    case MoveTimeDailyGoal
    case ExerciseTimeDailyTotal
    case ExerciseTimeDailyGoal
    case ActiveEnergyBurnedDailyTotal
    case ActiveEnergyBurnedDailyGoal
}

public struct SahhaInsight: Codable {
    public var name: SahhaInsightIdentifier
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
        self.name = insight.name.rawValue
        self.value = insight.value
        self.unit = insight.unit
        self.startDateTime = insight.startDate.toTimezoneFormat
        self.endDateTime = insight.endDate.toTimezoneFormat
    }
}
