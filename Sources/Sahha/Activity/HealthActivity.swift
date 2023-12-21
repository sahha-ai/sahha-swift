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
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxSampleLimit: Int = 32
    
    private enum StatisticType: String {
        case total
        case average
        case minimum
        case maximum
        case most_recent
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
                    self.postSensorData()
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
        
        for healthType in HealthTypeIdentifier.allCases {
            
            if let sampleType = healthType.objectType as? HKSampleType {
            
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
                                        self?.postSensorData(healthType: healthType)
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
    
    private func postSensorData() {
        for healthType in HealthTypeIdentifier.allCases {
            postSensorData(healthType: healthType)
        }
    }
    
    private func postSensorData(healthType: HealthTypeIdentifier) {
        
        guard isAvailable, activityStatus == .enabled, Sahha.isAuthenticated else {
            return
        }
        
        if let sampleType = healthType.objectType as? HKSampleType {
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
            let anchor = getAnchor(healthType: healthType)
            let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: maxSampleLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
                if let error = errorOrNil {
                    print(error.localizedDescription)
                    Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "postSensorData", body: "let query = HKAnchoredObjectQuery")
                    return
                }
                guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                    return
                }
                
                switch healthType.sensorType {
                case .sleep:
                    guard let categorySamples = samples as? [HKCategorySample] else {
                        print("Sahha | sleep samples in incorrect format")
                        return
                    }
                    self?.postSleepSamples(samples: categorySamples) { error, success in
                        if success {
                            self?.setAnchor(anchor: newAnchor, healthType: healthType)
                            self?.postSensorData(healthType: healthType)
                        }
                    }
                default:
                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        print("Sahha | \(healthType.rawValue) samples in incorrect format")
                        return
                    }
                    self?.postHealthSamples(healthType: healthType, samples: quantitySamples) { error, success in
                        if success {
                            self?.setAnchor(anchor: newAnchor, healthType: healthType)
                            self?.postSensorData(healthType: healthType)
                        } else {
                            print(healthType.rawValue, "error")
                        }
                    }
                }
            }
            store.execute(query)
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
        
        var interval = DateComponents()
        interval.day = 1
        
        getNextInsight(insightTypes: HealthTypeIdentifier.allCases, insights: [], startDate: dates?.startDate ?? Date(), endDate: dates?.endDate ?? Date(), interval: interval, callback: callback)
    }
    
    private func getNextInsight(insightTypes: [HealthTypeIdentifier], insights: [SahhaInsight], startDate: Date, endDate: Date, interval: DateComponents, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard insightTypes.isEmpty == false else {
            print("Sahha | Get insight data successfully completed")
            callback(nil, insights)
            return
        }
        
        var newInsightTypes = insightTypes
        let healthType = newInsightTypes.removeFirst()
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
        case .step_count:
            getInsightData(healthType: .step_count, statisicType: .total, startDate: startDate, endDate: endDate, interval: interval, options: .cumulativeSum) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                self?.getNextInsight(insightTypes: newInsightTypes, insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .sleep:
            getSleepInsightData(startDate: startDate, endDate: endDate, interval: interval) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                self?.getNextInsight(insightTypes: newInsightTypes, insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        case .activity_summary:
            getActivitySummaryInsightData(startDate: startDate, endDate: endDate) { [weak self] error, newInsights in
                if let error = error {
                    callback(error, [])
                    return
                }
                let moreInsights = insights + newInsights
                self?.getNextInsight(insightTypes: newInsightTypes, insights: insights + newInsights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
            }
        default:
            getNextInsight(insightTypes: newInsightTypes, insights: insights, startDate: startDate, endDate: endDate, interval: interval, callback: callback)
        }
    }
    
    private func getInsightData(healthType: HealthTypeIdentifier, statisicType: StatisticType, startDate: Date, endDate: Date, interval: DateComponents, options: HKStatisticsOptions, callback: @escaping (String?, [SahhaInsight]) -> Void) {
        
        guard let quantityType = healthType.objectType as? HKQuantityType else {
            let message = "Statistics can only be queried for quantity types"
            Sahha.postError(message: message, path: "HealthActivity", method: "getInsightData", body: healthType.rawValue)
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
                case .total:
                    quantity = result.sumQuantity()
                case .average:
                    quantity = result.averageQuantity()
                case .minimum:
                    quantity = result.minimumQuantity()
                case .maximum:
                    quantity = result.maximumQuantity()
                case .most_recent:
                    quantity = result.mostRecentQuantity()
                }
                guard let quantity = quantity else {
                    break
                }
                
                let insightName = healthType.rawValue + "_daily_" + quantityName
                if let insightIdentifier = SahhaInsightIdentifier(rawValue: insightName) {
                    let insight = SahhaInsight(name: insightIdentifier, value: quantity.doubleValue(for: healthType.unit), unit: healthType.unitString, startDate: result.startDate, endDate: result.endDate)
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
                return value == .inBed
            }
            
            func isAsleep(_ value: HKCategoryValueSleepAnalysis) -> Bool {
                if value == .asleep {
                    return true
                } else if #available(iOS 16.0, *) {
                    switch value {
                    case .asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified:
                        return true
                    default:
                        return false
                    }
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
                                var newInsight = bedDictionary[sampleId] ?? SahhaInsight(name: .time_in_bed_daily_total, value: 0, unit: HealthTypeIdentifier.sleep.unitString, startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                bedDictionary[sampleId] = newInsight
                            } else if isAsleep(sleepStage) {
                                var newInsight = sleepDictionary[sampleId] ?? SahhaInsight(name: .time_asleep_daily_total, value: 0, unit: HealthTypeIdentifier.sleep.unitString, startDate: rollingInterval.start, endDate: rollingInterval.end)
                                newInsight.value += sampleTime
                                sleepDictionary[sampleId] = newInsight
                                switch sleepStage {
                                case .asleepREM:
                                    var stageInsight = sleepREMDictionary[sampleId] ?? SahhaInsight(name: .time_in_rem_sleep_daily_total, value: 0, unit: HealthTypeIdentifier.sleep.unitString, startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepREMDictionary[sampleId] = stageInsight
                                case .asleepCore:
                                    var stageInsight = sleepLightDictionary[sampleId] ?? SahhaInsight(name: .time_in_light_sleep_daily_total, value: 0, unit: HealthTypeIdentifier.sleep.unitString, startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepLightDictionary[sampleId] = stageInsight
                                case .asleepDeep:
                                    var stageInsight = sleepDeepDictionary[sampleId] ?? SahhaInsight(name: .time_in_deep_sleep_daily_total, value: 0, unit: HealthTypeIdentifier.sleep.unitString, startDate: rollingInterval.start, endDate: rollingInterval.end)
                                    stageInsight.value += sampleTime
                                    sleepDeepDictionary[sampleId] = stageInsight
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
                if bedDictionary.isEmpty == false, let maxValue = bedDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maxValue.value)
                }
                if sleepDictionary.isEmpty == false, let maxValue = sleepDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maxValue.value)
                }
                if sleepREMDictionary.isEmpty == false, let maxValue = sleepREMDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maxValue.value)
                }
                if sleepLightDictionary.isEmpty == false, let maxValue = sleepLightDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maxValue.value)
                }
                if sleepDeepDictionary.isEmpty == false, let maxValue = sleepDeepDictionary.max(by: { $0.value.value < $1.value.value }) {
                    sleepInsights.append(maxValue.value)
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
                let startDate: Date = Calendar.current.startOfDay(for: date)
                let endDate: Date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startDate) ?? startDate
                
                sahhaInsights.append(SahhaInsight(name: .stand_hours_daily_total, value:                 activitySummary.appleStandHours.doubleValue(for: .count()) 
, unit: "hour", startDate: date, endDate: date))
                if #available(iOS 16.0, *) {
                    sahhaInsights.append(SahhaInsight(name: .stand_hours_daily_goal, value:                 activitySummary.standHoursGoal?.doubleValue(for: .count()) ?? 0
                                                      , unit: "hour", startDate: startDate, endDate: endDate))
                } else {
                    sahhaInsights.append(SahhaInsight(name: .stand_hours_daily_goal, value:                 activitySummary.appleStandHoursGoal.doubleValue(for: .count()) 
                                                      , unit: "hour", startDate: startDate, endDate: endDate))
                }
                sahhaInsights.append(SahhaInsight(name: .move_time_daily_total, value:                 activitySummary.appleMoveTime.doubleValue(for: .minute()) 
, unit: "minute", startDate: startDate, endDate: endDate))
                sahhaInsights.append(SahhaInsight(name: .move_time_daily_goal, value:                 activitySummary.appleMoveTimeGoal.doubleValue(for: .minute())
, unit: "minute", startDate: startDate, endDate: endDate))
                sahhaInsights.append(SahhaInsight(name: .exercise_time_daily_total, value:                 activitySummary.appleExerciseTime.doubleValue(for: .minute())
, unit: "minute", startDate: startDate, endDate: endDate))
                if #available(iOS 16.0, *) {
                    sahhaInsights.append(SahhaInsight(name: .exercise_time_daily_goal, value:                 activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) ?? 0
                                                      , unit: HealthTypeIdentifier.exercise_time.unitString, startDate: startDate, endDate: endDate))
                } else {
                    sahhaInsights.append(SahhaInsight(name: .exercise_time_daily_goal, value:                 activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()) 
                                                      , unit: HealthTypeIdentifier.exercise_time.unitString, startDate: startDate, endDate: endDate))
                }
                sahhaInsights.append(SahhaInsight(name: .active_energy_burned_daily_total, value:                 activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()) 
                                                  , unit: HealthTypeIdentifier.active_energy_burned.unitString, startDate: startDate, endDate: endDate))
                sahhaInsights.append(SahhaInsight(name: .active_energy_burned_daily_goal, value:                 activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie())
                                                  , unit: HealthTypeIdentifier.active_energy_burned.unitString, startDate: startDate, endDate: endDate))
            }
            
            callback(nil, sahhaInsights)
        }
        store.execute(query)
    }
    
    private func getRecordingMethod(_ sample: HKSample) -> String {
        var recordingMethod: String = "recording_method_unknown"
        if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
            recordingMethod = "recording_method_manual_entry"
        }
        return recordingMethod
    }
    
    private func postSleepSamples(samples: [HKCategorySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var requests: [HealthLogRequest] = []
        for sample in samples {
            let sleepStage: SleepStage
            
            if #available(iOS 16.0, *) {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    sleepStage = .sleep_stage_in_bed
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    sleepStage = .sleep_stage_awake
                case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                    sleepStage = .sleep_stage_rem
                case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                    sleepStage = .sleep_stage_light
                case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                    sleepStage = .sleep_stage_deep
                case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                    sleepStage = .sleep_stage_sleeping
                default:
                    sleepStage = .sleep_stage_unknown
                    break
                }
            }
            else {
                switch sample.value {
                case HKCategoryValueSleepAnalysis.inBed.rawValue:
                    sleepStage = .sleep_stage_in_bed
                case HKCategoryValueSleepAnalysis.awake.rawValue:
                    sleepStage = .sleep_stage_awake
                case HKCategoryValueSleepAnalysis.asleep.rawValue:
                    sleepStage = .sleep_stage_sleeping
                default:
                    sleepStage = .sleep_stage_unknown
                    break
                }
            }
            
            let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
            let value = Double(difference.minute ?? 0)
            
            let request = HealthLogRequest(sample.uuid, logType: HealthTypeIdentifier.sleep.rawValue, dataType: sleepStage.rawValue, value: value, unit: HealthTypeIdentifier.sleep.unitString, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
            requests.append(request)
        }
        
        postHealthLogs(requests, callback: callback)
    }

    
    private func postHealthSamples(healthType: HealthTypeIdentifier, samples: [HKQuantitySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        var requests: [HealthLogRequest] = []
        for sample in samples {
                        
            let value: Double = sample.quantity.doubleValue(for: healthType.unit)
            
            var request = HealthLogRequest(sample.uuid, healthType: healthType, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
            
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
                additionalProperties = [HealthLogPropertyIdentifier.measurementLocation.rawValue: stringValue]
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
                additionalProperties = [HealthLogPropertyIdentifier.measurementMethod.rawValue: stringValue]
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
                additionalProperties = [HealthLogPropertyIdentifier.motionContext.rawValue: stringValue]
            }
            
            if let metaValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber, let metaEnumValue = HKBloodGlucoseMealTime(rawValue: metaValue.intValue) {
                let relationToMeal: BloodRelationToMeal
                switch metaEnumValue {
                case .preprandial:
                    relationToMeal = .before_meal
                case .postprandial:
                    relationToMeal = .after_meal
                default:
                    relationToMeal = .unknown
                }
                additionalProperties = [HealthLogPropertyIdentifier.relationToMeal.rawValue: relationToMeal.rawValue]
            }
            
            if additionalProperties.isEmpty == false {
                request.additionalProperties = additionalProperties
            }
            
            requests.append(request)
        }
        
        postHealthLogs(requests, callback: callback)
    }
    
    private func postHealthLogs(_ healthRequests: [HealthLogRequest], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        APIController.postHealthLog(body: healthRequests) { result in
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
