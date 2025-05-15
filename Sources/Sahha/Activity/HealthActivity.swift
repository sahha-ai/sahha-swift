// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

fileprivate actor DataManager {
    
    private let maxDataLogRequestLimit: Int = 100
    private var dataLogs: [DataLogRequest] = []
    private var enabledSensors: Set<SahhaSensor> = []
    private var observedSensors: Set<SahhaSensor> = []
//    private var queriedSensors: Set<SahhaSensor> = [] {
//        didSet {
//            if dataLogs.count >= maxDataLogRequestLimit {
//                startPostingDataLogs()
//            }
//        }
//    }
    
    func clearData() {
        dataLogs = []
        saveDataLogs()
    }
    
    func loadData() {
        print("[DataManager] Loading saved dataLogs")
        dataLogs = loadDataLogs()
        print("[DataManager] Loaded \(dataLogs.count) saved logs")
    }
    
    func isEmpty() -> Bool {
        return dataLogs.isEmpty
    }
    
    func addDataLogs(_ logs: [DataLogRequest]) {
        guard logs.isEmpty == false else { return }
        
        print("[DataManager] Adding \(logs.count) logs (no sensor specified)")
        
        dataLogs.append(contentsOf: logs)
        tryStartPostingIfReady()
    }
    
    func addDataLogs(_ logs: [DataLogRequest], sensor: SahhaSensor) {
        guard logs.isEmpty == false else { return }
        
        print("[DataManager] Adding \(logs.count) logs for sensor: \(sensor)")
        dataLogs.append(contentsOf: logs)
        
//        if queriedSensors.contains(sensor) {
//            queriedSensors.remove(sensor)
//            print("[DataManager] Removed \(sensor) from queriedSensors")
//        }
        
        tryStartPostingIfReady()
    }
    
    private func tryStartPostingIfReady() {
        print("[DataManager] Checking if ready to post logs...")
        if dataLogs.count >= maxDataLogRequestLimit {
            print("[DataManager] Conditions met. Starting to post logs.")
            startPostingDataLogs()
        } else {
            print("[DataManager] Not enough logs yet (\(dataLogs.count)/\(maxDataLogRequestLimit)), or sensors still being queried")
        }
    }
    
    private func saveDataLogs(_ logs: [DataLogRequest] = []) {
        if logs.isEmpty == false {
            dataLogs.append(contentsOf: logs)
        }
        
        let encoder = JSONEncoder()
        let encodedDataLogs: [Data] = dataLogs.compactMap { try? encoder.encode($0) }
        UserDefaults.standard.setValue(encodedDataLogs, forKey: "SahhaDataLogs")
        print("[DataManager] Saved \(dataLogs.count) logs to UserDefaults")
    }
    
    private func loadDataLogs() -> [DataLogRequest] {
        let encodedDataLogs = UserDefaults.standard.array(forKey: "SahhaDataLogs") as? [Data] ?? []
        let decoder = JSONDecoder()
        let decoded = encodedDataLogs.compactMap { try? decoder.decode(DataLogRequest.self, from: $0) }
        print("[DataManager] Decoded \(decoded.count) logs from UserDefaults")
        return decoded
    }
    
    private func startPostingDataLogs() {
        print("[DataManager] Starting to post pending data logs")
        postPendingDataLogs()
    }
    
    private func postPendingDataLogs() {
        guard dataLogs.count >= maxDataLogRequestLimit else {
            print("[DataManager] Not enough logs to post. Current count: \(dataLogs.count)")
            return
        }
        
        let dataLogRequests: [DataLogRequest] = Array(dataLogs.prefix(maxDataLogRequestLimit))
        print("[DataManager] Preparing to post batch of \(dataLogRequests.count) logs")
        postDataLogs(dataLogRequests)
    }
    
    private func postDataLogs(_ requests: [DataLogRequest]) {
        guard dataLogs.count >= maxDataLogRequestLimit else {
            print("[DataManager] Skipped postDataLogs: not enough logs")
            return
        }
        
        let batch: [DataLogRequest] = Array(dataLogs.prefix(maxDataLogRequestLimit))
        print("[DataManager] Posting batch of \(batch.count) logs")
        
        postBatchWithRetry(batch) {
            Task {
                // Remove only after successful post
                print("[DataManager] Batch succeeded, removing from in-memory log list")
                self.dataLogs.removeFirst(batch.count)
                self.saveDataLogs()
                self.postPendingDataLogs() // Continue with next batch if available
            }
        }
    }
    
    private func postBatchWithRetry(
        _ batch: [DataLogRequest],
        retryCount: Int = 0,
        onSuccess: @escaping () -> Void
    ) {
        print("[PostBatch] Attempting to post batch (retry: \(retryCount))")
        
        APIController.postDataLog(body: batch) { result in
            switch result {
            case .success:
                print("[PostBatch] Batch post succeeded")
                onSuccess()
            case .failure:
                // Calculate delay based on retry count
                let delay: UInt64
                if retryCount == 0 {
                    delay = 5 * 1_000_000_000  // 5 seconds
                } else if retryCount == 1 {
                    delay = 30 * 1_000_000_000  // 30 seconds
                } else {
                    delay = 60 * 1_000_000_000  // 60 seconds indefinitely
                }
                
                print("[PostBatch] Batch post failed. Retrying in \(delay / 1_000_000_000) seconds")
                
                Task {
                    try? await Task.sleep(nanoseconds: delay)
                    self.postBatchWithRetry(batch, retryCount: retryCount + 1, onSuccess: onSuccess)
                }
            }
        }
    }
    
    func containsSensor(_ sensor: SahhaSensor) -> Bool {
        return enabledSensors.contains(sensor)
    }
    
    func enableSensor(_ sensor: SahhaSensor) {
        enabledSensors.insert(sensor)
    }
    
    func observeSensor(_ sensor: SahhaSensor) {
        enabledSensors.insert(sensor)
        observedSensors.insert(sensor)
    }
    
    func observesSensor(_ sensor: SahhaSensor) -> Bool {
        return observedSensors.contains(sensor)
    }
    
    func querySensor(_ sensor: SahhaSensor) {
//        queriedSensors.insert(sensor)
    }
}

fileprivate enum AppLogType: String {
    case app_create
    case app_start
    case app_resume
    case app_pause
    case app_foreground
    case app_background
    case app_destroy
    case app_locked
}

fileprivate func setAnchorDate(_ date: Date?, sensor: SahhaSensor) {
    UserDefaults.standard.set(date: date, forKey: "date_" + sensor.keyName)
}

fileprivate func getAnchorDate(sensor: SahhaSensor) -> Date? {
    UserDefaults.standard.date(forKey: "date_" + sensor.keyName)
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

fileprivate func getRecordingMethod(_ sample: HKSample) -> RecordingMethodIdentifier {
    var recordingMethod: RecordingMethodIdentifier = .unknown
    if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
        recordingMethod = .manual_entry
    }
    return recordingMethod
}

internal class HealthActivity {
    
    private static let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private static let store: HKHealthStore = HKHealthStore()
    private static let dataManager = DataManager()
    
    private enum StatisticType: String {
        case total
        case average
        case minimum
        case maximum
        case most_recent
    }
    
    init() {
        Task {
            await Self.dataManager.loadData()
            onAppCreate()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppStart), name: UIApplication.didFinishLaunchingNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppResume), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppPause), name: UIApplication.willResignActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppDestroy), name: UIApplication.willTerminateNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceUnlock), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDeviceLock), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
    }
    
    @objc fileprivate func onAppCreate() {
        createAppLog(.app_create)
    }
    
    @objc fileprivate func onAppStart() {
        createAppLog(.app_start)
    }
    
    @objc fileprivate func onAppResume() {
        createAppLog(.app_resume)
        postInsights()
        getDemographic()
    }
    
    @objc fileprivate func onAppPause() {
        createAppLog(.app_pause)
    }
    
    @objc fileprivate func onAppForeground() {
        createAppLog(.app_foreground)
    }
    
    @objc fileprivate func onAppBackground() {
        createAppLog(.app_background)
    }
    
    @objc fileprivate func onAppDestroy() {
        createAppLog(.app_destroy)
    }
    
    @objc fileprivate func onDeviceUnlock() {
        createDeviceLog(false)
    }
    
    @objc fileprivate func onDeviceLock() {
        createDeviceLog(true)
    }
    
    func clearData() {
        for sensor in SahhaSensor.allCases {
            setAnchorDate(nil, sensor: sensor)
            setAnchor(nil, sensor: sensor)
        }
        clearDeferredHeartRateLogs();
        Task {
            await Self.dataManager.clearData()
        }
    }
    
    internal func configure() {
        
        observeSensors()
        enableBackgroundDelivery()
        
        print("Sahha | Health configured")
    }
    
    private func filterError(_ error: Error, path: String, method: String, body: String) {
        print(error.localizedDescription)
        if let healthError = error as? HKError, healthError.code == HKError.Code.errorDatabaseInaccessible {
            // The device is currently locked so data is inaccessible
            // This should be considered a warning instead of an error
            // Avoid sending an error message
            createAppLog(.app_locked)
        } else {
            Sahha.postError(message: error.localizedDescription, path: path, method: method, body: body)
        }
    }
    
    func getDemographic() {
        
        guard Self.isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        Task {
            
            // Create an empty object
            var demographic = SahhaCredentials.getDemographic() ?? SahhaDemographic()
            
            if demographic.gender != nil, demographic.birthDate != nil {
                // We already have the latest value
                return
            }
            
            var genderString: String?
            var birthDateString: String?
            
            do {
                // Get the missing gender
                if demographic.gender == nil, await Self.dataManager.containsSensor(.gender) {
                    // Get the HealthKit gender
                    let gender = try Self.store.biologicalSex()
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
                }
            } catch let error {
                filterError(error, path: "HealthActivity", method: "getDemographic", body: "let gender = try store.biologicalSex()")
            }
            
            do {
                // Get the missing birth date
                if demographic.birthDate == nil, await Self.dataManager.containsSensor(.date_of_birth) {
                    // Get the HealthKit birth date
                    let dateOfBirth = try Self.store.dateOfBirthComponents()
                    if let dateString = dateOfBirth.date?.toYYYYMMDD, dateString.isEmpty == false {
                        birthDateString = dateString
                    }
                }
            } catch let error {
                filterError(error, path: "HealthActivity", method: "getDemographic", body: "let dateOfBirth = try store.dateOfBirthComponents()")
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
    }
    
    /// Activate Health - callback with TRUE or FALSE for success
    internal func enableSensors(_ sensors: Set<SahhaSensor>, _ callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        guard Self.isAvailable else {
            callback(nil, .unavailable)
            return
        }
        
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
        
        Self.store.requestAuthorization(toShare: [], read: objectTypes) { [weak self] success, error in
            if let error = error {
                print(error.localizedDescription)
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "activate", body: "store.requestAuthorization")
                callback(error.localizedDescription, .pending)
            } else {
                if success {
                    // Observe new sensors only
                    for sensor in sensors {
                        self?.observeSensor(sensor)
                    }
                }
                self?.getSensorStatus(sensors) { error, status in
                    callback(error, status)
                }
            }
        }
    }
    
    internal func getSensorStatus(_ sensors: Set<SahhaSensor>, _ callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        guard Self.isAvailable else {
            callback(nil, .unavailable)
            return
        }
        
        var objectTypes: Set<HKObjectType> = []
        for sensor in sensors {
            if let objectType = sensor.objectType {
                objectTypes.insert(objectType)
            }
        }
        
        guard objectTypes.isEmpty == false else {
            callback("Sahha | Health data types not specified", .pending)
            return
        }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: objectTypes) { status, error in
            
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
            callback(errorMessage, sensorStatus)
        }
    }
    
    private func enableBackgroundDelivery() {
        
        guard Self.isAvailable else {
            return
        }
        
        for sensor in SahhaSensor.allCases {
            
            if let sampleType = sensor.objectType as? HKSampleType {
                
                Self.store.enableBackgroundDelivery(for: sampleType, frequency: HKUpdateFrequency.immediate) { [weak self] _, error in
                    if let error = error {
                        self?.filterError(error, path: "HealthActivity", method: "enableBackgroundDelivery", body: "self?.store.enableBackgroundDelivery")
                    }
                }
            }
        }
    }
    
    private func observeSensors() {
        
        guard Self.isAvailable else {
            return
        }
        
        for sensor in SahhaSensor.allCases {
            observeSensor(sensor)
        }
        
    }
    
    private func observeSensor(_ sensor: SahhaSensor) {
        
        guard Self.isAvailable else {
            return
        }
        
        if let objectType = sensor.objectType {
            
            Self.store.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { [weak self] status, errorOrNil in
                
                if let error = errorOrNil {
                    print(error.localizedDescription)
                    Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "monitorSensor", body: "store.getRequestStatusForAuthorization " + error.localizedDescription)
                    return
                }
                
                switch status {
                case .unnecessary:
                    if let sampleType = objectType as? HKSampleType {
                        // HKObserverQuery is the only query type that can run in the background - we then need to use HKAnchoredObjectQuery once the app is notified of a change to the HealthKit Store
                        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] (query, completionHandler, errorOrNil) in
                            if let error = errorOrNil {
                                self?.filterError(error, path: "HealthActivity", method: "monitorSensor", body: "let query = HKObserverQuery " + error.localizedDescription)
                            } else {
                                self?.querySensor(sensor)
                            }
                            // If you have subscribed for background updates you must call the completion handler here
                            completionHandler()
                        }
                        Task {
                            if await Self.dataManager.observesSensor(sensor) {
                                // do nothing
                            } else {
                                // Keep track of monitored sensors
                                await Self.dataManager.observeSensor(sensor)
                                // Run the query
                                Self.store.execute(query)
                            }
                        }
                    } else {
                        Task {
                            // Sensor is not a sample type and cannot be monitored - add it automatically
                            await Self.dataManager.enableSensor(sensor)
                        }
                    }
                default:
                    break
                }
            }
        } else {
            Task {
                // Sensor is not available in HealthKit - add it automatically
                await Self.dataManager.enableSensor(sensor)
            }
        }
    }
    
    internal func querySensors() {
        guard Self.isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        for sensor in SahhaSensor.allCases {
            querySensor(sensor)
        }
    }
    
    private func postBatchWithRetry(
        _ batch: [DataLogRequest],
        retryCount: Int = 0,
        onSuccess: @escaping () -> Void
    ) {
        print("[PostBatch] Attempting to post batch (retry: \(retryCount))")
        
        APIController.postDataLog(body: batch) { result in
            switch result {
            case .success:
                print("[PostBatch] Batch post succeeded")
                onSuccess()
            case .failure:
                // Calculate delay based on retry count
                let delay: UInt64
                if retryCount == 0 {
                    delay = 5 * 1_000_000_000  // 5 seconds
                } else if retryCount == 1 {
                    delay = 30 * 1_000_000_000  // 30 seconds
                } else {
                    delay = 60 * 1_000_000_000  // 60 seconds indefinitely
                }
                
                print("[PostBatch] Batch post failed. Retrying in \(delay / 1_000_000_000) seconds")
                
                Task {
                    try? await Task.sleep(nanoseconds: delay)
                    self.postBatchWithRetry(batch, retryCount: retryCount + 1, onSuccess: onSuccess)
                }
            }
        }
    }
    
    private func querySensor(_ sensor: SahhaSensor) {
        guard Self.isAvailable, Sahha.isAuthenticated else { return }
        guard sensor != .heart_rate else { return }
        //        guard sensor != .heart_rate else { return self.queryRateHeart(); }
        guard let sampleType = sensor.objectType as? HKSampleType else { return }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: [sampleType]) { [weak self] status, _ in
            guard status == .unnecessary else { return }
            guard let self = self else { return }
            
            let startDate = getAnchorDate(sensor: sensor) ?? Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let endDate = Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: HKQueryOptions.strictEndDate)
            let anchor = getAnchor(sensor: sensor)
            
//            print("[\(sensor.keyName)] Querying samples from \(startDate) to \(endDate)")
            
            let limit = 100;
            
            func executeBatch(from anchor: HKQueryAnchor?) {
                let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: limit) { _, samplesOrNil, _, newAnchorOrNil, errorOrNil in
                    if let error = errorOrNil {
                        self.filterError(error, path: "HealthActivity", method: "querySensor", body: sensor.keyName)
                        return
                    }
                    
                    guard let newAnchor = newAnchorOrNil, let samples = samplesOrNil, !samples.isEmpty else {
//                        print("[\(sensor.keyName)] No samples found, returning early")
                        return
                    }
                    
                    let latestSampleEnd = samples.map(\.endDate).max()
//                    print("[\(sensor.keyName)] Fetched \(samples.count) raw samples")
                    
                    var requests: [DataLogRequest] = []
                    
                    for sample in samples {
                        let sampleId = sample.uuid
                        let source = sample.sourceRevision.source.bundleIdentifier
                        let recordingMethod = getRecordingMethod(sample)
                        let deviceType: String = sample.sourceRevision.productType ?? "unknown"
                        let startDate: Date = sample.startDate
                        let endDate: Date = sample.endDate
                        
                        
                        switch sensor.logType {
                        case .sleep:
                            guard let sleepSample = sample as? HKCategorySample else { continue }
                            
//                            print("[\(sensor.keyName)] Adding sleep sample")
                            
                            let sleepStage: SleepStage = Self.getSleepStage(sample: sleepSample)
                            let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
                            let value = Double(difference.minute ?? 0)
                            
                            let request = DataLogRequest(sampleId, sensor: .sleep, dataType: sleepStage.rawValue, value: value, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate)
                            
                            requests.append(request)
                            
                        case .exercise:
                            guard let exerciseSample = sample as? HKWorkout else { continue }
                            
//                            print("[\(sensor.keyName)] Adding exercise sample")
                            
                            let dataType = "exercise_session_" + exerciseSample.workoutActivityType.name
                            
                            var request = DataLogRequest(sampleId, sensor: .exercise, dataType: dataType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate)
                            
                            var additionalProperties: [String: String] = [:]
                            
                            if let distance = exerciseSample.totalDistance {
                                let value = distance.doubleValue(for: .meter())
                                additionalProperties["total_distance"] = "\(value)"
                            }
                            
                            if let energy = exerciseSample.totalEnergyBurned {
                                let value = energy.doubleValue(for: .largeCalorie())
                                additionalProperties["total_energy_burned"] = "\(value)"
                            }
                            
                            if !additionalProperties.isEmpty {
                                request.additionalProperties = additionalProperties
                            }
                            
                            requests.append(request)
                            
                        default:
                            guard let quantitySample = sample as? HKQuantitySample else { continue }
                            
//                            print("[\(sensor.keyName)] Adding health sample")
                            
                            let value = sensor.unit.map { quantitySample.quantity.doubleValue(for: $0) } ?? 0
                            
                            var request = DataLogRequest(sampleId, sensor: sensor, value: value, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: startDate, endDate: endDate)
                            
                            var additionalProperties: [String: String] = [:]
                            
                            if let metaValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber,
                               let metaEnumValue = HKHeartRateSensorLocation(rawValue: metaValue.intValue) {
                                additionalProperties[DataLogPropertyIdentifier.measurementLocation.rawValue] = {
                                    switch metaEnumValue {
                                    case .chest: return "chest"
                                    case .earLobe: return "ear_lobe"
                                    case .finger: return "finger"
                                    case .foot: return "foot"
                                    case .hand: return "hand"
                                    case .wrist: return "wrist"
                                    case .other: return "other"
                                    @unknown default: return "unknown"
                                    }
                                }()
                            }
                            
                            if let metaValue = sample.metadata?[HKMetadataKeyVO2MaxTestType] as? NSNumber,
                               let metaEnumValue = HKVO2MaxTestType(rawValue: metaValue.intValue) {
                                additionalProperties[DataLogPropertyIdentifier.measurementMethod.rawValue] = {
                                    switch metaEnumValue {
                                    case .maxExercise: return "max_exercise"
                                    case .predictionNonExercise: return "prediction_non_exercise"
                                    case .predictionSubMaxExercise: return "prediction_sub_max_exercise"
                                    @unknown default: return "unknown"
                                    }
                                }()
                            }
                            
                            if let metaValue = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber,
                               let metaEnumValue = HKHeartRateMotionContext(rawValue: metaValue.intValue) {
                                additionalProperties[DataLogPropertyIdentifier.motionContext.rawValue] = {
                                    switch metaEnumValue {
                                    case .notSet: return "not_set"
                                    case .sedentary: return "sedentary"
                                    case .active: return "active"
                                    @unknown default: return "unknown"
                                    }
                                }()
                            }
                            
                            if let metaValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber,
                               let metaEnumValue = HKBloodGlucoseMealTime(rawValue: metaValue.intValue) {
                                additionalProperties[DataLogPropertyIdentifier.relationToMeal.rawValue] = {
                                    switch metaEnumValue {
                                    case .preprandial: return BloodRelationToMeal.before_meal.rawValue
                                    case .postprandial: return BloodRelationToMeal.after_meal.rawValue
                                    default: return BloodRelationToMeal.unknown.rawValue
                                    }
                                }()
                            }
                            
                            if !additionalProperties.isEmpty {
                                request.additionalProperties = additionalProperties
                            }
                            
                            requests.append(request)
                        }
                    }
                    
//                    print("[\(sensor.keyName)] Adding \(requests.count) requests to data store")
                    
                    Task {
                        await Self.dataManager.addDataLogs(requests, sensor: sensor)
                    }
                    
                    setAnchor(newAnchor, sensor: sensor)
                    setAnchorDate(latestSampleEnd, sensor: sensor)
                    executeBatch(from: newAnchor)
                }
                
                Self.store.execute(query)
            }
            
            executeBatch(from: anchor)
        }
    }
    
    private let deferredLogsKey = "deferred_heart_rate_logs"
    
    private func saveDeferredHeartRateLogs(_ logs: [DataLogRequest]) {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: deferredLogsKey)
            print("[HeartRate] Saved \(logs.count) deferred logs to UserDefaults")
        }
    }
    
    private func loadDeferredHeartRateLogs() -> [DataLogRequest] {
        guard let data = UserDefaults.standard.data(forKey: deferredLogsKey),
              let logs = try? JSONDecoder().decode([DataLogRequest].self, from: data) else {
            print("[HeartRate] No deferred logs found in UserDefaults")
            return []
        }
        UserDefaults.standard.removeObject(forKey: deferredLogsKey)
        print("[HeartRate] Loaded \(logs.count) deferred logs from UserDefaults")
        return logs
    }
    
    private func clearDeferredHeartRateLogs() {
        UserDefaults.standard.removeObject(forKey: deferredLogsKey)
        print("[HeartRate] Cleared deferred heart rate logs from UserDefaults")
    }
    
    private func queryRateHeart() {
        guard Self.isAvailable, Sahha.isAuthenticated else { return }
        let sensor: SahhaSensor = .heart_rate
        guard let sampleType = sensor.objectType as? HKQuantityType else { return }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: [sampleType]) { [weak self] status, _ in
            guard status == .unnecessary, let self = self else { return }
            
            let anchor = getAnchor(sensor: sensor)
            let startDate = getAnchorDate(sensor: sensor) ?? Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            let now = Date()
            let endDate = Calendar.current.date(bySetting: .second, value: 0, of: now)!
            let minuteComponent = Calendar.current.component(.minute, from: endDate)
            let roundedMinute = (minuteComponent / 5) * 5
            let roundedEndDate = Calendar.current.date(bySetting: .minute, value: roundedMinute, of: endDate)!.addingTimeInterval(-0.001)
            
            print("[HeartRate] Querying samples from \(startDate) to \(roundedEndDate)")
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: roundedEndDate, options: .strictEndDate)
            let batchSize = 100;
            let limit = 50_000
            
            let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: limit) { _, samplesOrNil, _, newAnchorOrNil, errorOrNil in
                guard let newAnchor = newAnchorOrNil else { return }
                
                if let error = errorOrNil {
                    self.filterError(error, path: "HealthActivity", method: "heartRateQuery", body: "anchor query")
                    return
                }
                
                guard let samples = samplesOrNil as? [HKQuantitySample], !samples.isEmpty else {
                    print("[HeartRate] No samples found, returning early")
                    return
                }
                
                let latestSampleEnd = samples.map(\.endDate).max()
                print("[HeartRate] Fetched \(samples.count) raw samples")
                
                let aggregates = self.aggregateHeartRate(samples, upTo: roundedEndDate, sensor: sensor)
                let deferredLogs = self.loadDeferredHeartRateLogs()
                let totalLogs = deferredLogs + aggregates
                
                print("[HeartRate] Aggregated \(aggregates.count) logs (+ \(deferredLogs.count) deferred = \(totalLogs.count))")
                
                guard totalLogs.count >= batchSize else {
                    print("[HeartRate] Less than 100 logs total. Deferring \(totalLogs.count) logs.")
                    self.saveDeferredHeartRateLogs(totalLogs)
                    setAnchor(newAnchor, sensor: sensor)
                    setAnchorDate(latestSampleEnd, sensor: sensor)
                    self.queryRateHeart()
                    return
                }
                
                var batches: [[DataLogRequest]] = stride(from: 0, to: totalLogs.count, by: batchSize).map {
                    Array(totalLogs[$0..<min($0 + batchSize, totalLogs.count)])
                }
                
                if let last = batches.last, last.count < batchSize {
                    print("[HeartRate] Final batch is partial (\(last.count)). Deferring instead of posting.")
                    self.saveDeferredHeartRateLogs(last)
                    batches.removeLast()
                }
                
                func postNextBatch(index: Int) {
                    guard index < batches.count else {
                        print("[HeartRate] All full batches posted.")
                        setAnchor(newAnchor, sensor: sensor)
                        setAnchorDate(latestSampleEnd, sensor: sensor)
                        self.queryRateHeart()
                        return
                    }
                    
                    let batch = batches[index]
                    self.postBatchWithRetry(batch) {
                        print("[HeartRate] Posted batch \(index + 1) (\(batch.count) logs)")
                        postNextBatch(index: index + 1)
                    }
                }
                
                postNextBatch(index: 0)
            }
            
            Self.store.execute(query)
        }
    }
    
    private func aggregateHeartRate(_ samples: [HKQuantitySample], upTo endDate: Date, sensor: SahhaSensor) -> [DataLogRequest] {
        let samplesInRange = samples.filter { $0.startDate < endDate }
        
        // Threshold for long samples: >10 seconds
        let longSamples = samplesInRange.filter { $0.endDate.timeIntervalSince($0.startDate) > 10 }
        let shortSamples = samplesInRange.filter { $0.endDate.timeIntervalSince($0.startDate) <= 10 }
        
        // Group short samples into 5-min buckets
        let grouped = Dictionary(grouping: shortSamples) { sample -> Date in
            let interval = 5 * 60
            let time = Int(sample.startDate.timeIntervalSince1970)
            let bucket = time - (time % interval)
            return Date(timeIntervalSince1970: TimeInterval(bucket))
        }
        
        var logs: [DataLogRequest] = []
        
        for sample in longSamples {
            let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let sampleId = sample.uuid
            let source = sample.sourceRevision.source.bundleIdentifier
            let recordingMethod = getRecordingMethod(sample)
            let deviceType = sample.sourceRevision.productType ?? "unknown"
            
            logs.append(DataLogRequest(
                sampleId,
                sensor: sensor,
                value: value,
                source: source,
                recordingMethod: recordingMethod,
                deviceType: deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            ))
        }
        
        for (windowStart, windowSamples) in grouped {
            guard !windowSamples.isEmpty else { continue }
            
            let values = windowSamples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
            guard !values.isEmpty else { continue }
            
            let avg = values.reduce(0, +) / Double(values.count)
            let windowEnd = windowStart.addingTimeInterval(5 * 60 - 0.001)
            if windowEnd > endDate { continue }
            
            let sampleId = windowSamples.last?.uuid ?? UUID()
            let source = windowSamples.last?.sourceRevision.source.bundleIdentifier ?? "unknown"
            let recordingMethod = getRecordingMethod(windowSamples.last!)
            let deviceType = windowSamples.last?.sourceRevision.productType ?? "unknown"
            
            logs.append(DataLogRequest(
                sampleId,
                sensor: sensor,
                value: avg,
                source: source,
                recordingMethod: recordingMethod,
                deviceType: deviceType,
                startDate: windowStart,
                endDate: windowEnd
            ))
        }
        
        print("[HeartRate] Created \(logs.count) aggregate logs from \(samplesInRange.count) samples (\(longSamples.count) were pre-aggregated and logged directly)")
        return logs.sorted { (a: DataLogRequest, b: DataLogRequest) in a.startDateTime < b.startDateTime }
    }
    
    internal func postInsights() {
        
        guard Self.isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: [SahhaSensor.activity_summary.objectType!]) { status, error in
            
            switch status {
            case .unnecessary:
                let today = Date()
                // Set startDate to a week prior if date is nil (first app launch)
                let startDate = getAnchorDate(sensor: .activity_summary) ?? Calendar.current.date(byAdding: .day, value: -31, to: today) ?? today
                let endDate = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
                
                // Only check once per day
                if Calendar.current.isDateInToday(startDate) == false, today > startDate {
                    
                    // Prevent duplication
                    setAnchorDate(today, sensor: .activity_summary)
                    
                    let startComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: startDate)
                    let endComponents = Calendar.current.dateComponents([.day, .month, .year, .calendar], from: endDate)
                    
                    let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
                    
                    let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] query, result, error in
                        
                        if let error = error {
                            // Reset insight date
                            setAnchorDate(startDate, sensor: .activity_summary)
                            self?.filterError(error, path: "HealthActivity", method: "getActivitySummary", body: "")
                            Task {
                                await Self.dataManager.querySensor(.activity_summary)
                            }
                            return
                        }
                        
                        guard let result = result, !result.isEmpty else {
                            print("Sahha | Health Activity Summary is empty")
                            Task {
                                await Self.dataManager.querySensor(.activity_summary)
                            }
                            return
                        }
                        
                        Task {
                            
                            var requests: [DataLogRequest] = []
                            
                            for activitySummary in result {
                                
                                let logType = SensorLogTypeIndentifier.energy
                                let date = activitySummary.dateComponents(for: Calendar.current).date ?? Date()
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_total, value: activitySummary.appleStandHours.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                if #available(iOS 16.0, *), let value = activitySummary.standHoursGoal?.doubleValue(for: .count()) {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                } else {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: activitySummary.appleStandHoursGoal.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                }
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_total, value: activitySummary.appleMoveTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_goal, value: activitySummary.appleMoveTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_total, value: activitySummary.appleExerciseTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                if #available(iOS 16.0, *), let value = activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                } else {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                }
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_total, value: activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_goal, value: activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            }
                            
                            await Self.dataManager.addDataLogs(requests, sensor: .activity_summary)
                        }
                    }
                    
                    Task {
                        await Self.dataManager.querySensor(.activity_summary)
                    }
                    
                    Self.store.execute(query)
                }
            default:
                return
            }
        }
        
    }
    
    private static func createSahhaStat(from stat: HKStatistics, quantityType: HKQuantityType, sensor: SahhaSensor, periodicity: PeriodicityIdentifier) -> SahhaStat? {
        var quantity: HKQuantity?
        let aggregation: AggregationIdentifier
        switch quantityType.aggregationStyle {
        case .cumulative:
            quantity = stat.sumQuantity()
            aggregation = .sum
        case .discrete, .discreteArithmetic, .discreteTemporallyWeighted:
            quantity = stat.averageQuantity()
            aggregation = .avg
        default:
            aggregation = .sum
            break
        }
        if let quantity = quantity, let unit: HKUnit = sensor.unit {
            let value: Double = quantity.doubleValue(for: unit)
            var sources: [String] = []
            for source in stat.sources ?? [] {
                sources.append(source.bundleIdentifier)
            }
            let stat = SahhaStat(id: UUID().uuidString, category: sensor.category.rawValue, type: sensor.rawValue, aggregation: aggregation.rawValue, periodicity: periodicity.rawValue, value: value, unit: sensor.unitString, startDateTime: stat.startDate, endDateTime: stat.endDate, sources: sources)
            return stat
        }
        return nil
    }
    
    internal func getStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (_ error: String?, _ stats: [SahhaStat])->Void)  {
        
        guard Self.isAvailable else {
            callback("Health data is not available on this device", [])
            return
        }
        
        guard let objectType = sensor.objectType else {
            callback("Stats are not available for \(sensor.keyName)", [])
            return
        }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { [weak self] status, error in
            
            switch status {
            case .unnecessary:
                
                switch sensor {
                case .sleep:
                    self?.getSleepStats(startDateTime: startDateTime, endDateTime: endDateTime, periodicity: .daily, callback: callback)
                case .exercise:
                    self?.getExerciseStats(startDateTime: startDateTime, endDateTime: endDateTime, callback: callback)
                default:
                    self?.getQuantityStats(sensor: sensor, startDateTime: startDateTime, endDateTime: endDateTime, periodicity: .daily, callback: callback)
                }
                
            default:
                callback("User permission is not granted for \(sensor.keyName)", [])
                return
            }
        }
    }
    
    private func getSleepStats(startDateTime: Date, endDateTime: Date, periodicity: PeriodicityIdentifier, callback: @escaping (_ error: String?, _ stats: [SahhaStat])->Void)  {
        
        guard Self.isAvailable else {
            callback("Health data is not available on this device", [])
            return
        }
        
        var start = Calendar.current.date(byAdding: .day, value: -1, to: startDateTime) ?? startDateTime
        start = Calendar.current.startOfDay(for: start)
        start = Calendar.current.date(bySetting: .hour, value: 18, of: start) ?? start
        var end = Calendar.current.startOfDay(for: endDateTime)
        end = Calendar.current.date(bySetting: .hour, value: 18, of: end) ?? end
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQuery(sampleType: HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { sampleQuery, samplesOrNil, error in
            if let error = error {
                print(error.localizedDescription)
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "getSleepStats", body: "")
                callback(error.localizedDescription, [])
                return
            }
            guard let samples = samplesOrNil as? [HKCategorySample], samples.isEmpty == false else {
                callback("No stats were found for the given date range for sleep", [])
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
            
            var stats: [SahhaStat] = []
            let duration: Double
            switch periodicity {
            case .hourly:
                duration = 3600.0
            case .daily:
                duration = 86400.0
            }
            var rollingInterval = DateInterval(start: start, duration: duration)
            while rollingInterval.end <= end {
                
                typealias SleepSegment = Dictionary<String, Double>
                var sleepStats: Dictionary<SleepAggregate, SleepSegment> = [:]
                
                func insertSleepSegment(sleepAggregate: SleepAggregate, source: String, value: Double) {
                    if let sleepSegments = sleepStats[sleepAggregate] {
                        var  newSleepSegments = sleepSegments
                        if let oldValue = newSleepSegments[source] {
                            newSleepSegments[source] = oldValue + value
                        } else {
                            newSleepSegments[source] = value
                        }
                        sleepStats[sleepAggregate] = newSleepSegments
                    } else {
                        sleepStats[sleepAggregate] = [source: value]
                    }
                }
                
                for sample in samples {
                    if let sleepSample = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                        if let intersection = sampleInterval.intersection(with: rollingInterval) {
                            let sampleSource = sample.sourceRevision.source.bundleIdentifier
                            let sampleValue: Double = intersection.duration / Double(60.0)
                            if isInBed(sleepSample) {
                                insertSleepSegment(sleepAggregate: .sleep_in_bed_duration, source: sampleSource, value: sampleValue)
                            } else if isAsleep(sleepSample) {
                                insertSleepSegment(sleepAggregate: .sleep_duration, source: sampleSource, value: sampleValue)
                                switch sleepSample {
                                case .asleepREM:
                                    insertSleepSegment(sleepAggregate: .sleep_rem_duration, source: sampleSource, value: sampleValue)
                                case .asleepCore:
                                    insertSleepSegment(sleepAggregate: .sleep_light_duration, source: sampleSource, value: sampleValue)
                                case .asleepDeep:
                                    insertSleepSegment(sleepAggregate: .sleep_deep_duration, source: sampleSource, value: sampleValue)
                                default:
                                    insertSleepSegment(sleepAggregate: .sleep_unknown_duration, source: sampleSource, value: sampleValue)
                                    break
                                }
                            } else if sleepSample == .awake {
                                insertSleepSegment(sleepAggregate: .sleep_awake_duration, source: sampleSource, value: sampleValue)
                                // Add interruptions
                                insertSleepSegment(sleepAggregate: .sleep_interruptions, source: sampleSource, value: 1.0)
                            } else {
                                insertSleepSegment(sleepAggregate: .sleep_unknown_duration, source: sampleSource, value: sampleValue)
                            }
                        }
                    }
                }
                
                for (stageKey, stageValue) in sleepStats {
                    for (sourceKey, sourceValue) in stageValue {
                        let stat = SahhaStat(id: UUID().uuidString, category: SahhaBiomarkerCategory.sleep.rawValue, type: stageKey.rawValue, aggregation: AggregationIdentifier.sum.rawValue, periodicity: periodicity.rawValue, value: sourceValue, unit: stageKey == .sleep_interruptions ? "count" : SahhaSensor.sleep.unitString, startDateTime: rollingInterval.start, endDateTime: rollingInterval.end, sources: [sourceKey])
                        stats.append(stat)
                    }
                }
                
                rollingInterval = DateInterval(start: rollingInterval.end, duration: duration)
            }
            callback(nil, stats)
        }
        Self.store.execute(query)
    }
    
    private func getExerciseStats(startDateTime: Date, endDateTime: Date, callback: @escaping (_ error: String?, _ stats: [SahhaStat])->Void)  {
        
        guard Self.isAvailable else {
            callback("Health data is not available on this device", [])
            return
        }
        
        let start = Calendar.current.startOfDay(for: startDateTime)
        var end = Calendar.current.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
        end = Calendar.current.startOfDay(for: end)
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQuery(sampleType: HKSampleType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { sampleQuery, samplesOrNil, error in
            if let error = error {
                print(error.localizedDescription)
                Sahha.postError(message: error.localizedDescription, path: "HealthActivity", method: "getExerciseStats", body: "")
                callback(error.localizedDescription, [])
                return
            }
            guard let samples = samplesOrNil as? [HKWorkout], samples.isEmpty == false else {
                callback("No stats were found for the given date range for exercise", [])
                return
            }
            
            var stats: [SahhaStat] = []
            let day = 86400.0
            var rollingInterval = DateInterval(start: start, duration: day)
            while rollingInterval.end <= end {
                
                typealias WorkoutSegment = Dictionary<String, Double>
                var workoutStats: Dictionary<String, WorkoutSegment> = [:]
                
                func insertWorkoutSegment(workoutSession: String, source: String, value: Double) {
                    if let workoutSegments = workoutStats[workoutSession] {
                        var  newWorkoutSegments = workoutSegments
                        if let oldValue = newWorkoutSegments[source] {
                            newWorkoutSegments[source] = oldValue + value
                        } else {
                            newWorkoutSegments[source] = value
                        }
                        workoutStats[workoutSession] = newWorkoutSegments
                    } else {
                        workoutStats[workoutSession] = [source: value]
                    }
                }
                
                for sample in samples {
                    let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                    if let intersection = sampleInterval.intersection(with: rollingInterval) {
                        let sampleSource = sample.sourceRevision.source.bundleIdentifier
                        let sampleValue: Double = intersection.duration / Double(60.0)
                        insertWorkoutSegment(workoutSession: "exercise_session_" + sample.workoutActivityType.name + "_duration", source: sampleSource, value: sampleValue)
                        // Add total duration
                        insertWorkoutSegment(workoutSession: "exercise_duration", source: sampleSource, value: sampleValue)
                    }
                }
                
                var workoutDuration: Double = 0
                var workoutSources: Set<String> = []
                for (sessionKey, sessionValue) in workoutStats {
                    for (sourceKey, sourceValue) in sessionValue {
                        workoutDuration += sourceValue
                        workoutSources.insert(sourceKey)
                        let stat = SahhaStat(id: UUID().uuidString, category: SahhaBiomarkerCategory.exercise.rawValue, type: sessionKey, aggregation: AggregationIdentifier.sum.rawValue, periodicity: PeriodicityIdentifier.daily.rawValue, value: sourceValue, unit: SahhaSensor.exercise.unitString, startDateTime: rollingInterval.start, endDateTime: rollingInterval.end, sources: [sourceKey])
                        stats.append(stat)
                    }
                }
                
                rollingInterval = DateInterval(start: rollingInterval.end, duration: day)
            }
            callback(nil, stats)
        }
        Self.store.execute(query)
    }
    
    private func getQuantityStats(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, periodicity: PeriodicityIdentifier, callback: @escaping (_ error: String?, _ stats: [SahhaStat])->Void)  {
        
        guard Self.isAvailable else {
            callback("Health data is not available on this device", [])
            return
        }
        
        guard let quantityType = sensor.objectType as? HKQuantityType else {
            callback("Stats are not available for \(sensor.rawValue)", [])
            return
        }
        let start: Date
        var end = Calendar.current.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
        end = Calendar.current.startOfDay(for: end)
        var dateComponents = DateComponents()
        
        switch periodicity {
        case .daily:
            start = Calendar.current.startOfDay(for: startDateTime)
            dateComponents.day = 1
        case .hourly:
            start = startDateTime
            dateComponents.hour = 1
        }
        
        
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: sensor.statsOptions, anchorDate: start, intervalComponents: dateComponents)
        
        query.initialResultsHandler = {
            _, results, error in
            
            guard let results = results else {
                if let error = error {
                    print(error.localizedDescription)
                }
                callback("error", [])
                return
            }
            
            var sahhaStats: [SahhaStat] = []
            
            for stat in results.statistics() {
                if let sahhaStat = Self.createSahhaStat(from: stat, quantityType: quantityType, sensor: sensor, periodicity: periodicity) {
                    sahhaStats.append(sahhaStat)
                }
            }
            
            sahhaStats.sort {
                $0.value > $1.value
            }
            
            callback(nil, sahhaStats)
        }
        
        Self.store.execute(query)
    }
    
    internal func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (_ error: String?, _ samples: [SahhaSample])->Void)  {
        
        guard Self.isAvailable else {
            callback("Health data is not available on this device", [])
            return
        }
        
        guard let objectType = sensor.objectType else {
            callback("Sahha | Samples not available for \(sensor.rawValue)", [])
            return
        }
        
        Self.store.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { status, error in
            switch status {
            case .unnecessary:
                if let sampleType = sensor.objectType as? HKSampleType {
                    
                    let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
                    let startDateDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                                               ascending: true)
                    let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [startDateDescriptor]) { sampleQuery, samplesOrNil, errorOrNil in
                        if let error = errorOrNil {
                            callback(error.localizedDescription, [])
                            return
                        }
                        
                        guard let samples = samplesOrNil else {
                            callback("No samples found for \(sensor.rawValue)", [])
                            return
                        }
                        
                        var sahhaSamples: [SahhaSample] = []
                        
                        switch sensor.category {
                        case .sleep:
                            guard let categorySamples = samples as? [HKCategorySample] else {
                                callback("Sahha | Sleep samples in incorrect format", [])
                                return
                            }
                            for categorySample in categorySamples {
                                let sleepStage: SleepStage = Self.getSleepStage(sample: categorySample)
                                let difference = Calendar.current.dateComponents([.minute], from: categorySample.startDate, to: categorySample.endDate)
                                let value = Double(difference.minute ?? 0)
                                let recordingMethod = getRecordingMethod(categorySample).rawValue
                                let sahhaSample = SahhaSample(id: categorySample.uuid.uuidString, category: sensor.category.rawValue, type: sleepStage.rawValue, value: value, unit: sensor.unitString, startDateTime: categorySample.startDate, endDateTime: categorySample.endDate, recordingMethod: recordingMethod, source: categorySample.sourceRevision.source.bundleIdentifier)
                                sahhaSamples.append(sahhaSample)
                            }
                            
                        case .exercise:
                            guard let workoutSamples = samples as? [HKWorkout] else {
                                callback("Sahha | Exercise samples in incorrect format", [])
                                return
                            }
                            for workoutSample in workoutSamples {
                                let difference = Calendar.current.dateComponents([.minute], from: workoutSample.startDate, to: workoutSample.endDate)
                                let value = Double(difference.minute ?? 0)
                                let recordingMethod = getRecordingMethod(workoutSample).rawValue
                                var sahhaStats: [SahhaStat] = []
                                if #available(iOS 16.0, *) {
                                    for workoutStat in workoutSample.allStatistics {
                                        if let sensor = SahhaSensor(quantityType: workoutStat.key), let sahhaStat = Self.createSahhaStat(from: workoutStat.value, quantityType: workoutStat.key, sensor: sensor, periodicity: .daily) {
                                            sahhaStats.append(sahhaStat)
                                        }
                                    }
                                } else {
                                    // Fallback on earlier versions
                                }
                                let sahhaSample = SahhaSample(id: workoutSample.uuid.uuidString, category: sensor.category.rawValue, type: "exercise_" + workoutSample.workoutActivityType.name, value: value, unit: sensor.unitString, startDateTime: workoutSample.startDate, endDateTime: workoutSample.endDate, recordingMethod: recordingMethod, source: workoutSample.sourceRevision.source.bundleIdentifier, stats: sahhaStats)
                                sahhaSamples.append(sahhaSample)
                            }
                        default:
                            guard let quantitySamples = samples as? [HKQuantitySample] else {
                                callback("Sahha | \(sensor.rawValue) samples in incorrect format", [])
                                return
                            }
                            
                            for quantitySample in quantitySamples {
                                let value: Double
                                if let unit = sensor.unit {
                                    value = quantitySample.quantity.doubleValue(for: unit)
                                } else {
                                    value = 0
                                }
                                let recordingMethod = getRecordingMethod(quantitySample).rawValue
                                let sahhaSample = SahhaSample(id: quantitySample.uuid.uuidString, category: sensor.category.rawValue, type: sensor.rawValue, value: value, unit: sensor.unitString, startDateTime: quantitySample.startDate, endDateTime: quantitySample.endDate, recordingMethod: recordingMethod, source: quantitySample.sourceRevision.source.bundleIdentifier)
                                sahhaSamples.append(sahhaSample)
                            }
                        }
                        
                        callback(nil, sahhaSamples)
                    }
                    Self.store.execute(query)
                } else {
                    callback("Sahha | Samples not available for \(sensor.rawValue)", [])
                    return
                }
            default:
                callback("Sahha | User permission needed to collect \(sensor.rawValue) samples", [])
                return
            }
        }
    }
    
    private func createAppLog(_ appLogType: AppLogType) {
        
        Task {
            let request = DataLogRequest(UUID(), logType: "device", dataType: appLogType.rawValue, value: 0, unit: "", source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
            
            await Self.dataManager.addDataLogs([request])
        }
    }
    
    private func createDeviceLog(_ isLocked: Bool) {
        
        Task {
            guard await Self.dataManager.containsSensor(.device_lock) else {
                return
            }
            
            let request = DataLogRequest(UUID(), sensor: .device_lock, value: isLocked ? 1 : 0, source: SahhaConfig.appId, recordingMethod: .automatically_recorded, deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
            
            await Self.dataManager.addDataLogs([request], sensor: .device_lock)
        }
    }
    
    private static func getSleepStage(sample: HKCategorySample) -> SleepStage {
        
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
        
        return sleepStage
    }
    
    // MARK: - Unused
    
    // Logs created inside "querySensors" function, ignoring stat aggregates for now. Commented for future reference
    
    //    private func createSleepLogs(sensor: SahhaSensor, samples: [HKCategorySample], startDate: Date, endDate: Date) {
    //
    //        Task {
    //
    //            var requests: [DataLogRequest] = []
    //            for sample in samples {
    //
    //                let sleepStage: SleepStage = Self.getSleepStage(sample: sample)
    //                let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
    //                let value = Double(difference.minute ?? 0)
    //
    //                let request = DataLogRequest(sample.uuid, sensor: .sleep, dataType: sleepStage.rawValue, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
    //
    //                requests.append(request)
    //            }
    //
    //            getSleepStats(startDateTime: startDate, endDateTime: endDate, periodicity: .daily) { [weak self] error, stats in
    //
    //                Task {
    //
    //                    for stat in stats {
    //                        let request = DataLogRequest(stat: stat)
    //                        requests.append(request)
    //                    }
    //
    //                    self?.getSleepStats(startDateTime: startDate, endDateTime: endDate, periodicity: .hourly) { hourlyError, hourlyStats in
    //
    //                        Task {
    //
    //                            for stat in hourlyStats {
    //                                let request = DataLogRequest(stat: stat)
    //                                requests.append(request)
    //                            }
    //
    //                            await Self.dataManager.addDataLogs(requests, sensor: sensor)
    //                        }
    //
    //                    }
    //                }
    //
    //            }
    //        }
    //    }
    //
    //    private func createExerciseLogs(sensor: SahhaSensor, samples: [HKWorkout], startDate: Date, endDate: Date) {
    //
    //        Task {
    //
    //            var requests: [DataLogRequest] = []
    //            for sample in samples {
    //                let sampleId = sample.uuid
    //                let sampleType = sample.workoutActivityType.name
    //                let source = sample.sourceRevision.source.bundleIdentifier
    //                let recordingMethod = getRecordingMethod(sample)
    //                let deviceType = sample.sourceRevision.productType ?? "type_unknown"
    //
    //                // Add exercise session
    //                var request = DataLogRequest(sampleId, sensor: .exercise, dataType: "exercise_session_" + sampleType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: sample.startDate, endDate: sample.endDate)
    //
    //                var additionalProperties: [String: String] = [:]
    //
    //                if let distance = sample.totalDistance {
    //                    let value = distance.doubleValue(for: .meter())
    //                    additionalProperties["total_distance"] = "\(value)"
    //                }
    //
    //                if let energy = sample.totalEnergyBurned {
    //                    let value = energy.doubleValue(for: .largeCalorie())
    //                    additionalProperties["total_energy_burned"] = "\(value)"
    //                }
    //
    //                if additionalProperties.isEmpty == false {
    //                    request.additionalProperties = additionalProperties
    //                }
    //
    //                requests.append(request)
    //
    //                // Add exercise events
    //                if let workoutEvents = sample.workoutEvents {
    //                    for workoutEvent in workoutEvents {
    //                        let workoutEventType: String
    //                        switch workoutEvent.type {
    //                        case .pause:
    //                            workoutEventType = "exercise_event_pause"
    //                        case .resume:
    //                            workoutEventType = "exercise_event_resume"
    //                        case .lap:
    //                            workoutEventType = "exercise_event_lap"
    //                        case .marker:
    //                            workoutEventType = "exercise_event_marker"
    //                        case .motionPaused:
    //                            workoutEventType = "exercise_event_motion_paused"
    //                        case .motionResumed:
    //                            workoutEventType = "exercise_event_motion_resumed"
    //                        case .segment:
    //                            workoutEventType = "exercise_event_segment"
    //                        case .pauseOrResumeRequest:
    //                            workoutEventType = "exercise_event_pause_or_resume_request"
    //                        @unknown default:
    //                            workoutEventType = "exercise_event_unknown"
    //                        }
    //                        let request = DataLogRequest(UUID(), sensor: .exercise, dataType: workoutEventType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutEvent.dateInterval.start, endDate: workoutEvent.dateInterval.end, parentId: sampleId)
    //                        requests.append(request)
    //                    }
    //                }
    //
    //                // Add exercise segments
    //                if #available(iOS 16.0, *) {
    //                    for workoutActivity in sample.workoutActivities {
    //                        let dataType = "exercise_segment_" + workoutActivity.workoutConfiguration.activityType.name
    //                        let endDate: Date = workoutActivity.endDate ?? workoutActivity.startDate + workoutActivity.duration
    //                        let request = DataLogRequest(UUID(), sensor: .exercise, dataType: dataType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutActivity.startDate, endDate: endDate, parentId: sampleId)
    //                        requests.append(request)
    //                    }
    //                }
    //            }
    //
    //            getExerciseStats(startDateTime: startDate, endDateTime: endDate) { error, stats in
    //
    //                Task {
    //                    for stat in stats {
    //                        let request = DataLogRequest(stat: stat)
    //                        requests.append(request)
    //                    }
    //
    //                    await Self.dataManager.addDataLogs(requests, sensor: sensor)
    //                }
    //
    //            }
    //
    //        }
    //    }
    
    //    private func createHealthLogs(sensor: SahhaSensor, samples: [HKQuantitySample], startDate: Date, endDate: Date) {
    //
    //        Task {
    //
    //            var requests: [DataLogRequest] = []
    //            for sample in samples {
    //
    //                let value: Double
    //                if let unit = sensor.unit {
    //                    value = sample.quantity.doubleValue(for: unit)
    //                } else {
    //                    value = 0
    //                }
    //
    //                var request = DataLogRequest(sample.uuid, sensor: sensor, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
    //
    //                var additionalProperties: [String: String] = [:]
    //
    //                if let metaValue = sample.metadata?[HKMetadataKeyHeartRateSensorLocation] as? NSNumber, let metaEnumValue = HKHeartRateSensorLocation(rawValue: metaValue.intValue) {
    //                    let stringValue: String
    //                    switch metaEnumValue {
    //                    case .chest:
    //                        stringValue = "chest"
    //                    case .earLobe:
    //                        stringValue = "ear_lobe"
    //                    case .finger:
    //                        stringValue = "finger"
    //                    case .foot:
    //                        stringValue = "foot"
    //                    case .hand:
    //                        stringValue = "hand"
    //                    case .wrist:
    //                        stringValue = "wrist"
    //                    case .other:
    //                        stringValue = "other"
    //                    @unknown default:
    //                        stringValue = "unknown"
    //                    }
    //                    additionalProperties = [DataLogPropertyIdentifier.measurementLocation.rawValue: stringValue]
    //                }
    //
    //                if let metaValue = sample.metadata?[HKMetadataKeyVO2MaxTestType] as? NSNumber, let metaEnumValue = HKVO2MaxTestType(rawValue: metaValue.intValue) {
    //                    let stringValue: String
    //                    switch metaEnumValue {
    //                    case .maxExercise:
    //                        stringValue = "max_exercise"
    //                    case .predictionNonExercise:
    //                        stringValue = "prediction_non_exercise"
    //                    case .predictionSubMaxExercise:
    //                        stringValue = "prediction_sub_max_exercise"
    //                    @unknown default:
    //                        stringValue = "unknown"
    //                    }
    //                    additionalProperties = [DataLogPropertyIdentifier.measurementMethod.rawValue: stringValue]
    //                }
    //
    //                if let metaValue = sample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber, let metaEnumValue = HKHeartRateMotionContext(rawValue: metaValue.intValue) {
    //                    let stringValue: String
    //                    switch metaEnumValue {
    //                    case .notSet:
    //                        stringValue = "not_set"
    //                    case .sedentary:
    //                        stringValue = "sedentary"
    //                    case .active:
    //                        stringValue = "active"
    //                    @unknown default:
    //                        stringValue = "unknown"
    //                    }
    //                    additionalProperties = [DataLogPropertyIdentifier.motionContext.rawValue: stringValue]
    //                }
    //
    //                if let metaValue = sample.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? NSNumber, let metaEnumValue = HKBloodGlucoseMealTime(rawValue: metaValue.intValue) {
    //                    let relationToMeal: BloodRelationToMeal
    //                    switch metaEnumValue {
    //                    case .preprandial:
    //                        relationToMeal = .before_meal
    //                    case .postprandial:
    //                        relationToMeal = .after_meal
    //                    default:
    //                        relationToMeal = .unknown
    //                    }
    //                    additionalProperties = [DataLogPropertyIdentifier.relationToMeal.rawValue: relationToMeal.rawValue]
    //                }
    //
    //                if additionalProperties.isEmpty == false {
    //                    request.additionalProperties = additionalProperties
    //                }
    //
    //                requests.append(request)
    //            }
    //
    //            getQuantityStats(sensor: sensor, startDateTime: startDate, endDateTime: endDate, periodicity: .daily) { [weak self] error, stats in
    //
    //                Task {
    //                    for stat in stats {
    //                        let request = DataLogRequest(stat: stat)
    //                        requests.append(request)
    //                    }
    //
    //                    switch sensor {
    //                    case .steps, .heart_rate, .respiratory_rate, .oxygen_saturation, .basal_body_temperature:
    //                        self?.getQuantityStats(sensor: sensor, startDateTime: startDate, endDateTime: endDate, periodicity: .hourly) { hourlyError, hourlyStats in
    //
    //                            Task {
    //                                for stat in hourlyStats {
    //                                    let request = DataLogRequest(stat: stat)
    //                                    requests.append(request)
    //                                }
    //
    //                                await Self.dataManager.addDataLogs(requests, sensor: sensor)
    //                            }
    //                        }
    //                    default:
    //                        await Self.dataManager.addDataLogs(requests, sensor: sensor)
    //                    }
    //                }
    //
    //            }
    //
    //        }
    //    }
    //
}
