// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public struct HealthActivitySample: Encodable, Hashable {
    public var isAsleep: Bool
    public var startDate: Date
    public var endDate: Date
    public var count: Int
    
    init(isAsleep: Bool, startDate: Date, endDate: Date) {
        self.isAsleep = isAsleep
        self.startDate = startDate
        self.endDate = endDate
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.count = difference.minute ?? 0
    }
}

public class HealthActivity {
    
    public private(set) var activityStatus: ActivityStatus = .pending
    public private(set) var activityHistory: [HealthActivitySample] = []
    
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    
    private let store: HKHealthStore = HKHealthStore()
    private let sampleTypes = Set([
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
    ])
    
    init() {
        print("health")
                
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func configure() {
    }
    
    @objc private func onAppOpen() {
        print("health open")
        checkAuthorization { [weak self] _ in
            self?.checkHistory()
        }
    }
    
    private func checkAuthorization(_ callback: ((ActivityStatus)->Void)? = nil) {
        guard isAvailable else {
            activityStatus = .unavailable
            callback?(activityStatus)
            return
        }
        store.getRequestStatusForAuthorization(toShare: [], read: sampleTypes) { [weak self] status, error in
            
            guard let self = self else {
                return
            }
            
            if let error = error {
                print("health error")
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
            print("health status : \(self.activityStatus.description)")
            callback?(self.activityStatus)
        }
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    public func activate(_ callback: @escaping (ActivityStatus)->Void) {
        
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
    
    private func checkHistory() {
        if activityStatus == .enabled {
            checkSleepHistory() { [weak self] identifier, anchor, data, history in
                if data.isEmpty == false {
                    self?.postSleepRange(data: data, identifier: identifier, anchor: anchor)
                }
                self?.activityHistory = history
            }
        }
    }
    
    private func checkQuantity(typeId: HKQuantityTypeIdentifier, unit: HKUnit, callback: @escaping (String, HKQueryAnchor, [HealthRequest])->Void) {
        if let sampleType = HKObjectType.quantityType(forIdentifier: typeId) {
            checkHistory(sampleType: sampleType) { anchor, data in
                if let samples = data as? [HKQuantitySample] {
                    var healthSamples: [HealthRequest] = []
                    for sample in samples {
                        let healthSample = HealthRequest(count: sample.quantity.doubleValue(for: unit), startDate: sample.startDate, endDate: sample.endDate)
                        healthSamples.append(healthSample)
                    }
                    if healthSamples.isEmpty == false {
                        callback(sampleType.identifier, anchor, healthSamples)
                    }
                }
            }
        }
    }
    
    private func checkSleepHistory(callback: @escaping (String, HKQueryAnchor, [SleepRequest], [HealthActivitySample])->Void) {
        if let sampleType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            checkHistory(sampleType: sampleType) { anchor, data in
                if let samples = data as? [HKCategorySample] {
                    var requests: [SleepRequest] = []
                    var history: [HealthActivitySample] = []
                    for sample in samples {
                        if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                            let request = SleepRequest(startDate: sample.startDate, endDate: sample.endDate)
                            requests.append(request)
                            history.append(HealthActivitySample(isAsleep: true, startDate: sample.startDate, endDate: sample.endDate))
                        } else {
                            history.append(HealthActivitySample(isAsleep: false, startDate: sample.startDate, endDate: sample.endDate))
                        }
                    }
                    callback(sampleType.identifier, anchor, requests, history)
                }
            }
        }
    }
    
    private func checkHistory(sampleType: HKSampleType, callback: @escaping (HKQueryAnchor, [HKSample])->Void) {
        
        var anchor: HKQueryAnchor?
        // Filter out samples that were added manually by the user
        let sourcePredicate = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        var compoundPredicate: NSPredicate?
        // check if a previous anchor exists
        if let data = UserDefaults.standard.object(forKey: sampleType.identifier) as? Data, let object = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            anchor = object
            print("old anchor " + sampleType.identifier)
            compoundPredicate = NSCompoundPredicate(type: .and, subpredicates: [sourcePredicate])

        } else {
            print("empty anchor " + sampleType.identifier)
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let timePredicate = HKAnchoredObjectQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
            compoundPredicate = NSCompoundPredicate(type: .and, subpredicates: [timePredicate, sourcePredicate])
        }
        let query = HKAnchoredObjectQuery(type: sampleType,
                                          predicate: compoundPredicate,
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
    
    private func postSleepRange(data: [SleepRequest], identifier: String, anchor: HKQueryAnchor) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postSleepRange(data: newData, identifier: identifier, anchor: anchor)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postSleepRange(data: oldData, identifier: identifier, anchor: anchor)
        } else {
            APIController.postSleep(body: data) { result in
                switch result {
                case .success(_):
                    // Save anchor
                    if let data: Data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: false) {
                        UserDefaults.standard.set(data, forKey: identifier)
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                    return
                }
            }
        }
    }
}
