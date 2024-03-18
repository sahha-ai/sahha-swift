// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    private(set) var activityStatus: SahhaSensorStatus = .pending {
        didSet {
            if activityStatus == .enabled, oldValue != .enabled {
                enableBackgroundDelivery()
                getDemographic()
            } else if activityStatus != .enabled, oldValue == .enabled {
                store.disableAllBackgroundDelivery { _, _ in
                }
            }
        }
    }
    private let activitySensors: Set<SahhaSensor> = Set(SahhaSensor.allCases)
    private var enabledHealthTypes: Set<HealthTypeIdentifier> = []
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxHealthLogRequestLimit: Int = 64
    private var healthLogRequests: [HealthLogRequest] = []
    
    private enum StatisticType: String {
        case total
        case average
        case minimum
        case maximum
        case most_recent
    }
    
    internal init() {
        loadHealthLogData()
    }
    
    internal func clearAllData() {
        for healthType in HealthTypeIdentifier.allCases {
            setAnchor(anchor: nil, healthType: healthType)
        }
        setInsightDate(nil)
    }
    
    internal func clearTestData() {
        setAnchor(anchor: nil, healthType: .active_energy_burned)
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
                
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceUnlock), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceLock), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        
        checkAuthorization() { _, _ in
            // print("Sahha | Health configured")
            callback?()
        }
    }
    
    @objc fileprivate func onAppOpen() {
        checkAuthorization()
    }
    
    @objc fileprivate func onAppClose() {
    }
    
    @objc fileprivate func onDeviceUnlock() {
        if enabledHealthTypes.contains(.device_lock) {
            createDeviceLog(false)
        }
    }
    
    @objc fileprivate func onDeviceLock() {
        if enabledHealthTypes.contains(.device_lock) {
            createDeviceLog(true)
        }
    }
    
    fileprivate func setAnchor(anchor: HKQueryAnchor?, healthType: HealthTypeIdentifier) {
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
    
    fileprivate func getAnchor(healthType: HealthTypeIdentifier) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: healthType.keyName) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            print("Sahha | Unable to get health anchor", healthType.keyName)
            Sahha.postError(message: "Unable to get health anchor", path: "HealthActivity", method: "getAnchor", body: healthType.keyName)
            return nil
        }
    }
    
    fileprivate func setInsightDate(_ date: Date?) {
        UserDefaults.standard.set(date: date, forKey: "SahhaInsightDate")
    }
    
    fileprivate func getInsightDate() -> Date? {
        return UserDefaults.standard.date(forKey: "SahhaInsightDate")
    }
    
    fileprivate func loadHealthLogData() {
        let healthLogData = UserDefaults.standard.array(forKey: "SahhaHealthLogRequests") as? [Data] ?? []
        
        let decoder = JSONDecoder()
        for data in healthLogData {
            do {
                let request = try decoder.decode(HealthLogRequest.self, from: data)
                healthLogRequests.append(request)
            } catch {
                // Fallback
            }
        }
    }
    
    fileprivate func saveHealthLogData() {
        
        let encoder = JSONEncoder()
        var healthLogData: [Data] = []
        var healthLogRequestsCopy = healthLogRequests
        while healthLogRequestsCopy.isEmpty == false {
            do {
                let healthLogRequest = healthLogRequestsCopy.popLast()
                let data = try encoder.encode(healthLogRequest)
                healthLogData.append(data)
            } catch {
                // Fallback
            }
        }
        
        UserDefaults.standard.setValue(healthLogData, forKey: "SahhaHealthLogRequests")
    }
    
    fileprivate func getDemographic() {
        
        // Create an empty object
        var demographic = SahhaStorage.demographic
        
        if demographic.gender != nil, demographic.birthDate != nil {
            // We already have the latest value
            //return
        }
        
        var genderString: String?
        var birthDateString: String?
        
        // Get the missing gender
        if demographic.gender == nil {
            do {
                // Get the HealthKit gender
                let gender = try store.biologicalSex()
                switch gender.biologicalSex {
                case .male:
                    genderString = "male"
                case .female:
                    genderString = "female"
                case .other:
                    genderString = "gender diverse"
                default:
                    break
                }
            } catch let error {
                filterError(error, path: "HealthActivity", method: "getDemographic", body: "let gender = try store.biologicalSex()")
            }
        }
        
        // Get the missing birth date
        if demographic.birthDate == nil {
            do {
                // Get the HealthKit birth date
                let dateOfBirth = try store.dateOfBirthComponents()
                if let dateString = dateOfBirth.date?.toYYYYMMDD {
                    birthDateString = dateString
                }
            } catch let error {
                filterError(error, path: "HealthActivity", method: "getDemographic", body: "let dateOfBirth = try store.dateOfBirthComponents()")
            }
        }
        
        guard genderString != nil || birthDateString != nil else {
            // There are no HealthKit values to save
            return
        }
        
        Sahha.getDemographic { error, result in
            if let result = result {
                demographic = result
                if demographic.gender == nil {
                    demographic.gender = genderString
                }
                if demographic.birthDate == nil {
                    demographic.birthDate = birthDateString
                }
            }
            
            // Save the demographic
            SahhaStorage.saveDemographic(demographic)
            
            // Post the demographic
            Sahha.postDemographic(demographic) { _, _ in
            }
        }
    }
    
    fileprivate func filterError(_ error: Error, path: String, method: String, body: String) {
        print(error.localizedDescription)
        if let healthError = error as? HKError, healthError.code == HKError.Code.errorDatabaseInaccessible {
            // The device is currently locked so data is inaccessible
            // This should be considered a warning instead of an error
            // Avoid sending an error message
        } else {
            Sahha.postError(message: error.localizedDescription, path: path, method: method, body: body)
        }
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    public func activate(_ callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        guard activityStatus == .pending || activityStatus == .disabled else {
            callback(nil, activityStatus)
            return
        }
        
        var objectTypes: Set<HKObjectType> = []
        for healthType in enabledHealthTypes {
            if let objectType = healthType.objectType {
                objectTypes.insert(objectType)
            }
        }
        
        guard objectTypes.isEmpty == false else {
            activityStatus = .pending
            callback("Sahha | Health data types not specified", activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
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
        
        var objectTypes: Set<HKObjectType> = []
        for healthType in enabledHealthTypes {
            if let objectType = healthType.objectType {
                objectTypes.insert(objectType)
            }
        }
        
        guard objectTypes.isEmpty == false else {
            activityStatus = .pending
            callback?("Sahha | Health data types not specified", activityStatus)
            return
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
            // print("Sahha | Health activity status : \(self.activityStatus.description)")
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
                                self?.filterError(error, path: "HealthActivity", method: "enableBackgroundDelivery", body: "self?.store.enableBackgroundDelivery")
                                return
                            }
                            switch success {
                            case true:
                                // HKObserverQuery is the only query type that can run in the background - we then need to use HKAnchoredObjectQuery once the app is notified of a change to the HealthKit Store
                                let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                                    if let error = errorOrNil {
                                        self?.filterError(error, path: "HealthActivity", method: "enableBackgroundDelivery", body: "let query = HKObserverQuery")
                                        // return before completionHandler() is called
                                        return
                                    } else {
                                        self?.postSensorData(healthType: healthType)
                                    }
                                    // If you have subscribed for background updates you must call the completion handler here
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
    
    internal func postSensorData(healthType: HealthTypeIdentifier) {
        
        guard isAvailable, activityStatus == .enabled, Sahha.isAuthenticated else {
            return
        }
        
        postInsights()
        
        if let sampleType = healthType.objectType as? HKSampleType {
            let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
            let anchor = getAnchor(healthType: healthType)
            let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
                if let error = errorOrNil {
                    self?.filterError(error, path: "HealthActivity", method: "postSensorData", body: "let query = HKAnchoredObjectQuery")
                    return
                }
                guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                    return
                }
                
                switch healthType.sensorType {
                case .sleep:
                    guard let categorySamples = samples as? [HKCategorySample] else {
                        print("Sahha | Sleep samples in incorrect format")
                        return
                    }
                    self?.setAnchor(anchor: newAnchor, healthType: healthType)
                    self?.createSleepLogs(samples: categorySamples)
                case .exercise:
                    guard let workoutSamples = samples as? [HKWorkout] else {
                        print("Sahha | Exercise samples in incorrect format")
                        return
                    }
                    self?.setAnchor(anchor: newAnchor, healthType: healthType)
                    self?.createExerciseLogs(samples: workoutSamples)
                default:
                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        print("Sahha | \(healthType.rawValue) samples in incorrect format")
                        return
                    }
                    self?.setAnchor(anchor: newAnchor, healthType: healthType)
                    self?.createHealthLogs(healthType: healthType, samples: quantitySamples)
                }
            }
            store.execute(query)
        }
    }
    
    internal func postInsights() {
        
        guard isAvailable, activityStatus == .enabled, Sahha.isAuthenticated else {
            return
        }
        
        let today = Date()
        // Set startDate to a week prior if date is nil (first app launch)
        let startDate = getInsightDate() ?? Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today
        let endDate = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        
        // Only check once per day
        if Calendar.current.isDateInToday(startDate) == false, today > startDate {
            
            // Prevent duplication
            setInsightDate(today)
            
            let startComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: startDate)
            let endComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: endDate)
            
            let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
            
            let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] query, result, error in
                
                if let error = error {
                    // Reset insight date
                    self?.setInsightDate(startDate)
                    self?.filterError(error, path: "HealthActivity", method: "getActivitySummary", body: "")
                    return
                }
                
                guard let result = result, !result.isEmpty else {
                    print("Sahha | Health Activity Summary is empty")
                    return
                }
                
                var requests: [HealthLogRequest] = []
                
                for activitySummary in result {
                    
                    let logType = SahhaSensor.energy.rawValue
                    let dateComponents = activitySummary.dateComponents(for: Calendar.current)
                    let date = dateComponents.date ?? Date()
                    let summaryStartDate: Date = Calendar.current.startOfDay(for: date)
                    let summaryEndDate: Date = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: summaryStartDate) ?? summaryStartDate
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.stand_hours_daily_total.rawValue, value: activitySummary.appleStandHours.doubleValue(for: .count()), unit: "hour", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    
                    if #available(iOS 16.0, *), let value = activitySummary.standHoursGoal?.doubleValue(for: .count()) {
                        requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.stand_hours_daily_goal.rawValue, value: value, unit: "hour", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    } else {
                        requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.stand_hours_daily_goal.rawValue, value: activitySummary.appleStandHoursGoal.doubleValue(for: .count()) , unit: "hour", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    }
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.move_time_daily_total.rawValue, value: activitySummary.appleMoveTime.doubleValue(for: .minute()) , unit: "minute", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.move_time_daily_goal.rawValue, value: activitySummary.appleMoveTimeGoal.doubleValue(for: .minute()) , unit: "minute", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.exercise_time_daily_total.rawValue, value: activitySummary.appleExerciseTime.doubleValue(for: .minute()) , unit: "minute", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    
                    if #available(iOS 16.0, *), let value = activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) {
                        requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.exercise_time_daily_goal.rawValue, value: value , unit: "minute", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    } else {
                        requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.exercise_time_daily_goal.rawValue, value: activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()), unit: "minute", source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    }
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.active_energy_burned_daily_total.rawValue, value: activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()), unit: HealthTypeIdentifier.active_energy_burned.unitString, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                    
                    requests.append(HealthLogRequest(UUID(), logType: logType, dataType: ActivitySummaryIdentifier.active_energy_burned_daily_goal.rawValue, value: activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie()), unit: HealthTypeIdentifier.active_energy_burned.unitString, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: summaryStartDate, endDate: summaryEndDate))
                }
                
                self?.addPendingHealthLogs(requests)
            }
            
            store.execute(query)
            
        }
    }

    
    private func getRecordingMethod(_ sample: HKSample) -> String {
        var recordingMethod: String = "recording_method_unknown"
        if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
            recordingMethod = "recording_method_manual_entry"
        }
        return recordingMethod
    }
    
    private func createDeviceLog(_ isLocked: Bool) {
        let request = HealthLogRequest(UUID(), healthType: .device_lock, value: isLocked ? 1 : 0, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
        addPendingHealthLogs([request])
    }
    
    private func createSleepLogs(samples: [HKCategorySample]) {
        
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
        
        addPendingHealthLogs(requests)
    }
    
    private func createExerciseLogs(samples: [HKWorkout]) {
        
        var requests: [HealthLogRequest] = []
        for sample in samples {
            let sampleId = sample.uuid
            let sampleType = sample.workoutActivityType.name
            let unit = HealthTypeIdentifier.exercise.unitString
            let source = sample.sourceRevision.source.bundleIdentifier
            let recordingMethod = getRecordingMethod(sample)
            let deviceType = sample.sourceRevision.productType ?? "type_unknown"
                        
            // Add exercise session
            var request = HealthLogRequest(sampleId, logType: SahhaSensor.exercise.rawValue, dataType: "exercise_session_" + sampleType, value: 1, unit: unit, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: sample.startDate, endDate: sample.endDate)
            
            var additionalProperties: [String: String] = [:]
            
            if let distance = sample.totalDistance {
                let value = distance.doubleValue(for: .meter())
                additionalProperties["total_distance"] = "\(value)"
            }
            
            if let energy = sample.totalEnergyBurned {
                let value = energy.doubleValue(for: .largeCalorie())
                additionalProperties["total_energy_burned"] = "\(value)"
            }
            
            if additionalProperties.isEmpty == false {
                request.additionalProperties = additionalProperties
            }
            
            requests.append(request)
            
            // Add exercise events
            if let workoutEvents = sample.workoutEvents {
                for workoutEvent in workoutEvents {
                    let workoutEventType: String
                    switch workoutEvent.type {
                    case .pause:
                        workoutEventType = "exercise_event_pause"
                    case .resume:
                        workoutEventType = "exercise_event_resume"
                    case .lap:
                        workoutEventType = "exercise_event_lap"
                    case .marker:
                        workoutEventType = "exercise_event_marker"
                    case .motionPaused:
                        workoutEventType = "exercise_event_motion_paused"
                    case .motionResumed:
                        workoutEventType = "exercise_event_motion_resumed"
                    case .segment:
                        workoutEventType = "exercise_event_segment"
                    case .pauseOrResumeRequest:
                        workoutEventType = "exercise_event_pause_or_resume_request"
                    @unknown default:
                        workoutEventType = "exercise_event_unknown"
                    }
                    let request = HealthLogRequest(UUID(), logType: SahhaSensor.exercise.rawValue, dataType: workoutEventType, value: 1, unit: unit, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutEvent.dateInterval.start, endDate: workoutEvent.dateInterval.end, parentId: sampleId)
                    requests.append(request)
                }
            }
            
            // Add exercise segments
            if #available(iOS 16.0, *) {
                for workoutActivity in sample.workoutActivities {
                    let dataType = "exercise_segment_" + workoutActivity.workoutConfiguration.activityType.name
                    let endDate: Date = workoutActivity.endDate ?? workoutActivity.startDate + workoutActivity.duration
                    let request = HealthLogRequest(workoutActivity.uuid, logType: SahhaSensor.exercise.rawValue, dataType: dataType, value: 1, unit: unit, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutActivity.startDate, endDate: endDate, parentId: sampleId)
                    requests.append(request)
                }
            }
        }
        
        addPendingHealthLogs(requests)
    }
    
    private func createHealthLogs(healthType: HealthTypeIdentifier, samples: [HKQuantitySample]) {
        
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
        
        addPendingHealthLogs(requests)
    }
    
    private func addPendingHealthLogs(_ requests: [HealthLogRequest]) {
        
        healthLogRequests.insert(contentsOf: requests, at: 0)
        
        checkPendingHealthLogs()
    }
    
    private func checkPendingHealthLogs() {
        
        guard healthLogRequests.isEmpty == false else {
            return
        }

        let date = UserDefaults.standard.date(forKey: "SahhaSensorDataDate") ?? Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let hourDifference = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0
        // POST Sensor Logs if count > max || 1 hour has elapsed since last POST
        if healthLogRequests.count >= maxHealthLogRequestLimit || hourDifference >= 1  {
            postPendingHealthLogs()
        } else {
            saveHealthLogData()
        }
    }
    
    private func postPendingHealthLogs() {
        
        var requests: [HealthLogRequest] = []
        for _ in 0..<maxHealthLogRequestLimit {
            if let element = healthLogRequests.popLast() {
                requests.append(element)
            } else {
                break
            }
        }

        if requests.isEmpty == false {
            postHealthLogs(requests) { [weak self] _, success in
                if success {
                    self?.checkPendingHealthLogs()
                }
            }
        }
    }
    
    private func postHealthLogs(_ requests: [HealthLogRequest], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        UserDefaults.standard.set(date: Date(), forKey: "SahhaSensorDataDate")
        
        APIController.postHealthLog(body: requests) { [weak self] result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                self?.healthLogRequests.append(contentsOf: requests)
                callback(error.localizedDescription, false)
            }
        }
    }
}
