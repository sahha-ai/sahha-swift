// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import HealthKit

struct HealthLogRequest: Encodable {
    var id: String
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
    var parentId: String?
    
    init(_ uuid: UUID, healthType: HealthTypeIdentifier, value: Double, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: String? = nil) {
        self.init(uuid, logType: healthType.sensorType.rawValue, dataType: healthType.rawValue, value: value, unit: healthType.unitString, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate, additionalProperties: additionalProperties, parentId: parentId)
    }
    
    init(_ uuid: UUID, logType: String, dataType: String, value: Double, unit: String, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: String? = nil) {
        self.id = uuid.uuidString
        self.logType = logType
        self.dataType = dataType
        self.value = value
        self.unit = unit
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toDateTime
        self.endDateTime = endDate.toDateTime
        self.additionalProperties = additionalProperties
        self.parentId = parentId
    }
}

enum HealthLogPropertyIdentifier: String {
    case bodyPosition
    case measurementLocation
    case measurementMethod
    case motionContext
    case relationToMeal
}

enum SleepStage: String {
    case sleep_stage_unknown
    case sleep_stage_in_bed
    case sleep_stage_awake
    case sleep_stage_rem
    case sleep_stage_light
    case sleep_stage_deep
    case sleep_stage_sleeping
}

enum BloodRelationToMeal: String {
    case unknown
    case before_meal
    case after_meal
}

enum HealthTypeIdentifier: String, CaseIterable {
    case sleep
    case step_count
    case floor_count
    case heart_rate
    case resting_heart_rate
    case walking_heart_rate_average
    case heart_rate_variability_sdnn
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case blood_glucose
    case vo2_max
    case oxygen_saturation
    case respiratory_rate
    case active_energy_burned
    case basal_energy_burned
    case time_in_daylight
    case body_temperature
    case basal_body_temperature
    case sleeping_wrist_temperature
    case height
    case weight
    case lean_body_mass
    case body_mass_index
    case body_fat
    case waist_circumference
    // case stand_time
    // case move_time
    // case exercise_time
    case activity_summary
    
    var keyName: String {
        "sahha_".appending(self.rawValue)
    }
    
    var objectType: HKObjectType? {
        return switch self {
        case .sleep:
            HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        case .step_count:
            HKSampleType.quantityType(forIdentifier: .stepCount)!
        case .floor_count:
            HKSampleType.quantityType(forIdentifier: .flightsClimbed)!
        case .heart_rate:
            HKSampleType.quantityType(forIdentifier: .heartRate)!
        case .resting_heart_rate:
            HKSampleType.quantityType(forIdentifier: .restingHeartRate)!
        case .walking_heart_rate_average:
            HKSampleType.quantityType(forIdentifier: .walkingHeartRateAverage)!
        case .heart_rate_variability_sdnn:
            HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        case .blood_pressure_systolic:
            HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!
        case .blood_pressure_diastolic:
            HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
        case .blood_glucose:
            HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
        case .vo2_max:
            HKSampleType.quantityType(forIdentifier: .vo2Max)!
        case .oxygen_saturation:
            HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!
        case .respiratory_rate:
            HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
        case .active_energy_burned:
            HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!
        case .basal_energy_burned:
            HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!
        case .time_in_daylight:
            if #available(iOS 17.0, *) {
                HKSampleType.quantityType(forIdentifier: .timeInDaylight)!
            } else {
                nil
            }
        case .body_temperature:
            HKSampleType.quantityType(forIdentifier: .bodyTemperature)!
        case .basal_body_temperature:
            HKSampleType.quantityType(forIdentifier: .basalBodyTemperature)!
        case .sleeping_wrist_temperature:
            if #available(iOS 16.0, *) {
                HKSampleType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
            } else {
                nil
            }
        case .height:
            HKSampleType.quantityType(forIdentifier: .height)!
        case .weight:
            HKSampleType.quantityType(forIdentifier: .bodyMass)!
        case .lean_body_mass:
            HKSampleType.quantityType(forIdentifier: .leanBodyMass)!
        case .body_mass_index:
            HKSampleType.quantityType(forIdentifier: .bodyMassIndex)!
        case .body_fat:
            HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!
        case .waist_circumference:
            HKSampleType.quantityType(forIdentifier: .waistCircumference)!
            /*
        case .stand_time:
            HKSampleType.quantityType(forIdentifier: .appleStandTime)!
        case .move_time:
            if #available(iOS 14.5, *) {
                HKSampleType.quantityType(forIdentifier: .appleMoveTime)!
            } else {
                nil
            }
        case .exercise_time:
            HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
             */
        case .activity_summary:
            HKSampleType.activitySummaryType()
        }
    }
    
    internal var unit: HKUnit {
        return switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            .count().unitDivided(by: .minute())
        case .heart_rate_variability_sdnn:
            .secondUnit(with: .milli)
        case .vo2_max:
            HKUnit(from: "ml/kg*min")
        case .oxygen_saturation, .body_fat:
            .percent()
        case .respiratory_rate:
            .count().unitDivided(by: .second())
        case .active_energy_burned, .basal_energy_burned:
            .largeCalorie()
        case .time_in_daylight/* , .stand_time, .move_time, .exercise_time */:
            .minute()
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            .degreeCelsius()
        case .height, .waist_circumference:
            .meter()
        case .weight, .lean_body_mass:
            .gramUnit(with: .kilo)
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            .millimeterOfMercury()
        case .blood_glucose:
            HKUnit(from: "mg/dL")
        case .sleep, .step_count, .floor_count, .body_mass_index, .activity_summary:
            .count()
        }
    }
    
    internal var unitString: String {
        return switch self {
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average:
            "bpm"
        case .heart_rate_variability_sdnn:
            "ms"
        case .vo2_max:
            "ml/kg/min"
        case .oxygen_saturation, .body_fat:
            "percent"
        case .respiratory_rate:
            "bps"
        case .active_energy_burned, .basal_energy_burned:
            "kcal"
        case .sleep, .time_in_daylight/* , .stand_time, .move_time, .exercise_time */:
            "minute"
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            "degC"
        case .height, .waist_circumference:
            "m"
        case .weight, .lean_body_mass:
            "kg"
        case .blood_pressure_systolic, .blood_pressure_diastolic:
            "mmHg"
        case .blood_glucose:
            "mg/dL"
        case .step_count, .floor_count, .body_mass_index, .activity_summary:
            "count"
        }
    }
    
    internal var sensorType: SahhaSensor {
        return switch self {
        case .sleep:
            .sleep
        case .step_count, .floor_count, /* .move_time, .stand_time, .exercise_time, */.activity_summary:
            .activity
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn:
            .heart
        case .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose:
            .blood
        case .oxygen_saturation, .vo2_max, .respiratory_rate:
            .oxygen
        case .active_energy_burned, .basal_energy_burned, .time_in_daylight:
            .energy
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            .temperature
        case .height, .weight, .lean_body_mass, .body_mass_index, .body_fat, .waist_circumference:
            .body
        }
    }
}
