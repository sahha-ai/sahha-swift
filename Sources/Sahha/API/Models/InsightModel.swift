//
//  InsightModel.swift
//  Sahha
//
//  Created by Desislav Hristov on 26.09.25.
//

public enum SahhaInsightTrendCategory {
    case score(SahhaInsightScore)
    case factor(SahhaInsightFactor)
}

public enum SahhaInsightComparisonCategory {
    case score(SahhaInsightScore)
    case biomarker(SahhaInsightBiomarker)
}

public enum SahhaInsightScore: String {
    case sleep
    case activity
    case readiness
    case wellbeing
    case mental_wellbeing
}

public enum SahhaInsightFactor: String {
    case sleep_duration
    case sleep_regularity
    case sleep_continuity
    case sleep_debt
    case circadian_alignment
    case physical_recovery
    case mental_recovery
    case steps
    case active_hours
    case active_calories
    case intense_activity_duration
    case extended_inactivity
    case floors_climbed
    case activity_regularity
    case walking_strain_capacity
    case exercise_strain_capacity
    case resting_heart_rate
    case heart_rate_variability
}

public enum SahhaInsightBiomarker: String {
    case steps
    case sleep_duration
    case heart_rate_resting
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case vo2_max
}
