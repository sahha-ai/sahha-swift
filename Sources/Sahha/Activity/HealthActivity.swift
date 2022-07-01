// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    private let sleepKey = "sleepActivityDate"
    private let pedometerKey = "pedometerActivityDate"
    
    internal private(set) var activityStatus: SahhaSensorStatus = .pending
    
    private let activitySensors: Set<SahhaSensor> = [.sleep, .pedometer]
    private var enabledSensors: Set<SahhaSensor> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var sampleTypes: Set<HKObjectType> = []
    
    internal init() {
        print("Sahha | Health init")
        //UserDefaults.standard.removeObject(forKey: sleepKey)
        //UserDefaults.standard.removeObject(forKey: pedometerKey)
    }
    
    internal func configure(sensors: Set<SahhaSensor>) {
        enabledSensors = activitySensors.intersection(sensors)
        sampleTypes = []
        if enabledSensors.contains(.sleep) {
            sampleTypes.insert(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!)
        }
        if enabledSensors.contains(.pedometer) {
            sampleTypes.insert(HKObjectType.quantityType(forIdentifier: .stepCount)!)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
                
        NotificationCenter.default.addObserver(self, selector: #selector(onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        print("Sahha | Health configured")
    }
    
    @objc private func onAppOpen() {
        checkAuthorization { _ in
        }
    }
    
    @objc private func onAppClose() {
    }
    
    private func checkAuthorization(_ callback: ((SahhaSensorStatus)->Void)? = nil) {
        guard isAvailable else {
            activityStatus = .unavailable
            callback?(activityStatus)
            return
        }
        guard sampleTypes.isEmpty == false else {
            activityStatus = .pending
            callback?(activityStatus)
            return
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
                    if self.activityStatus != .enabled {
                        self.activityStatus = .enabled
                        self.setupBackgroundDelivery()
                    }
                default:
                    self.activityStatus = .pending
                }
            }
            print("Sahha | Health activity status : \(self.activityStatus.description)")
            callback?(self.activityStatus)
        }
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    public func activate(_ callback: @escaping (SahhaSensorStatus)->Void) {
        
        guard activityStatus == .pending || activityStatus == .disabled else {
            callback(activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.store.requestAuthorization(toShare: [], read: self?.sampleTypes) { [weak self] success, error in
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
    
    internal func postSensorData(_ sensor: SahhaSensor, callback:((_ error: String?, _ success: Bool)-> Void)? = nil) {
        
        guard enabledSensors.contains(sensor) else {
            callback?("Sahha | \(sensor.rawValue) sensor is missing from Sahha.configure()", false)
            return
        }
        
        guard isAvailable else {
            callback?("Sahha | Health activity is not available", false)
            return
        }
        
        guard activityStatus == .enabled else {
            callback?("Sahha | Health activity is not enabled", false)
            return
        }
        
        switch sensor {
        case .sleep:
            checkSleepHistory() { [weak self] identifier, anchor, data in
                if data.isEmpty == false {
                    self?.postSleepRange(data: data, identifier: identifier, anchor: anchor, callback: callback)
                } else {
                    callback?("Sahha | No new Health sleep activity since last post", false)
                }
            }
        case .pedometer:
            checkQuantityHistory(typeId: .stepCount) { [weak self] identifier, anchor, data in
                if data.isEmpty == false {
                    self?.postPedometerRange(data: data, identifier: identifier, anchor: anchor, callback: callback)
                } else {
                    callback?("Sahha | No new Health pedometer activity since last post", false)
                }
            }
        default:
            callback?("Sahha | \(sensor.rawValue) sensor is not available", false)
        }
    }
    
    private func setupBackgroundDelivery() {
        
        guard isAvailable else {
            return
        }
        
        guard activityStatus == .enabled else {
            return
        }
        
        print("Sahha | Health background delivery ready")
        
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            enableBackgroundDelivery(healthType: sleepType, sensor: .sleep)
        }
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            enableBackgroundDelivery(healthType: stepType, sensor: .pedometer)
        }
    }
    
    private func enableBackgroundDelivery(healthType: HKObjectType, sensor: SahhaSensor) {
        store.enableBackgroundDelivery(for: healthType, frequency: HKUpdateFrequency.hourly) { [weak self] success, error in
            print("Sahha | Health background delivery triggered for \(sensor.rawValue)")
            if let error = error {
                print(error.localizedDescription)
                return
            }
            switch success {
            case true:
                if Sahha.settings.postSensorDataManually == false {
                    self?.postSensorData(sensor)
                }
                return
            case false:
                return
            }
        }
    }
    
    private func checkQuantityHistory(typeId: HKQuantityTypeIdentifier, callback: @escaping (String, HKQueryAnchor, [HealthRequest])->Void) {
        if let sampleType = HKObjectType.quantityType(forIdentifier: typeId) {
            checkHistory(sampleType: sampleType) { anchor, data in
                if let samples = data as? [HKQuantitySample] {
                    var healthSamples: [HealthRequest] = []
                    var unit: HKUnit
                    switch typeId {
                    case .stepCount:
                        unit = HKUnit.count()
                    default:
                        unit = HKUnit.count()
                    }
                    for sample in samples {
                        var manuallyEntered: Bool = false
                        if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                            manuallyEntered = true
                        }
                        let healthSample = HealthRequest(dataType: typeId.rawValue, count: sample.quantity.doubleValue(for: unit), source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
                        healthSamples.append(healthSample)
                    }
                    if healthSamples.isEmpty == false {
                        callback(sampleType.identifier, anchor, healthSamples)
                    }
                }
            }
        }
    }
    
    private func checkSleepHistory(callback: @escaping (String, HKQueryAnchor, [SleepRequest])->Void) {
        if let sampleType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            checkHistory(sampleType: sampleType) { anchor, data in
                if let samples = data as? [HKCategorySample] {
                    var requests: [SleepRequest] = []
                    for sample in samples {
                        var request: SleepRequest?
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
                        request = SleepRequest(stage: sleepStage, source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
                        if let request = request {
                            requests.append(request)
                        }
                    }
                    callback(sampleType.identifier, anchor, requests)
                }
            }
        }
    }
    
    private func checkHistory(sampleType: HKSampleType, callback: @escaping (HKQueryAnchor, [HKSample])->Void) {
        
        var anchor: HKQueryAnchor?
        var predicate: NSPredicate?
        // check if a previous anchor exists
        if let data = UserDefaults.standard.object(forKey: sampleType.identifier) as? Data, let object = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            anchor = object
        } else {
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            predicate = HKAnchoredObjectQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        }
        let query = HKAnchoredObjectQuery(type: sampleType,
                                          predicate: predicate,
                                          anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
            guard let samples = samplesOrNil, samples.isEmpty == false, let _ = deletedObjectsOrNil, let callbackAnchor = newAnchor else {
                print(sampleType.identifier)
                if let error = errorOrNil {
                    print(error.localizedDescription)
                }
                return
            }
            callback(callbackAnchor, samples)
        }
        
        store.execute(query)
    }
    
    private func postSleepRange(data: [SleepRequest], identifier: String, anchor: HKQueryAnchor, callback: ((_ error: String?, _ success: Bool)-> Void)? = nil) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postSleepRange(data: newData, identifier: identifier, anchor: anchor)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postSleepRange(data: oldData, identifier: identifier, anchor: anchor, callback: callback)
        } else {
            APIController.postSleep(body: data) { [weak self] result in
                switch result {
                case .success(_):
                    // Save anchor
                    if let data: Data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false) {
                        UserDefaults.standard.set(data, forKey: identifier)
                        if let key = self?.sleepKey {
                            UserDefaults.standard.set(date: Date(), forKey: key)
                        }
                    }
                    callback?(nil, true)
                case .failure(let error):
                    print(error.localizedDescription)
                    callback?(error.localizedDescription, false)
                }
            }
        }
    }
    
    private func postPedometerRange(data: [HealthRequest], identifier: String, anchor: HKQueryAnchor, callback: ((_ error: String?, _ success: Bool)-> Void)? = nil) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postPedometerRange(data: newData, identifier: identifier, anchor: anchor)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postPedometerRange(data: oldData, identifier: identifier, anchor: anchor, callback: callback)
        } else {
            APIController.postMovement(body: data) { [weak self] result in
                switch result {
                case .success(_):
                    // Save anchor
                    if let data: Data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false) {
                        UserDefaults.standard.set(data, forKey: identifier)
                        if let key = self?.pedometerKey {
                            UserDefaults.standard.set(date: Date(), forKey: key)
                        }
                    }
                    callback?(nil, true)
                case .failure(let error):
                    print(error.localizedDescription)
                    callback?(error.localizedDescription, false)
                }
            }
        }
    }
}
