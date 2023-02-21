// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    internal private(set) var activityStatus: SahhaSensorStatus = .pending {
        didSet {
            if activityStatus == .enabled {
                enableBackgroundDelivery()
            }
        }
    }
    private let activitySensors: Set<SahhaSensor> = [.sleep, .pedometer]
    private var enabledSensors: Set<SahhaSensor> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxSampleLimit: Int = 32
    private var sampleTypes: Set<HKSampleType> = []
    private var backgroundSampleTypes: Set<HKSampleType> = []
    private var backgroundSensors: Set<SahhaSensor> = []
    
    internal init() {
        print("Sahha | Health init")
    }
    
    private func clearAllData() {
        for sampleType in sampleTypes {
            setAnchor(anchor: nil, anchorName: sampleType.identifier)
        }
    }
    
    internal func configure(sensors: Set<SahhaSensor>, callback: (() -> Void)? = nil) {
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
    
    private func setAnchor(anchor: HKQueryAnchor?, anchorName: String) {
        guard let anchor = anchor else {
            UserDefaults.standard.removeObject(forKey: anchorName)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: anchorName)
        } catch {
            print("Sahha | Unable to set health anchor", anchorName)
        }
    }

    private func getAnchor(anchorName: String) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: anchorName) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            print("Sahha | Unable to get health anchor", anchorName)
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
        
        for sampleType in sampleTypes {
            
            if backgroundSampleTypes.contains(sampleType) {
                return
            }
            
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
                            self?.backgroundSampleTypes.insert(sampleType)
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
        
        guard backgroundSensors.isEmpty else {
            callback("Sahha | Post sensor data task is already in progress", false)
            return
        }
        
        let sensorCallback: (_ error: String?, _ success: Bool) -> Void = { [weak self] error, success in
            // Clean up
            self?.backgroundSensors.removeAll()
            
            // Pass to parent callback
            callback(error, success)
            
            return
        }
        
        backgroundSensors = enabledSensors
        
        postNextSensorData(callback: sensorCallback)
    }
    
    private func postNextSensorData(callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        guard backgroundSensors.isEmpty == false else {
            print("Sahha | Post sensor data successfully completed")
            callback(nil, true)
            return
        }
        
        let sensor = backgroundSensors.removeFirst()
        postSensorData(sensor: sensor, callback: callback)
    }
    
    private func postSensorData(sensor: SahhaSensor, callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        let sampleType: HKSampleType
        switch sensor {
        case .sleep:
            sampleType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        case .pedometer:
            sampleType = HKSampleType.quantityType(forIdentifier: .stepCount)!
        default:
            callback("Sahha | \(sensor.rawValue) sensor is not available", false)
            return
        }
        
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
        let anchor = getAnchor(anchorName: sampleType.identifier)
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: maxSampleLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
            if let error = errorOrNil {
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
                return
            }
            guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                self?.postNextSensorData(callback: callback)
                return
            }
            
            switch sensor {
            case .sleep:
                guard let categorySamples = samples as? [HKCategorySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postSleepRange(samples: categorySamples) { error, success in
                    if success {
                        self?.setAnchor(anchor: newAnchor, anchorName: sampleType.identifier)
                        self?.postSensorData(sensor: sensor, callback: callback)
                    } else {
                        callback(error, success)
                    }
                }
            case .pedometer:
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    self?.postNextSensorData(callback: callback)
                    return
                }
                self?.postMovementRange(samples: quantitySamples) { error, success in
                    if success {
                        self?.setAnchor(anchor: newAnchor, anchorName: sampleType.identifier)
                        self?.postSensorData(sensor: sensor, callback: callback)
                    } else {
                        callback(error, success)
                    }
                }
            default:
                callback("Sahha | \(sensor.rawValue) sensor is not available", false)
                return
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

        let healthIdentifier: String = HKQuantityTypeIdentifier.stepCount.rawValue
        var healthRequests: [HealthRequest] = []
        for sample in samples {
            var manuallyEntered: Bool = false
            if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
                manuallyEntered = true
            }
            let healthRequest = HealthRequest(dataType: healthIdentifier, count: sample.quantity.doubleValue(for: .count()), source: sample.sourceRevision.source.bundleIdentifier, manuallyEntered: manuallyEntered, startDate: sample.startDate, endDate: sample.endDate)
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
}
