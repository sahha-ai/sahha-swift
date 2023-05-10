// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    internal private(set) var activityStatus: SahhaSensorStatus = .pending {
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
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxSampleLimit: Int = 32
    private var bloodGlucoseUnit: HKUnit = .count()
    
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
                return HKObjectType.quantityType(forIdentifier: .stepCount)!
            case .HeartRate:
                return HKObjectType.quantityType(forIdentifier: .heartRate)!
            case .RestingHeartRate:
                return HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
            case .WalkingHeartRateAverage:
                return HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)!
            case .HeartRateVariability:
                return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
            case .BloodPressureSystolic:
                return HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!
            case .BloodPressureDiastolic:
                return HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!
            case .BloodGlucose:
                return HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
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
        
        checkAuthorization() { _ in
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
        }
    }

    private func getAnchor(healthType: HealthTypeIdentifier) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: healthType.keyName) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            print("Sahha | Unable to get health anchor", healthType.keyName)
            return nil
        }
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    public func activate(_ callback: @escaping (SahhaSensorStatus)->Void) {
        
        guard activityStatus == .pending || activityStatus == .disabled else {
            callback(activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            var sampleTypes: Set<HKSampleType> = []
            if let healthTypes = self?.enabledHealthTypes {
                for healthType in healthTypes {
                    sampleTypes.insert(healthType.sampleType)
                }
            }
            self?.store.requestAuthorization(toShare: [], read: sampleTypes) { [weak self] success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print(error.localizedDescription)
                    }
                    self?.checkAuthorization({ newStatus in
                        callback(newStatus)
                    })
                }
            }
        }
    }
    
    private func checkAuthorization(_ callback: ((SahhaSensorStatus)->Void)? = nil) {
        guard isAvailable else {
            activityStatus = .unavailable
            callback?(activityStatus)
            return
        }
        guard enabledHealthTypes.isEmpty == false else {
            activityStatus = .pending
            callback?(activityStatus)
            return
        }
        var sampleTypes: Set<HKSampleType> = []
        for healthType in enabledHealthTypes {
            sampleTypes.insert(healthType.sampleType)
        }
        store.getRequestStatusForAuthorization(toShare: [], read: sampleTypes) { [weak self] status, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                print("Sahha | Health error")
                print(error.localizedDescription)
                self.activityStatus = .pending
            } else {
                switch status {
                case .unnecessary:
                    self.activityStatus = .enabled
                default:
                    self.activityStatus = .pending
                }
            }
            print("Sahha | Health activity status : \(self.activityStatus.description)")
            callback?(self.activityStatus)
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
                    return
                }
                
                switch status {
                case .unnecessary:
                    self?.store.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate) { [weak self] success, error in
                        if let error = error {
                            print(error.localizedDescription)
                            return
                        }
                        switch success {
                        case true:
                            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                                if let error = errorOrNil {
                                    print(error.localizedDescription)
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
        
        let sensorCallback: (_ error: String?, _ success: Bool) -> Void = { [weak self] error, success in
            // Clean up
            self?.backgroundHealthTypes.removeAll()
            
            // Pass to parent callback
            callback(error, success)
            
            return
        }
        
        backgroundHealthTypes = enabledHealthTypes
        
        store.preferredUnits(for: [HKObjectType.quantityType(forIdentifier: .bloodGlucose)!]) { [weak self] unitTypes, error in
            if let _ = error {
                // do nothing
            } else if let unitType = unitTypes.first {
                self?.bloodGlucoseUnit = unitType.value
            }
            
            self?.postNextSensorData(callback: sensorCallback)
        }
    }
    
    private func postNextSensorData(callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        guard backgroundHealthTypes.isEmpty == false else {
            print("Sahha | Post sensor data successfully completed")
            callback(nil, true)
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
    
    private func postSleepRange(samples: [HKCategorySample], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        //let healthIdentifier: String = HKCategoryTypeIdentifier.sleepAnalysis.rawValue
        var sleepRequests: [SleepRequest] = []
        for sample in samples {
            let sleepStage: SleepStage
            switch sample.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                sleepStage = .inBed
            case HKCategoryValueSleepAnalysis.asleep.rawValue:
                sleepStage = .asleep
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                sleepStage = .awake
            default:
                sleepStage = .unknown
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
