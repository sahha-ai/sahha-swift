// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    internal private(set) var activityStatus: SahhaSensorStatus = .pending
    
    private let activitySensors: Set<SahhaSensor> = [.sleep, .pedometer]
    private var enabledSensors: Set<SahhaSensor> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var sampleTypes: Set<HKObjectType> = []
    private var configureCallback: (() -> Void)?
    
    internal init() {
        print("Sahha | Health init")
        //clearAllData()
    }
    
    private func clearAllData() {
        if let value = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            clearDate(value.identifier)
        }
        if let value = HKObjectType.quantityType(forIdentifier: .stepCount) {
            clearDate(value.identifier)
        }
    }
    
    private func clearDate(_ identifier: String) {
        print("Sahha | Clear date", identifier)
        UserDefaults.standard.removeObject(forKey: identifier + "Start")
        UserDefaults.standard.removeObject(forKey: identifier)
    }
    
    private func setDate(_ identifier: String, date: Date) {
        print("Sahha | Set date", identifier, date.toTimezoneFormat)
        let startDate = UserDefaults.standard.date(forKey: identifier) ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        UserDefaults.standard.set(date: startDate, forKey: identifier + "Start")
        UserDefaults.standard.set(date: date, forKey: identifier)
    }
    
    internal func configure(sensors: Set<SahhaSensor>, callback: (() -> Void)? = nil) {
        configureCallback = callback
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
        checkAuthorization { [weak self] _ in
            self?.configureCallback?()
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
            checkSleepHistory() { [weak self] identifier, date, data in
                if data.isEmpty == false {
                    self?.postSleepRange(data: data, identifier: identifier, date: date, callback: callback)
                } else {
                    callback?("Sahha | No new Health sleep activity since last post", false)
                }
            }
        case .pedometer:
            checkQuantityHistory(typeId: .stepCount) { [weak self] identifier, date, data in
                if data.isEmpty == false {
                    self?.postPedometerRange(data: data, identifier: identifier, date: date, callback: callback)
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
        
        
        if let sampleType = HKSampleType.categoryType(forIdentifier: .sleepAnalysis) {
            enableBackgroundDelivery(sampleType: sampleType, sensor: .sleep)
        }
        if let sampleType = HKSampleType.quantityType(forIdentifier: .stepCount) {
            enableBackgroundDelivery(sampleType: sampleType, sensor: .pedometer)
        }
    }
    
    private func enableBackgroundDelivery(sampleType: HKSampleType, sensor: SahhaSensor) {
        store.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.hourly) { [weak self] success, error in
            print("Sahha | Health background delivery enabled for \(sensor.rawValue)")
            if let error = error {
                print(error.localizedDescription)
                return
            }
            switch success {
            case true:
                let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                    print("Sahha | Health background delivery received for \(sensor.rawValue)")
                    if let _ = errorOrNil {
                        completionHandler()
                        return
                    }
                    if Sahha.settings.postSensorDataManually == false {
                        self?.postSensorData(sensor, callback: { error, success in
                            completionHandler()
                        })
                    } else {
                        completionHandler()
                    }
                }
                if let store = self?.store {
                    store.execute(query)
                }
                return
            case false:
                return
            }
        }
    }
    
    private func checkQuantityHistory(typeId: HKQuantityTypeIdentifier, callback: @escaping (String, Date, [HealthRequest])->Void) {
        if let sampleType = HKObjectType.quantityType(forIdentifier: typeId) {
            let startDate = UserDefaults.standard.date(forKey: sampleType.identifier) ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let endDate = Date()
            getHistory(sampleType: sampleType, startDate: startDate, endDate: endDate) { error, data in
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
                    callback(sampleType.identifier, endDate, healthSamples)
                }
            }
        }
    }
    
    private func checkSleepHistory(callback: @escaping (String, Date, [SleepRequest])->Void) {
        if let sampleType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            let startDate = UserDefaults.standard.date(forKey: sampleType.identifier) ?? Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let endDate = Date()
            getHistory(sampleType: sampleType, startDate: startDate, endDate: endDate) { error, data in
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
                    callback(sampleType.identifier, endDate, requests)
                }
            }
        }
    }
    
    private func getHistory(sampleType: HKSampleType, startDate: Date, endDate: Date, callback: @escaping (String?, [HKSample])->Void) {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
        let sortByDate = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortByDate]) { query, samples, error in
            print("Sahha | Get history", sampleType.identifier, startDate.toTimezoneFormat, endDate.toTimezoneFormat, samples?.count ?? 0)
            if let error = error {
                callback(error.localizedDescription, [])
                return
            }
            guard let samples = samples else {
                callback("No sensor data found", [])
                return
            }
            callback(nil, samples)
            return
        }
        store.execute(query)
    }
    
    private func postSleepRange(data: [SleepRequest], identifier: String, date: Date, callback: ((_ error: String?, _ success: Bool)-> Void)? = nil) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postSleepRange(data: newData, identifier: identifier, date: date)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postSleepRange(data: oldData, identifier: identifier, date: date, callback: callback)
        } else {
            //setDate(identifier, date: date)
            APIController.postSleep(body: data) { [weak self] result in
                switch result {
                case .success(_):
                    self?.setDate(identifier, date: date)
                    callback?(nil, true)
                case .failure(let error):
                    print(error.localizedDescription)
                    callback?(error.localizedDescription, false)
                }
            }
        }
    }
    
    private func postPedometerRange(data: [HealthRequest], identifier: String, date: Date, callback: ((_ error: String?, _ success: Bool)-> Void)? = nil) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postPedometerRange(data: newData, identifier: identifier, date: date)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postPedometerRange(data: oldData, identifier: identifier, date: date, callback: callback)
        } else {
            //setDate(identifier, date: date)
            APIController.postMovement(body: data) { [weak self] result in
                switch result {
                case .success(_):
                    self?.setDate(identifier, date: date)
                    callback?(nil, true)
                case .failure(let error):
                    print(error.localizedDescription)
                    callback?(error.localizedDescription, false)
                }
            }
        }
    }
}
