// Copyright © 2023 Sahha. All rights reserved.

import Foundation

public enum SahhaInsightIdentifier: String, Codable, CaseIterable {
    case time_in_bed_daily_total
    case time_asleep_daily_total
    case time_in_rem_sleep_daily_total
    case time_in_light_sleep_daily_total
    case time_in_deep_sleep_daily_total
    case step_count_daily_total
    case stand_hours_daily_total
    case stand_hours_daily_goal
    case move_time_daily_total
    case move_time_daily_goal
    case exercise_time_daily_total
    case exercise_time_daily_goal
    case active_energy_burned_daily_total
    case active_energy_burned_daily_goal
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
        self.startDateTime = insight.startDate.toDateTime
        self.endDateTime = insight.endDate.toDateTime
    }
}
