// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    private(set) var activityStatus: SahhaSensorStatus = .pending {
        didSet {
            if activityStatus == .enabled {
                if oldValue != .enabled {
                    enableBackgroundDelivery()
                }
            } else {
                store.disableAllBackgroundDelivery { _, _ in
                }
            }
        }
    }
    private let activitySensors: Set<SahhaSensor> = Set(SahhaSensor.allCases)
    private var enabledHealthTypes: Set<HealthTypeIdentifier> = []
    private var backgroundHealthTypes: Set<HealthTypeIdentifier> = []
    private var insightHealthTypes: Set<HealthTypeIdentifier> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxSampleLimit: Int = 32
    
    private enum StatisticType: String {
        case Total
        case Average
        case Minimum
        case Maximum
        case MostRecent
    }
    
    private enum HealthTypeIdentifier: String, CaseIterable {
        case Sleep = "sleep"
        case StepCount = "step_count"
        case FloorCount = "floor_count"
        case HeartRate = "heart_rate"
        case RestingHeartRate = "resting_heart_rate"
        case WalkingHeartRateAverage = "walking_heart_rate_average"
        case HeartRateVariability = "heart_rate_variability_sdnn"
        case BloodPressureSystolic = "blood_pressure_systolic"
        case BloodPressureDiastolic = "blood_pressure_diastolic"
        case BloodGlucose = "blood_glucose"
        case VO2Max = "vo2_max"
        case OxygenSaturation = "oxygen_saturation"
        case RespiratoryRate = "respiratory_rate"
        case ActiveEnergyBurned = "active_energy_burned"
        case BasalEnergyBurned = "basal_energy_burned"
        case TimeInDaylight = "time_in_daylight"
        case Height = "height"
        case Weight = "weight"
        case LeanBodyMass = "lean_body_mass"
        case BodyMassIndex = "body_mass_index"
        case BodyFat = "body_fat"
        case WaistCircumference = "waist_circumference"
        case StandTime = "stand_time"
        case MoveTime = "move_time"
        case ExerciseTime = "exercise_time"
        case ActivitySummary = "activity_summary"
        
        var keyName: String {
            "Sahha".appending(self.rawValue)
        }
        
        var logName: String {
            self.rawValue
        }
        
        var objectType: HKObjectType? {
            switch self {
            case .Sleep:
                return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
            case .StepCount:
                return HKSampleType.quantityType(forIdentifier: .stepCount)!
            case .FloorCount:
                return HKSampleType.quantityType(forIdentifier: .flightsClimbed)!
            case .HeartRate:
                return HKSampleType.quantityType(forIdentifier: .heartRate)!
            case .RestingHeartRate:
                return HKSampleType.quantityType(forIdentifier: .restingHeartRate)!
            case .WalkingHeartRateAverage:
                return HKSampleType.quantityType(forIdentifier: .walkingHeartRateAverage)!
            case .HeartRateVariability:
                return HKSampleType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            case .BloodPressureSystolic:
                return HKSampleType.quantityType(forIdentifier: .bloodPressureSystolic)!
            case .BloodPressureDiastolic:
                return HKSampleType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            case .BloodGlucose:
                return HKSampleType.quantityType(forIdentifier: .bloodGlucose)!
            case .VO2Max:
                return HKSampleType.quantityType(forIdentifier: .vo2Max)!
            case .OxygenSaturation:
                return HKSampleType.quantityType(forIdentifier: .oxygenSaturation)!
            case .RespiratoryRate:
                return HKSampleType.quantityType(forIdentifier: .respiratoryRate)!
            case .ActiveEnergyBurned:
                return HKSampleType.quantityType(forIdentifier: .activeEnergyBurned)!
            case .BasalEnergyBurned:
                return HKSampleType.quantityType(forIdentifier: .basalEnergyBurned)!
            case .TimeInDaylight:
                if #available(iOS 17.0, *) {
                    return HKSampleType.quantityType(forIdentifier: .timeInDaylight)!
                } else {
                    return nil
                }
            case .Height:
                return HKSampleType.quantityType(forIdentifier: .height)!
            case .Weight:
                return HKSampleType.quantityType(forIdentifier: .bodyMass)!
            case .LeanBodyMass:
                return HKSampleType.quantityType(forIdentifier: .leanBodyMass)!
            case .BodyMassIndex:
                return HKSampleType.quantityType(forIdentifier: .bodyMassIndex)!
            case .BodyFat:
                return HKSampleType.quantityType(forIdentifier: .bodyFatPercentage)!
            case .WaistCircumference:
                return HKSampleType.quantityType(forIdentifier: .waistCircumference)!
            case .StandTime:
                return HKSampleType.quantityType(forIdentifier: .appleStandTime)!
            case .MoveTime:
                if #available(iOS 14.5, *) {
                    return HKSampleType.quantityType(forIdentifier: .appleMoveTime)!
                } else {
                    return nil
                }
            case .ExerciseTime:
                return HKSampleType.quantityType(forIdentifier: .appleExerciseTime)!
            case .ActivitySummary:
                return HKSampleType.activitySummaryType()
            }
        }
        
        var unit: HKUnit {
            return switch self {
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage:
                .count().unitDivided(by: .minute())
            case .HeartRateVariability:
                .secondUnit(with: .milli)
            case .VO2Max:
                HKUnit(from: "ml/kg*min")
            case .OxygenSaturation, .BodyFat:
                .percent()
            case .RespiratoryRate:
                .count().unitDivided(by: .second())
            case .ActiveEnergyBurned, .BasalEnergyBurned:
                .largeCalorie()
            case .TimeInDaylight, .StandTime, .MoveTime, .ExerciseTime:
                .minute()
            case .Height, .WaistCircumference:
                .meter()
            case .Weight, .LeanBodyMass:
                .gramUnit(with: .kilo)
            case .BloodPressureSystolic, .BloodPressureDiastolic:
                .millimeterOfMercury()
            case .BloodGlucose:
                HKUnit(from: "mg/dL")
            case .Sleep, .StepCount, .FloorCount, .BodyMassIndex, .ActivitySummary:
                .count()
            }
        }
        
        var unitString: String {
            return switch self {
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage:
                "m/s"
            case .HeartRateVariability:
                "ms"
            case .VO2Max:
                "ml/kg/min"
            case .OxygenSaturation, .BodyFat:
                "percent"
            case .RespiratoryRate:
                "bps"
            case .ActiveEnergyBurned, .BasalEnergyBurned:
                "kcal"
            case .Sleep, .TimeInDaylight, .StandTime, .MoveTime, .ExerciseTime:
                "minute"
            case .Height, .WaistCircumference:
                "m"
            case .Weight, .LeanBodyMass:
                "kg"
            case .BloodPressureSystolic, .BloodPressureDiastolic:
                "mmHg"
            case .BloodGlucose:
                "mg/dL"
            case .StepCount, .FloorCount, .BodyMassIndex, .ActivitySummary:
                "count"
            }
        }
        
        var sensorType: SahhaSensor {
            switch self {
            case .Sleep:
                return .sleep
            case .StepCount, .FloorCount, .MoveTime, .StandTime, .ExerciseTime, .ActivitySummary:
                return .activity
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage, .HeartRateVariability:
                return .heart
            case .BloodPressureSystolic, .BloodPressureDiastolic, .BloodGlucose:
                return .blood
            case .OxygenSaturation, .VO2Max, .RespiratoryRate:
                return .oxygen
            case .ActiveEnergyBurned, .BasalEnergyBurned, .TimeInDaylight:
                return .energy
            case .Height, .Weight, .LeanBodyMass, .BodyMassIndex, .BodyFat, .WaistCircumference:
                return .body
            }
        }
        
        var endpointPath: ApiEndpoint.EndpointPath {
            switch self {
            case .Sleep:
                return .sleep
            case .StepCount, .FloorCount, .MoveTime, .StandTime, .ExerciseTime:
                return .activity
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage, .HeartRateVariability:
                return .heart
            case .BloodPressureSystolic, .BloodPressureDiastolic, .BloodGlucose:
                return .blood
            case .VO2Max, .OxygenSaturation, .RespiratoryRate:
                return .oxygen
            case .ActiveEnergyBurned, .BasalEnergyBurned, .TimeInDaylight:
                return .energy
            case .Height, .Weight, .LeanBodyMass, .BodyMassIndex, .BodyFat, .WaistCircumference:
                return .body
            case .ActivitySummary:
                return .insight
            }
        }
    }
    
    internal init() {
        print("Sahha | Health init")
    }
    
    internal func clearAllData() {
        for healthType in HealthTypeIdentifier.allCases {
            setAnchor(anchor: nil, healthType: healthType)
        }
        setInsightDate(nil)
    }
    
    internal func configure(sensors: Set<SahhaSensor>, callback: (() -> Void)? = nil) {
        let enabledSensors = activitySensors.intersection(sensors)
        
        // Add all enabled health types
        for healthTypeIdentifier in HealthTypeIdentifier.allCases {
            if enabledSensors.contains(healthTypeIdentifier.sensorType) {
                enabledHealthTypes.insert(healthTypeIdentifier)
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        
        checkAuthorization() { _, _ in
            print("Sahha | Health configured")
            callback?()
        }
    }
    
    @objc private func onAppOpen() {
        checkAuthorization()
    }
    
    @objc private func onAppClose() {
    }
    
    private func setAnchor(anchor: HKQueryAnchor?, healthType: HealthTypeIdentifier) {
        guard let anchor = anchor else {
            UserDefaults.standard.removeObject(forKey: healthType.keyName)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: healthType.keyName)
        } catch {
            print("Sahha | Unable to set health anchor", healthType.keyName)
            Sahha.postError(message: "Unable to set health anchor", path: "HealthActivity", method: "setAnchor", body: healthType.keyName + " | " + anchor.debugDescription)
        }
    }
    
    private func getAnchor(healthType: HealthTypeIdentifier) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: healthType.keyName) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            print("Sahha | Unable to get health anchor", healthType.keyName)
            Sahha.postError(message: "Unable to get health anchor", path: "HealthActivity", method: "getAnchor", body: healthType.keyName)
            return nil
        }
    }
    
    private func setInsightDate(_ date: Date?) {
        UserDefaults.standard.set(date: date, forKey: "SahhaInsightDate")
    }
    
    private func getInsightDate() -> Date? {
        return UserDefaults.standard.date(forKey: "SahhaInsightDate")
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    public func activate(_ callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        guard activityStatus == .pending || activityStatus == .disabled else {
            callback(nil, activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            var objectTypes: Set<HKObjectType> = []
            if let healthTypes = self?.enabledHealthTypes {
                for healthType in healthTypes {
                    if let objectType = healthType.objectType {
                        objectTypes.insert(objectType)
                    }
                }
            }
            self?.store.requestAuthorization(toShare: [], read: objectTypes) { [weak self] success, error in
                DispatchQueue.main.async { [weak self] in
                    if let error = error {
                        print(error.localizedDescription)
                        Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "activate", body: "self?.store.requestAuthorization")
                        callback(error.localizedDescription, self?.activityStatus ?? .pending)
                    } else {
                        self?.checkAuthorization({ error, status in
                            callback(error, status)
                        })
                    }
                }
            }
        }
    }
    
    internal func checkAuthorization(_ callback: ((String?, SahhaSensorStatus)->Void)? = nil) {
        guard isAvailable else {
            activityStatus = .unavailable
            callback?(nil, activityStatus)
            return
        }
        guard enabledHealthTypes.isEmpty == false else {
            activityStatus = .pending
            callback?("Sahha | Health data types not specified", activityStatus)
            return
        }
        var objectTypes: Set<HKObjectType> = []
        for healthType in enabledHealthTypes {
            if let objectType = healthType.objectType {
                objectTypes.insert(objectType)
            }
        }
        store.getRequestStatusForAuthorization(toShare: [], read: objectTypes) { [weak self] status, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                print("Sahha | Health error")
                print(error.localizedDescription)
                self.activityStatus = .pending
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "checkAuthorization", body: "store.getRequestStatusForAuthorization")
            } else {
                switch status {
                case .unnecessary:
                    self.activityStatus = .enabled
                default:
                    self.activityStatus = .pending
                }
            }
            print("Sahha | Health activity status : \(self.activityStatus.description)")
            callback?(nil, self.activityStatus)
        }
    }
    
    private func enableBackgroundDelivery() {
        
        guard isAvailable else {
            return
        }
        
        for healthId in HealthTypeIdentifier.allCases {
            
            if let sampleType = healthId.objectType as? HKSampleType {
            
                store.getRequestStatusForAuthorization(toShare: [], read: [sampleType]) { [weak self] status, errorOrNil in
                    
                    if let error = errorOrNil {
                        print(error.localizedDescription)
                        Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "enableBackgroundDelivery", body: "store.getRequestStatusForAuthorization")
                        return
                    }
                    
                    switch status {
                    case .unnecessary:
                        self?.store.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate) { [weak self] success, error in
                            if let error = error {
                                print(error.localizedDescription)
                                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "enableBackgroundDelivery", body: "self?.store.enableBackgroundDelivery")
                                return
                            }
                            switch success {
                            case true:
                                let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                                    if let error = errorOrNil {
                                        print(error.localizedDescription)
                                        Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "enableBackgroundDelivery", body: "let query = HKObserverQuery")
                                    } else {
                                        self?.postSensorData { _ , _ in }
                                    }
                                    // Must be called to stop updating for duplicate data
                                    completionHandler()
                                }
                                if let store = self?.store {
                                    store.execute(query)
                                }
                                return
                            case false:
                                return
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    internal func postSensorData(callback: @escaping (_ error: String?, _ success: Bool) -> Void) {
        
        guard backgroundHealthTypes.isEmpty else {
            callback("Sahha | Post sensor data task is already in progress", false)
            return
        }
        
        guard SahhaCredentials.isAuthenticated else {
            callback("Sahha | Post sensor data task is not authenticated - you must set a profile", false)
            return
        }
        
        let sensorCallback: (_ error: String?, _ success: Bool) -> Void = { [weak self] error, success in
            // Clean up
            self?.backgroundHealthTypes.removeAll()
            
            // Pass to parent callback
            callback(error, success)
            
            return
        }
        
        backgroundHealthTypes = enabledHealthTypes
        
        postNextSensorData(callback: sensorCallback)
    }
    
    private func postNextSensorData(callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        guard backgroundHealthTypes.isEmpty == false else {
            print("Sahha | Post sensor data successfully completed")
            callback(nil, true)
            postInsights()
            return
        }
        
        let healthType = backgroundHealthTypes.removeFirst()
        postSensorData(healthType: healthType, callback: callback)
    }
    
    private func postSensorData(healthType: HealthTypeIdentifier, callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        if let sampleType = healthType.objectType as? HKSampleType {
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
            let anchor = getAnchor(healthType: healthType)
            let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: maxSampleLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
                if let error = errorOrNil {
                    print(error.localizedDescription)
                    Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "postSensorData", body: "let query = HKAnchoredObjectQuery")
                    callback(error.localizedDescription, false)
                    return
                }
                guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                
                switch healthType.sensorType {
                case .sleep:
                    guard let categorySamples = samples as? [HKCategorySample] else {
                        self?.postNextSensorData(callback: callback)
                        return
                    }
                    self?.postSleepSamples(samples: categorySamples) { error, success in
                        if success {
                            self?.setAnchor(anchor: newAnchor, healthType: healthType)
                            self?.postSensorData(healthType: healthType, callback: callback)
                        } else {
                            callback(error, success)
                        }
                    }
                default:
                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        self?.postNextSensorData(callback: callback)
                        return
                    }
                    self?.postHealthSamples(healthType: healthType, samples: quantitySamples) { error, success in
                        if success {
                            self?.setAnchor(anchor: newAnchor, healthType: healthType)
                            self?.postSensorData(healthType: healthType, callback: callback)
                        } else {
                            callback(error, success)
                        }
                    }
                }
            }
            store.execute(query)
        } else {
            postNextSensorData(callback: callback)
        }
    }
    
    private func postInsights() {
        
        let today = Date()
        // Set startDate to a week prior if date is nil (first app launch)
        let startDate = getInsightDate() ?? Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let endDate = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        // Only check once per day
        if Calendar.current.isDateInToday(startDate) == false, today > startDate {
            getInsights(dates: (startDate: startDate, endDate: endDate)) { error, insights in
                if let error = error {
                    print(error)
                } else if insights.isEmpty == false {
                    var requests: [SahhaInsightRequest] = []
                    for insight in insights {
                        requests.append(SahhaInsightRequest(insight))
                    }
                    
                    APIController.postInsight(body: requests) { [weak self] result in
                        switch result {
                        case .success(_):
                            print("Sahha | Post insight data successfully completed")
                            self?.setInsightDate(today)
                        case .failure(let error):
                            print(error.localizedDescription)
                        }
                    }
                }
            }
        } else {
            print("Sahha | Post insight data - no new data available yet. Try again later.")
        }
    }
    
    internal func getInsights(dates:(startDate: Date, endDate: Date)? = nil, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard insightHealthTypes.isEmpty else {
            callback("Sahha | Get insight data task is already in progress", [])
            return
        }
        
        var interval = DateComponents()
        interval.day = 1
        
        insightHealthTypes = enabledHealthTypes
        getNextInsight(insights: [], startDate: dates?.startDate ?? Date(), endDate: dates?.endDate ?? Date(), interval: interval, callback: callback)
    }
    
    private func getNextInsight(insights: [SahhaInsight], startDate: Date, endDate: Date, interval: DateComponents, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard insightHealthTypes.isEmpty == false else {
            print("Sahha | Get insight data successfully completed")
            callback(nil, insights)
            return
        }
        
        let healthType = insightHealthTypes.removeFirst()
        switch healthType {
            /* // Coming soon
        case .HeartRateVariability:
            getInsightData(healthType: .HeartRateVariability, unit: .secondUnit(with: .milli), statisicType: .average, startDate: startDate, endDate: endDate, interval: interval, options: .discreteAverage) { [weak self] error, newInsights in
                self?.getNextInsight(insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .HeartRate:
            getInsightData(healthType: .HeartRate, unit: .count().unitDivided(by: .minute()), statisicType: .average, startDate: startDate, endDate: endDate, interval: interval, options: .discreteAverage) { [weak self] error, newInsights in
                self?.getNextInsight(insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .RestingHeartRate:
            getInsightData(healthType: .RestingHeartRate, unit: .count().unitDivided(by: .minute()), statisicType: .average, startDate: startDate, endDate: endDate, interval: interval, options: .discreteAverage) { [weak self] error, newInsights in
                self?.getNextInsight(insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .WalkingHeartRateAverage:
            getInsightData(healthType: .WalkingHeartRateAverage, unit: .count().unitDivided(by: .minute()), statisicType: .average, startDate: startDate, endDate: endDate, interval: interval, options: .discreteAverage) { [weak self] error, newInsights in
                self?.getNextInsight(insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
             */
        case .StepCount:
            getInsightData(healthType: .StepCount, unit: .count(), statisicType: .Total, startDate: startDate, endDate: endDate, interval: interval, options: .cumulativeSum) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                let moreInsights = insights + newInsights
                self?.getNextInsight(insights: moreInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .Sleep:
            getSleepInsightData(startDate: startDate, endDate: endDate, interval: interval) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                let moreInsights = insights + newInsights
                self?.getNextInsight(insights: moreInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .ActivitySummary:
            getActivitySummaryInsightData(startDate: startDate, endDate: endDate) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                let moreInsights = insights + newInsights
                self?.getNextInsight(insights: moreInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        default:
            getNextInsight(insights: insights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
        }
    }
    
    private func getInsightData(healthType: HealthTypeIdentifier, unit: HKUnit, statisicType: StatisticType, startDate: Date, endDate: Date, interval: DateComponents, options: HKStatisticsOptions, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard let quantityType = healthType.objectType as? HKQuantityType else {
            let message = "Statistics can only be queried for quantity types"
            Sahha.postError(message: message, path: "HealthActivity", method: "getInsightData", body: healthType.keyName)
            callback(message, [])
            return
        }
        
        let queryStartDate = Calendar.current.startOfDay(for: startDate)
        let queryEndDate: Date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: queryStartDate, end: queryEndDate)
        let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options, anchorDate: queryStartDate, intervalComponents: interval)
        
        query.initialResultsHandler = {
            _, results, error in
            
            guard let results = results else {
                if let error = error {
                    print(error.localizedDescription)
                    Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "getInsightData", body: "if let error = error {")
                }
                callback(error?.localizedDescription, [])
                return
            }
            
            var insights: [SahhaInsight] = []
            
            for result in results.statistics() {
                let quantity: HKQuantity?
                let quantityName: String = statisicType.rawValue
                switch statisicType {
                case .Total:
                    quantity = result.sumQuantity()
                case .Average:
                    quantity = result.averageQuantity()
                case .Minimum:
                    quantity = result.minimumQuantity()
                case .Maximum:
                    quantity = result.maximumQuantity()
                case .MostRecent:
                    quantity = result.mostRecentQuantity()
                }
                guard let quantity = quantity else {
                    break
                }
                
                let insightName = healthType.rawValue + "Daily" + quantityName
                if let insightIdentifier = SahhaInsightIdentifier(rawValue: insightName) {
                   let insight = SahhaInsight(name: insightIdentifier, value: quantity.doubleValue(for: unit), unit: unit.unitString, startDate: result.startDate, endDate: result.endDate)
                    insights.append(insight)
                }
            }
            
            callback(nil, insights)
        }
        
        store.execute(query)
    }
    
    private func getSleepInsightData(startDate: Date, endDate: Date, interval: DateComponents, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        let adjustedStartDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate) ?? startDate
        let newStartDate = Calendar.current.date(bySetting: .hour, value: 18, of: adjustedStartDate) ?? adjustedStartDate

        let newEndDate = Calendar.current.date(bySetting: .hour, value: 18, of: endDate) ?? endDate

        let predicate = HKQuery.predicateForSamples(withStart: newStartDate, end: newEndDate)
        let query = HKSampleQuery(sampleType: HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { sampleQuery, samplesOrNil, error in
            if let error = error {
                print(error.localizedDescription)
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "getSleepInsightData", body: "")
                callback(error.localizedDescription, [])
                return
            }
            guard let samples = samplesOrNil as? [HKCategorySample], samples.isEmpty == false else {
                callback(nil, [])
                return
            }
            
            func isInBed(_ value: HKCategoryValueSleepAnalysis) -> Bool {
                return value == HKCategoryValueSleepAnalysis.inBed
            }
            
            func isAsleep(_ value: HKCategoryValueSleepAnalysis) -> Bool {
                if #available(iOS 16.0, *) {
                    switch value {
                    case .asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified:
                        return true
                    default:
                        return false
                    }
                }
                else if value == .asleep {
                    return true
                }
                return false
            }
            
            var sleepInsights: [SahhaInsight] = []
            let day = 86400.0
            var rollingInterval = DateInterval(start: newStartDate, duration: day)
            while rollingInterval.end <= newEndDate {
                var bedDictionary: [String:SahhaInsight] = [:]
                var sleepDictionary: [String:SahhaInsight] = [:]
                var sleepREMDictionary: [String:SahhaInsight] = [:]
                var sleepLightDictionary: [String:SahhaInsight] = [:]
                var sleepDeepDictionary: [String:SahhaInsight] = [:]
                for sample in samples {
                    if let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                        if let intersection = sampleInterval.intersection(with: rollingInterval) {
                            let sampleTime = intersection.duration / 60
                            let sampleId = sample.sourceRevision.source.bundleIdentifier
                            if isInBed(sleepStage) {
                                var newInsight = bedDictionary[sampleId] ?? SahhaInsight(name: .TimeInBedDailyTotal, value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                bedDictionary[sampleId] = newInsight
                            } else if isAsleep(sleepStage) {
                                var newInsight = sleepDictionary[sampleId] ?? SahhaInsight(name: .TimeAsleepDailyTotal, value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                sleepDictionary[sampleId] = newInsight
                                switch sleepStage {
                                case .asleepREM:
                                    var stageInsight = sleepREMDictionary[sampleId] ?? SahhaInsight(name: .TimeInREMSleepDailyTotal, value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepREMDictionary[sampleId] = stageInsight
                                case .asleepCore:
                                    var stageInsight = sleepLightDictionary[sampleId] ?? SahhaInsight(name: .TimeInLightSleepDailyTotal, value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepLightDictionary[sampleId] = stageInsight
                                case .asleepDeep:
                                    var stageInsight = sleepDeepDictionary[sampleId] ?? SahhaInsight(name: .TimeInDeepSleepDailyTotal, value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepDeepDictionary[sampleId] = stageInsight
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
                if bedDictionary.isEmpty == false, let minimumBed = bedDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(minimumBed.value)
                }
                if sleepDictionary.isEmpty == false, let maximumSleep = sleepDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maximumSleep.value)
                }
                if sleepREMDictionary.isEmpty == false, let maximumSleep = sleepREMDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maximumSleep.value)
                }
                if sleepLightDictionary.isEmpty == false, let maximumSleep = sleepLightDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maximumSleep.value)
                }
                if sleepDeepDictionary.isEmpty == false, let maximumSleep = sleepDeepDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maximumSleep.value)
                }
                rollingInterval = DateInterval(start: rollingInterval.end, duration: day)
            }
            callback(nil, sleepInsights)
        }
        store.execute(query)
    }
    
    private func getActivitySummaryInsightData(startDate: Date, endDate: Date, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        let startComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: startDate)
        let endComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: endDate)
        
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
        
        let query = HKActivitySummaryQuery(predicate: predicate) { query, result, error in
            
            if let error = error {
                print(error.localizedDescription)
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "getActivitySummary", body: "")
                callback(error.localizedDescription, [])
                return
            }
            
            guard let result = result, !result.isEmpty else {
                callback("Sahha | Health Activity Summary is empty", [])
                return
            }
            
            var sahhaInsights: [SahhaInsight] = []
            
            for activitySummary in result {
                
                let dateComponents = activitySummary.dateComponents(for: Calendar.current)
                let date = dateComponents.date ?? Date()
                
                sahhaInsights.append(SahhaInsight(name: .StandHoursDailyTotal, value:                 activitySummary.appleStandHours.doubleValue(for: .count()) 
, unit: "hour", startDate: date, endDate: date))
                if #available(iOS 16.0, *) {
                    sahhaInsights.append(SahhaInsight(name: .StandHoursDailyGoal, value:                 activitySummary.standHoursGoal?.doubleValue(for: .count()) ?? 0
                                                      , unit: "hour", startDate: date, endDate: date))
                } else {
                    sahhaInsights.append(SahhaInsight(name: .StandHoursDailyGoal, value:                 activitySummary.appleStandHoursGoal.doubleValue(for: .count()) 
                                                      , unit: "hour", startDate: date, endDate: date))
                }
                sahhaInsights.append(SahhaInsight(name: .MoveTimeDailyTotal, value:                 activitySummary.appleMoveTime.doubleValue(for: .minute()) 
, unit: "minute", startDate: date, endDate: date))
                sahhaInsights.append(SahhaInsight(name: .MoveTimeDailyGoal, value:                 activitySummary.appleMoveTimeGoal.doubleValue(for: .minute()) 
, unit: "minute", startDate: date, endDate: date))
                sahhaInsights.append(SahhaInsight(name: .ExerciseTimeDailyTotal, value:                 activitySummary.appleExerciseTime.doubleValue(for: .minute()) 
, unit: "minute", startDate: date, endDate: date))
                if #available(iOS 16.0, *) {
                    sahhaInsights.append(SahhaInsight(name: .ExerciseTimeDailyGoal, value:                 activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) ?? 0
                                                      , unit: "minute", startDate: date, endDate: date))
                } else {
                    sahhaInsights.append(SahhaInsight(name: .ExerciseTimeDailyGoal, value:                 activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()) 
                                                      , unit: "minute", startDate: date, endDate: date))
                }
                sahhaInsights.append(SahhaInsight(name: .ActiveEnergyBurnedDailyTotal, value:                 activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()) 
, unit: HKUnit.largeCalorie().unitString, startDate: date, endDate: date))
                sahhaInsights.append(SahhaInsight(name: .ActiveEnergyBurnedDailyGoal, value:                 activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie()) 
                                                  , unit: HKUnit.largeCalorie().unitString, startDate: date, endDate: date))
            }
            
            callback(nil, sahhaInsights)
        }
        store.execute(query)
    }
    
    private func getRecordingMethod(_ sample: HKSample) -> String {
        var recordingMethod: String = "RECORDING_METHOD_UNKNOWN"
        if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
            recordingMethod = "RECORDING_METHOD_MANUAL_ENTRY"
        }
        return recordingMethod
    }
    
    private func postSleepSamples(samples: [HKCategorySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var requests: [DataLogRequest] = []
        for sample in samples {
            let sleepStage: SleepStage
            
            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    sleepStage = .inBed
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    sleepStage = .awake
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    sleepStage = .asleepREM
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    sleepStage = .asleepCore
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    sleepStage = .asleepDeep
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    sleepStage = .asleepUnspecified
                default:
                    sleepStage = .unknown
                    break
                }
            }
            else {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    sleepStage = .inBed
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    sleepStage = .awake
                case HKCategoryValueSleepAnalysis.asleep.rawValue:
                    sleepStage = .asleepUnspecified
                default:
                    sleepStage = .unknown
                    break
                }
            }
            
            let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
            let value = Double(difference.minute ?? 0)
            
            let request = DataLogRequest(logType: .sleep, dataType: sleepStage.rawValue, value: value, unit: HealthTypeIdentifier.Sleep.unitString, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
            requests.append(request)
        }
        
        APIController.postDataLog(body: requests) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }

    
    private func postHealthSamples(healthType: HealthTypeIdentifier, samples: [HKQuantitySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var requests: [DataLogRequest] = []
        for sample in samples {
            
            var dataType = healthType.rawValue
            
            let value: Double = sample.quantity.doubleValue(for: healthType.unit)
            
            var request = DataLogRequest(logType: healthType.sensorType, dataType: healthType.rawValue, value: value, unit: healthType.unit.unitString, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
            
            var additionalProperties: [String: String] = [:]
            
            if let metaValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber, let metaEnumValue = HKHeartRateSensorLocation(rawValue: metaValue.intValue) {
                let stringValue: String
                switch metaEnumValue {
                case .chest:
                    stringValue = "chest"
                case .earLobe:
                    stringValue = "ear_lobe"
                case .finger:
                    stringValue = "finger"
                case .foot:
                    stringValue = "foot"
                case .hand:
                    stringValue = "hand"
                case .wrist:
                    stringValue = "wrist"
                case .other:
                    stringValue = "other"
                @unknown default:
                    stringValue = "unknown"
                }
                additionalProperties = [DataLogPropertyIdentifier.measurementLocation.rawValue: stringValue]
            }
            
            if let metaValue = sample.metadata?[HKMetadataKeyVO2MaxTestType] as? NSNumber, let metaEnumValue = HKVO2MaxTestType(rawValue: metaValue.intValue) {
                let stringValue: String
                switch metaEnumValue {
                case .maxExercise:
                    stringValue = "max_exercise"
                case .predictionNonExercise:
                    stringValue = "prediction_non_exercise"
                case .predictionSubMaxExercise:
                    stringValue = "prediction_sub_max_exercise"
                @unknown default:
                    stringValue = "unknown"
                }
                additionalProperties = [DataLogPropertyIdentifier.measurementMethod.rawValue: stringValue]
            }
            
            if let metaValue = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber, let metaEnumValue = HKHeartRateMotionContext(rawValue: metaValue.intValue) {
                let stringValue: String
                switch metaEnumValue {
                case .notSet:
                    stringValue = "not_set"
                case .sedentary:
                    stringValue = "sedentary"
                case .active:
                    stringValue = "active"
                @unknown default:
                    stringValue = "unknown"
                }
                additionalProperties = [DataLogPropertyIdentifier.motionContext.rawValue: stringValue]
            }
            
            if let metaValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber, let metaEnumValue = HKBloodGlucoseMealTime(rawValue: metaValue.intValue) {
                let relationToMeal: BloodRelationToMeal
                switch metaEnumValue {
                case .preprandial:
                    relationToMeal = .beforeMeal
                case .postprandial:
                    relationToMeal = .afterMeal
                default:
                    relationToMeal = .unknown
                }
                additionalProperties = [DataLogPropertyIdentifier.relationToMeal.rawValue: relationToMeal.rawValue]
            }
            
            if additionalProperties.isEmpty == false {
                request.additionalProperties = additionalProperties
            }
            
            requests.append(request)
        }
        
        APIController.postDataLog(body: requests) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }
}
