// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import HealthKit

struct DataLogRequest: Codable {
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
    
    init(_ uuid: UUID, sensor: SahhaSensor, value: Double, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: UUID? = nil) {
        self.init(uuid, logType: sensor.logType.rawValue, dataType: sensor.rawValue, value: value, unit: sensor.unitString, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate, additionalProperties: additionalProperties, parentId: parentId)
    }
    
    init(_ uuid: UUID, sensor: SahhaSensor, dataType: String, value: Double, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: UUID? = nil) {
        self.init(uuid, logType: sensor.logType.rawValue, dataType: dataType, value: value, unit: sensor.unitString, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate, additionalProperties: additionalProperties, parentId: parentId)
    }
    
    init(_ uuid: UUID, logType: SensorLogTypeIndentifier, activitySummary: ActivitySummaryIdentifier, value: Double, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: UUID? = nil) {
        self.init(uuid, logType: logType.rawValue, dataType: activitySummary.rawValue, value: value, unit: activitySummary.unitString, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate, additionalProperties: additionalProperties, parentId: parentId)
    }
    
    private init(_ uuid: UUID, logType: String, dataType: String, value: Double, unit: String, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date, additionalProperties: [String: String]? = nil, parentId: UUID? = nil) {
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
        self.parentId = parentId?.uuidString
    }
}

enum SensorLogTypeIndentifier: String {
    case demographic
    case sleep
    case activity
    case device
    case heart
    case blood
    case oxygen
    case energy
    case temperature
    case body
    case exercise
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

public enum ActivitySummaryIdentifier: String {
    case stand_hours_daily_total
    case stand_hours_daily_goal
    case move_time_daily_total
    case move_time_daily_goal
    case exercise_time_daily_total
    case exercise_time_daily_goal
    case active_energy_burned_daily_total
    case active_energy_burned_daily_goal
    
    internal var unitString: String {
        return switch self {
        case .stand_hours_daily_total,
        .stand_hours_daily_goal:
            "hour"
        case .move_time_daily_total,
        .move_time_daily_goal,
        .exercise_time_daily_total,
        .exercise_time_daily_goal:
            "minute"
        case .active_energy_burned_daily_total,
        .active_energy_burned_daily_goal:
            "kcal"
        }
    }
}
    
extension SahhaSensor {
    
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
        case .activity_summary:
            HKSampleType.activitySummaryType()
        case .gender:
            HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex)
        case .date_of_birth:
            HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth)
        case .exercise:
            HKWorkoutType.workoutType()
        case .device_lock:
            nil
        case .heart_rate_variability_rmssd:
            nil
        case .total_energy_burned:
            nil
        case .basal_metabolic_rate:
            nil
        case .body_water_mass:
            nil
        case .bone_mass:
            nil

        }
    }
    
    internal var unit: HKUnit? {
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
        case .time_in_daylight, .stand_time, .move_time, .exercise_time:
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
        case .sleep, .step_count, .floor_count, .body_mass_index:
            .count()
        case .gender, .date_of_birth, .device_lock, .exercise, .heart_rate_variability_rmssd, .activity_summary, .total_energy_burned, .basal_metabolic_rate, .body_water_mass, .bone_mass:
            nil
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
        case .sleep, .time_in_daylight, .stand_time, .move_time, .exercise_time:
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
        case .gender, .date_of_birth, .device_lock, .exercise, .heart_rate_variability_rmssd, .total_energy_burned, .basal_metabolic_rate, .body_water_mass, .bone_mass:
            "none"
        }
    }
    
    internal var logType: SensorLogTypeIndentifier {
        return switch self {
        case .gender, .date_of_birth:
            .demographic
        case .sleep:
            .sleep
        case .step_count, .floor_count, .move_time, .stand_time, .exercise_time, .activity_summary:
            .activity
        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .heart_rate_variability_rmssd:
            .heart
        case .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose:
            .blood
        case .oxygen_saturation, .vo2_max, .respiratory_rate:
            .oxygen
        case .active_energy_burned, .basal_energy_burned, .total_energy_burned, .basal_metabolic_rate, .time_in_daylight:
            .energy
        case .body_temperature, .basal_body_temperature, .sleeping_wrist_temperature:
            .temperature
        case .height, .weight, .lean_body_mass, .body_mass_index, .body_fat, .waist_circumference, .body_water_mass, .bone_mass:
            .body
        case .device_lock:
            .device
        case .exercise:
            .exercise
        }
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .americanFootball:             return "american_football"
        case .archery:                      return "archery"
        case .australianFootball:           return "australian_football"
        case .badminton:                    return "badminton"
        case .baseball:                     return "baseball"
        case .basketball:                   return "basketball"
        case .bowling:                      return "bowling"
        case .boxing:                       return "boxing"
        case .climbing:                     return "climbing"
        case .cricket:                      return "cricket"
        case .crossTraining:                return "cross_training"
        case .curling:                      return "curling"
        case .cycling:                      return "cycling"
        case .dance:                        return "dance"
        case .danceInspiredTraining:        return "dance_inspired_training"
        case .elliptical:                   return "elliptical"
        case .equestrianSports:             return "equestrian_sports"
        case .fencing:                      return "fencing"
        case .fishing:                      return "fishing"
        case .functionalStrengthTraining:   return "functional_strength_training"
        case .golf:                         return "golf"
        case .gymnastics:                   return "gymnastics"
        case .handball:                     return "handball"
        case .hiking:                       return "hiking"
        case .hockey:                       return "hockey"
        case .hunting:                      return "hunting"
        case .lacrosse:                     return "lacrosse"
        case .martialArts:                  return "martial_arts"
        case .mindAndBody:                  return "mind_and_body"
        case .mixedMetabolicCardioTraining: return "mixed_metabolic_cardio_training"
        case .paddleSports:                 return "paddle_sports"
        case .play:                         return "play"
        case .preparationAndRecovery:       return "preparation_and_recovery"
        case .racquetball:                  return "racquetball"
        case .rowing:                       return "rowing"
        case .rugby:                        return "rugby"
        case .running:                      return "running"
        case .sailing:                      return "sailing"
        case .skatingSports:                return "skating_sports"
        case .snowSports:                   return "snow_sports"
        case .soccer:                       return "soccer"
        case .softball:                     return "softball"
        case .squash:                       return "squash"
        case .stairClimbing:                return "stair_climbing"
        case .surfingSports:                return "surfing_sports"
        case .swimming:                     return "swimming"
        case .tableTennis:                  return "table_tennis"
        case .tennis:                       return "tennis"
        case .trackAndField:                return "track_and_field"
        case .traditionalStrengthTraining:  return "traditional_strength_training"
        case .volleyball:                   return "volleyball"
        case .walking:                      return "walking"
        case .waterFitness:                 return "water_fitness"
        case .waterPolo:                    return "water_polo"
        case .waterSports:                  return "water_sports"
        case .wrestling:                    return "wrestling"
        case .yoga:                         return "yoga"
            
            // - iOS 10
            
        case .barre:                        return "barre"
        case .coreTraining:                 return "core_training"
        case .crossCountrySkiing:           return "cross_country_skiing"
        case .downhillSkiing:               return "downhill_skiing"
        case .flexibility:                  return "flexibility"
        case .highIntensityIntervalTraining:    return "high_intensity_interval_training"
        case .jumpRope:                     return "jump_rope"
        case .kickboxing:                   return "kickboxing"
        case .pilates:                      return "pilates"
        case .snowboarding:                 return "snowboarding"
        case .stairs:                       return "stairs"
        case .stepTraining:                 return "step_training"
        case .wheelchairWalkPace:           return "wheelchair_walk_pace"
        case .wheelchairRunPace:            return "wheelchair_run_pace"
            
            // - iOS 11
            
        case .taiChi:                       return "tai_chi"
        case .mixedCardio:                  return "mixed_cardio"
        case .handCycling:                  return "hand_cycling"
            
            // - iOS 13
            
        case .discSports:                   return "disc_sports"
        case .fitnessGaming:                return "fitness_gaming"
            
            // - iOS 14
        case .cardioDance:                  return "cardio_dance"
        case .socialDance:                  return "social_dance"
        case .pickleball:                   return "pickleball"
        case .cooldown:                     return "cooldown"
            
            // - iOS 16
        case .swimBikeRun:                  return "swim_bike_run"
        case .transition:                   return "transition"
            
            // - iOS 17
        case .underwaterDiving:             return "underwater_diving"
            
            // - Other
        case .other:                        return "other"
        @unknown default:                   return "unknown"
        }
    }
}
