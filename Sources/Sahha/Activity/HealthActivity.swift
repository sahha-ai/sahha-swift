// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

public class HealthActivity {
    
    private let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private let store: HKHealthStore = HKHealthStore()
    private var maxHealthLogRequestLimit: Int = 64
    private var healthLogRequests: [DataLogRequest] = []
    private var enabledSensors: Set<SahhaSensor> = []
    
    private enum StatisticType: String {
        case total
        case average
        case minimum
        case maximum
        case most_recent
    }
    
    internal func configure() {
        
        print("Sahha | Health configure")
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceUnlock), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceLock), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        
        loadHealthLogData()
        enableBackgroundDelivery()
        monitorSensors()
    }
    
    internal func clearAllData() {
        for sensor in SahhaSensor.allCases {
            setAnchor(nil, sensor: sensor)
        }
        setInsightDate(nil)
    }
    
    internal func clearTestData() {
        setAnchor(nil, sensor: .active_energy_burned)
    }
    
    @objc fileprivate func onAppOpen() {
        postInsights()
    }
    
    @objc fileprivate func onAppClose() {
    }
    
    @objc fileprivate func onAppBackground() {
        getDemographic()
        postInsights()
    }
    
    @objc fileprivate func onDeviceUnlock() {
        createDeviceLog(false)
    }
    
    @objc fileprivate func onDeviceLock() {
        createDeviceLog(true)
    }
    
    fileprivate func setAnchor(_ anchor: HKQueryAnchor?, sensor: SahhaSensor) {
        guard let anchor = anchor else {
            UserDefaults.standard.removeObject(forKey: sensor.keyName)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: sensor.keyName)
        } catch {
            print("Sahha | Unable to set health anchor", sensor.keyName)
            Sahha.postError(message: "Unable to set health anchor", path: "HealthActivity", method: "setAnchor", body: sensor.keyName + " | " + anchor.debugDescription)
        }
    }
    
    fileprivate func getAnchor(sensor: SahhaSensor) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: sensor.keyName) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            print("Sahha | Unable to get health anchor", sensor.keyName)
            Sahha.postError(message: "Unable to get health anchor", path: "HealthActivity", method: "getAnchor", body: sensor.keyName)
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
                let request = try decoder.decode(DataLogRequest.self, from: data)
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
        var demographic = SahhaCredentials.getDemographic() ?? SahhaDemographic()
        
        if demographic.gender != nil, demographic.birthDate != nil {
            // We already have the latest value
            return
        }
        
        var genderString: String?
        var birthDateString: String?
        
        // Get the missing gender
        if demographic.gender == nil, enabledSensors.contains(.gender) {
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
        if demographic.birthDate == nil, enabledSensors.contains(.date_of_birth) {
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
    public func enableSensors(_ sensors: Set<SahhaSensor>, _ callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        var objectTypes: Set<HKObjectType> = []
        for healthType in sensors {
            if let objectType = healthType.objectType {
                objectTypes.insert(objectType)
            }
        }
        
        guard objectTypes.isEmpty == false else {
            callback("Sahha | Health data types not specified", .pending)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.store.requestAuthorization(toShare: [], read: objectTypes) { [weak self] success, error in
                DispatchQueue.main.async { [weak self] in
                    if let error = error {
                        print(error.localizedDescription)
                        Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "activate", body: "self?.store.requestAuthorization")
                        callback(error.localizedDescription, .pending)
                    } else {
                        if success {
                            // Monitor new sensors only
                            for sensor in sensors {
                                self?.monitorSensor(sensor)
                            }
                        }
                        self?.getSensorStatus(sensors) { error, status in
                            callback(error, status)
                        }
                    }
                }
            }
        }
    }
    
    internal func getSensorStatus(_ sensors: Set<SahhaSensor>, _ callback: ((String?, SahhaSensorStatus)->Void)? = nil) {
        
        guard isAvailable else {
            callback?(nil, .unavailable)
            return
        }
        
        var objectTypes: Set<HKObjectType> = []
        for sensor in sensors {
            if let objectType = sensor.objectType {
                objectTypes.insert(objectType)
            }
        }
        
        guard objectTypes.isEmpty == false else {
            callback?("Sahha | Health data types not specified", .pending)
            return
        }
        
        store.getRequestStatusForAuthorization(toShare: [], read: objectTypes) { status, error in
            
            var errorMessage: String? = nil
            let sensorStatus: SahhaSensorStatus
            
            if let error = error {
                sensorStatus = .pending
                errorMessage = error.localizedDescription
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "checkAuthorization", body: "store.getRequestStatusForAuthorization")
            } else {
                switch status {
                case .unnecessary:
                    sensorStatus = .enabled
                    
                default:
                    sensorStatus = .pending
                }
            }
            callback?(errorMessage, sensorStatus)
        }
    }
    
    private func enableBackgroundDelivery() {
        
        guard isAvailable else {
            return
        }
        
        for sensor in SahhaSensor.allCases {
            
            if let sampleType = sensor.objectType as? HKSampleType {
                
                store.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate) { [weak self] success, error in
                    if let error = error {
                        self?.filterError(error, path: "HealthActivity", method: "enableBackgroundDelivery", body: "self?.store.enableBackgroundDelivery")
                        return
                    } else {
                        self?.monitorSensor(sensor)
                    }
                }
            }
        }
    }
    
    private func monitorSensors() {
        
        guard isAvailable else {
            return
        }
        
        for sensor in SahhaSensor.allCases {
            monitorSensor(sensor)
        }
        
    }
    
    private func monitorSensor(_ sensor: SahhaSensor) {
        
        guard isAvailable else {
            return
        }
        
        // Only monitor the same sensor once
        if enabledSensors.contains(sensor) {
            return
        }
        
        if let objectType = sensor.objectType {
            
            store.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { [weak self] status, errorOrNil in
                
                if let error = errorOrNil {
                    print(error.localizedDescription)
                    Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "enableBackgroundDelivery", body: "store.getRequestStatusForAuthorization " + error.localizedDescription)
                    return
                }
                
                switch status {
                case .unnecessary:
                    if let sampleType = objectType as? HKSampleType {
                        // HKObserverQuery is the only query type that can run in the background - we then need to use HKAnchoredObjectQuery once the app is notified of a change to the HealthKit Store
                        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                            if let error = errorOrNil {
                                self?.filterError(error, path: "HealthActivity", method: "enableBackgroundDelivery", body: "let query = HKObserverQuery " + error.localizedDescription)
                            } else {
                                self?.postSensorData(sensor)
                            }
                            // If you have subscribed for background updates you must call the completion handler here
                            completionHandler()
                        }
                        // Keep track of monitored sensors
                        self?.enabledSensors.insert(sensor)
                        // Run the query
                        self?.store.execute(query)
                    } else {
                        // Sensor is not a sample type and cannot be monitored - add it automatically
                        self?.enabledSensors.insert(sensor)
                    }
                default:
                    break
                }
            }
        } else {
            // Sensor is not available in HealthKit - add it automatically
            enabledSensors.insert(sensor)
        }
    }
    
    internal func postSensorData(_ sensor: SahhaSensor) {
        
        guard isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        if let sampleType = sensor.objectType as? HKSampleType {
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
            let anchor = getAnchor(sensor: sensor)
            let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
                if let error = errorOrNil {
                    self?.filterError(error, path: "HealthActivity", method: "postSensorData", body: "let query = HKAnchoredObjectQuery")
                    return
                }
                guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                    return
                }
                                
                switch sensor.logType {
                case .sleep:
                    guard let categorySamples = samples as? [HKCategorySample] else {
                        print("Sahha | Sleep samples in incorrect format")
                        return
                    }
                    self?.setAnchor(newAnchor, sensor: sensor)
                    self?.createSleepLogs(samples: categorySamples)
                case .exercise:
                    guard let workoutSamples = samples as? [HKWorkout] else {
                        print("Sahha | Exercise samples in incorrect format")
                        return
                    }
                    self?.setAnchor(newAnchor, sensor: sensor)
                    self?.createExerciseLogs(samples: workoutSamples)
                default:
                    guard let quantitySamples = samples as? [HKQuantitySample] else {
                        print("Sahha | \(sensor.rawValue) samples in incorrect format")
                        return
                    }
                    self?.setAnchor(newAnchor, sensor: sensor)
                    self?.createHealthLogs(sensor: sensor, samples: quantitySamples)
                }
            }
            store.execute(query)
        }
    }
    
    internal func postInsights() {
        
        guard isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        store.getRequestStatusForAuthorization(toShare: [], read: [SahhaSensor.activity_summary.objectType!]) { [weak self] status, error in
            
            switch status {
            case .unnecessary:
                let today = Date()
                // Set startDate to a week prior if date is nil (first app launch)
                let startDate = self?.getInsightDate() ?? Calendar.current.date(byAdding: .day, value: -31, to: today) ?? today
                let endDate = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
                
                // Only check once per day
                if Calendar.current.isDateInToday(startDate) == false, today > startDate {
                    
                    // Prevent duplication
                    self?.setInsightDate(today)
                    
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
                        
                        var requests: [DataLogRequest] = []
                        
                        for activitySummary in result {
                                                        
                            let logType = SensorLogTypeIndentifier.energy
                            let date = activitySummary.dateComponents(for: Calendar.current).date ?? Date()
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_total, value: activitySummary.appleStandHours.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            
                            if #available(iOS 16.0, *), let value = activitySummary.standHoursGoal?.doubleValue(for: .count()) {
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            } else {
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: activitySummary.appleStandHoursGoal.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            }
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_total, value: activitySummary.appleMoveTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_goal, value: activitySummary.appleMoveTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_total, value: activitySummary.appleExerciseTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            
                            if #available(iOS 16.0, *), let value = activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) {
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            } else {
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            }
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_total, value: activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            
                            requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_goal, value: activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                        }
                        
                        self?.addPendingHealthLogs(requests)
                    }
                    
                    self?.store.execute(query)
                }
            default:
                return
            }
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
        
        guard enabledSensors.contains(.device_lock) else {
            return
        }
        
        let request = DataLogRequest(UUID(), sensor: .device_lock, value: isLocked ? 1 : 0, source: SahhaConfig.appId, recordingMethod: "recording_method_automatically_recorded", deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
        addPendingHealthLogs([request])
    }
    
    private func createSleepLogs(samples: [HKCategorySample]) {
        
        var requests: [DataLogRequest] = []
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
            
            let request = DataLogRequest(sample.uuid, sensor: .sleep, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
            requests.append(request)
        }
        
        addPendingHealthLogs(requests)
    }
    
    private func createExerciseLogs(samples: [HKWorkout]) {
        
        var requests: [DataLogRequest] = []
        for sample in samples {
            let sampleId = sample.uuid
            let sampleType = sample.workoutActivityType.name
            let source = sample.sourceRevision.source.bundleIdentifier
            let recordingMethod = getRecordingMethod(sample)
            let deviceType = sample.sourceRevision.productType ?? "type_unknown"
            
            // Add exercise session
            var request = DataLogRequest(sampleId, sensor: .exercise, dataType: "exercise_session_" + sampleType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: sample.startDate, endDate: sample.endDate)
            
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
                    let request = DataLogRequest(UUID(), sensor: .exercise, dataType: workoutEventType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutEvent.dateInterval.start, endDate: workoutEvent.dateInterval.end, parentId: sampleId)
                    requests.append(request)
                }
            }
            
            // Add exercise segments
            if #available(iOS 16.0, *) {
                for workoutActivity in sample.workoutActivities {
                    let dataType = "exercise_segment_" + workoutActivity.workoutConfiguration.activityType.name
                    let endDate: Date = workoutActivity.endDate ?? workoutActivity.startDate + workoutActivity.duration
                    let request = DataLogRequest(workoutActivity.uuid, sensor: .exercise, dataType: dataType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutActivity.startDate, endDate: endDate, parentId: sampleId)
                    requests.append(request)
                }
            }
        }
        
        addPendingHealthLogs(requests)
    }
    
    private func createHealthLogs(sensor: SahhaSensor, samples: [HKQuantitySample]) {
        
        var requests: [DataLogRequest] = []
        for sample in samples {
            
            let value: Double
            if let unit = sensor.unit {
                value = sample.quantity.doubleValue(for: unit)
            } else {
                value = 0
            }
            
            var request = DataLogRequest(sample.uuid, sensor: sensor, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
            
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
    
    private func addPendingHealthLogs(_ requests: [DataLogRequest]) {
        
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
        
        var requests: [DataLogRequest] = []
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
    
    private func postHealthLogs(_ requests: [DataLogRequest], callback: @escaping (_ error: String?, _ success: Bool)-> Void) {
        
        UserDefaults.standard.set(date: Date(), forKey: "SahhaSensorDataDate")
        
        APIController.postDataLog(body: requests) { [weak self] result in
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
