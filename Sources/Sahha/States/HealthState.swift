//
//  HealthState.swift
//  
//
//  Created by Matthew on 2/11/22.
//

import SwiftUI
import HealthKit

class HealthState {
    private var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private var authorizationStatus: HKAuthorizationRequestStatus = .unknown

    private var isAuthorized: Bool {
        authorizationStatus == .unnecessary
    }
    
    private var isNotAuthorized: Bool {
        authorizationStatus == .shouldRequest
    }
    
    private let store: HKHealthStore = HKHealthStore()
    private let sampleTypes = Set([
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
    ])
    
    init() {
        print("health")
        checkAuthorization()
    }
    
    private func checkAuthorization() {
        if isAvailable {
            store.getRequestStatusForAuthorization(toShare: [], read: sampleTypes) { status, error in
                if let error = error {
                    print("health error")
                    print(error.localizedDescription)
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.authorizationStatus = status
                        print("health status \(String(describing: status))")
                    }
                }
            }
        } else {
            print("health not available")
        }
    }
    
    func requestPermission() {
        guard isAvailable else {
            return
        }
        
        if isAuthorized {
            return
        }
        
        store.requestAuthorization(toShare: [], read: sampleTypes) { [weak self] success, error in
            switch success {
            case true:
                DispatchQueue.main.async { [weak self] in
                    if let self = self {
                        self.checkAuthorization()
                    }
                }
                return
            case false:
                if let error = error {
                    print(error.localizedDescription)
                }
                return
            }
        }
    }
    
    func checkHistory() {
        if isAvailable && isAuthorized {
            checkCategory(typeId: .sleepAnalysis) { [weak self] identifier, anchor, sleepSamples, bedSamples in
                if sleepSamples.isEmpty == false {
                    self?.postHealthRange(dataType: .timeAsleep, data: sleepSamples, identifier: identifier, anchor: anchor)
                }
                if bedSamples.isEmpty == false {
                    self?.postHealthRange(dataType: .timeInBed, data: bedSamples, identifier: identifier, anchor: anchor)
                }
            }
            checkQuantity(typeId: .stepCount, unit: .count()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .stepCount, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .flightsClimbed, unit: .count()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .flightsClimbed, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .distanceWalkingRunning, unit: .meter()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .distanceWalkingRunning, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .walkingSpeed, unit: .meter().unitDivided(by: .second())) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .walkingSpeed, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .walkingDoubleSupportPercentage, unit: .percent()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .walkingDoubleSupportPercentage, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .walkingAsymmetryPercentage, unit: .percent()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .walkingAsymmetryPercentage, data: samples, identifier: identifier, anchor: anchor)
            }
            checkQuantity(typeId: .walkingStepLength, unit: .meter()) { [weak self] identifier, anchor, samples in
                self?.postHealthRange(dataType: .walkingStepLength, data: samples, identifier: identifier, anchor: anchor)
            }
        }
    }
    
    func checkQuantity(typeId: HKQuantityTypeIdentifier, unit: HKUnit, callback: @escaping (String, HKQueryAnchor, [HealthRequest])->Void) {
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
    
    func checkCategory(typeId: HKCategoryTypeIdentifier, callback: @escaping (String, HKQueryAnchor, [HealthRequest],[HealthRequest])->Void) {
        if let sampleType = HKObjectType.categoryType(forIdentifier: typeId) {
            checkHistory(sampleType: sampleType) { anchor, data in
                if let samples = data as? [HKCategorySample] {
                    var sleepSamples: [HealthRequest] = []
                    var bedSamples: [HealthRequest] = []
                    for sample in samples {
                        let integer = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate).minute ?? 0
                        let double = Double(integer)
                        let healthSample = HealthRequest(count: double, startDate: sample.startDate, endDate: sample.endDate)
                        if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                            bedSamples.append(healthSample)
                        } else if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                            sleepSamples.append(healthSample)
                        }
                    }
                    callback(sampleType.identifier, anchor, sleepSamples, bedSamples)
                }
            }
        }
    }
    
    func checkHistory(sampleType: HKSampleType, callback: @escaping (HKQueryAnchor, [HKSample])->Void) {
        
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
    
    func postHealthRange(dataType: HealthTypeIdentifer, data: [HealthRequest], identifier: String, anchor: HKQueryAnchor) {
    }
}
