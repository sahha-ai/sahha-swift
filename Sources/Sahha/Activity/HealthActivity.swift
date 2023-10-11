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
    private let activitySensors: Set<SahhaSensor> = [.sleep, .pedometer, .heart, .blood]
    private var enabledHealthTypes: Set<HealthTypeIdentifier> = []
    private var backgroundHealthTypes: Set<HealthTypeIdentifier> = []
    private var insightHealthTypes: Set<HealthTypeIdentifier> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxSampleLimit: Int = 32
    private var bloodGlucoseUnit: HKUnit = .count()
    
    private enum StatisticType {
        case sum
        case average
        case min
        case max
        case mostRecent
    }
    
    private enum HealthTypeIdentifier: String, CaseIterable {
        case Sleep
        case StepCount
        case HeartRate
        case RestingHeartRate
        case WalkingHeartRateAverage
        case HeartRateVariability
        case BloodPressureSystolic
        case BloodPressureDiastolic
        case BloodGlucose
        
        var keyName: String {
            "Sahha".appending(self.rawValue)
        }
        
        var sampleType: HKSampleType {
            switch self {
            case .Sleep:
                return HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
            case .StepCount:
                return HKSampleType.quantityType(forIdentifier: .stepCount)!
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
        if enabledSensors.contains(.sleep) {
            enabledHealthTypes.insert(.Sleep)
        }
        if enabledSensors.contains(.pedometer) {
            enabledHealthTypes.insert(.StepCount)
        }
        if enabledSensors.contains(.heart) {
            enabledHealthTypes.insert(.HeartRate)
            enabledHealthTypes.insert(.RestingHeartRate)
            enabledHealthTypes.insert(.WalkingHeartRateAverage)
            enabledHealthTypes.insert(.HeartRateVariability)
        }
        if enabledSensors.contains(.blood) {
            enabledHealthTypes.insert(.BloodPressureSystolic)
            enabledHealthTypes.insert(.BloodPressureDiastolic)
            enabledHealthTypes.insert(.BloodGlucose)
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
                    objectTypes.insert(healthType.sampleType)
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
            objectTypes.insert(healthType.sampleType)
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
            
            let sampleType = healthId.sampleType
            
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
        
        store.preferredUnits(for: [HKObjectType.quantityType(forIdentifier: .bloodGlucose)!]) { [weak self] unitTypes, error in
            if let error = error {
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "postSensorData", body: "store.preferredUnits")
                callback("Sahha | Post sensor data task - Glucose Unit Invalid", false)
            } else if let unitType = unitTypes.first {
                self?.bloodGlucoseUnit = unitType.value
                self?.postNextSensorData(callback: sensorCallback)
            }
        }
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
        
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
        let anchor = getAnchor(healthType: healthType)
        let query = HKAnchoredObjectQuery(type: healthType.sampleType, predicate: predicate, anchor: anchor, limit: maxSampleLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
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
            
            switch healthType {
            case .Sleep:
                guard let categorySamples = samples as? [HKCategorySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postSleepRange(samples: categorySamples) { error, success in
                    if success {
                        self?.setAnchor(anchor: newAnchor, healthType: healthType)
                        self?.postSensorData(healthType: healthType, callback: callback)
                    } else {
                        callback(error, success)
                    }
                }
            case .StepCount:
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postMovementRange(samples: quantitySamples) { error, success in
                    if success {
                        self?.setAnchor(anchor: newAnchor, healthType: healthType)
                        self?.postSensorData(healthType: healthType, callback: callback)
                    } else {
                        callback(error, success)
                    }
                }
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage, .HeartRateVariability:
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postHeartRange(healthType: healthType, samples: quantitySamples) { error, success in
                    if success {
                        self?.setAnchor(anchor: newAnchor, healthType: healthType)
                        self?.postSensorData(healthType: healthType, callback: callback)
                    } else {
                        callback(error, success)
                    }
                }
            case .BloodPressureSystolic, .BloodPressureDiastolic, .BloodGlucose:
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postBloodRange(healthType: healthType, samples: quantitySamples) { error, success in
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
            getInsightData(healthType: .StepCount, unit: .count(), statisicType: .sum, startDate: startDate, endDate: endDate, interval: interval, options: .cumulativeSum) { [weak self] error, newInsights in
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
        default:
            getNextInsight(insights: insights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
        }
    }
    
    private func getInsightData(healthType: HealthTypeIdentifier, unit: HKUnit, statisicType: StatisticType, startDate: Date, endDate: Date, interval: DateComponents, options: HKStatisticsOptions, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard let quantityType = healthType.sampleType as? HKQuantityType else {
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
                let quantityName: String
                switch statisicType {
                case .sum:
                    quantity = result.sumQuantity()
                    quantityName = "Total"
                case .average:
                    quantity = result.averageQuantity()
                    quantityName = "Average"
                case .min:
                    quantity = result.minimumQuantity()
                    quantityName = "Minimum"
                case .max:
                    quantity = result.maximumQuantity()
                    quantityName = "Maximum"
                case .mostRecent:
                    quantity = result.mostRecentQuantity()
                    quantityName = "MostRecent"
                }
                guard let quantity = quantity else {
                    break
                }
                
                let insightName = healthType.rawValue + "Daily" + quantityName
                let insight = SahhaInsight(name: insightName, value: quantity.doubleValue(for: unit), unit: unit.unitString, startDate: result.startDate, endDate: result.endDate)
                insights.append(insight)
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
                for sample in samples {
                    if let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                        if let intersection = sampleInterval.intersection(with: rollingInterval) {
                            let sampleTime = intersection.duration / 60
                            let sampleId = sample.sourceRevision.source.bundleIdentifier
                            if isInBed(sleepStage) {
                                var newInsight = bedDictionary[sampleId] ?? SahhaInsight(name: "TimeInBedDailyTotal", value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                bedDictionary[sampleId] = newInsight
                            } else if isAsleep(sleepStage) {
                                var newInsight = sleepDictionary[sampleId] ?? SahhaInsight(name: "TimeAsleepDailyTotal", value: 0, unit: "minute", startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                sleepDictionary[sampleId] = newInsight
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
                rollingInterval = DateInterval(start: rollingInterval.end, duration: day)
            }
            callback(nil, sleepInsights)
        }
        store.execute(query)
    }
    
    private func postSleepRange(samples: [HKCategorySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        //let healthIdentifier: String = HKCategoryTypeIdentifier.sleepAnalysis.rawValue
        var sleepRequests: [SleepRequest] = []
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
                    sleepStage = .asleep
                default:
                    sleepStage = .unknown
                    break
                }
            }
            
            var manuallyEntered: Bool = false
            if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                manuallyEntered = true
            }
            let sleepRequest = SleepRequest(stage: sleepStage, source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
            sleepRequests.append(sleepRequest)
        }
        
        APIController.postSleep(body: sleepRequests) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }
    
    private func postMovementRange(samples: [HKQuantitySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var healthRequests: [HealthRequest] = []
        for sample in samples {
            var manuallyEntered: Bool = false
            if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                manuallyEntered = true
            }
            let healthRequest = HealthRequest(dataType: HealthTypeIdentifier.StepCount.rawValue, count: sample.quantity.doubleValue(for: .count()), source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
            healthRequests.append(healthRequest)
        }
        
        APIController.postMovement(body: healthRequests) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }
    
    private func postHeartRange(healthType: HealthTypeIdentifier, samples: [HKQuantitySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var healthRequests: [HealthRequest] = []
        for sample in samples {
            
            var count: Double
            switch healthType {
            case .HeartRate, .RestingHeartRate, .WalkingHeartRateAverage:
                count = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            case .HeartRateVariability:
                count = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            default:
                count = sample.quantity.doubleValue(for: .count())
            }
            
            var manuallyEntered: Bool = false
            if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                manuallyEntered = true
            }
            
            let healthRequest = HealthRequest(dataType: healthType.rawValue, count: count, source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
            healthRequests.append(healthRequest)
        }
        APIController.postHeart(body: healthRequests) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }
    
    private func postBloodRange(healthType: HealthTypeIdentifier, samples: [HKQuantitySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var bloodRequests: [BloodRequest] = []
        for sample in samples {
            
            var count: Double
            var unit: String?
            switch healthType {
            case .BloodPressureSystolic, .BloodPressureDiastolic:
                count = sample.quantity.doubleValue(for: .millimeterOfMercury())
            case .BloodGlucose:
                if bloodGlucoseUnit != .count() {
                    count = sample.quantity.doubleValue(for: bloodGlucoseUnit)
                    unit = bloodGlucoseUnit.unitString
                } else {
                    Sahha.postError(message: "Blood Glucose measurement unit incorrect", path: "HealthActivity", method: "postBloodRange", body: "if bloodGlucoseUnit != .count() | \(bloodGlucoseUnit.unitString)")
                    callback("Blood Glucose measurement unit incorrect", false)
                    return
                }
            default:
                count = sample.quantity.doubleValue(for: .count())
            }
            
            var relationToMeal: BloodRelationToMeal?
            if let metaValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber, let metaEnumValue = HKBloodGlucoseMealTime(rawValue: metaValue.intValue) {
                switch metaEnumValue {
                case .preprandial:
                    relationToMeal = .beforeMeal
                case .postprandial:
                    relationToMeal = .afterMeal
                default:
                    relationToMeal = .unknown
                }
            }
            
            var manuallyEntered: Bool = false
            if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                manuallyEntered = true
            }
            
            let bloodRequest = BloodRequest(dataType: healthType.rawValue, count: count, unit: unit, relationToMeal: relationToMeal, source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
            bloodRequests.append(bloodRequest)
        }
        APIController.postBlood(body: bloodRequests) { result in
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
