// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import HealthKit

fileprivate actor DataManager {
    
    private let maxDataLogRequestLimit: Int = 90
    private var dataLogs: [DataLogRequest] = []
    private var enabledSensors: Set<SahhaSensor> = []
    private var observedSensors: Set<SahhaSensor> = []
    private var queriedSensors: Set<SahhaSensor> = [] {
        didSet {
            if queriedSensors.isEmpty, dataLogs.isEmpty == false {
                startPostingDataLogs()
            }
        }
    }
    
    func clearData() {
        dataLogs = []
        saveDataLogs()
    }
    
    func loadData() {
        dataLogs = loadDataLogs()
    }
    
    func isEmpty() -> Bool {
        return dataLogs.isEmpty
    }
    
    func addDataLogs(_ logs: [DataLogRequest]) {
        if logs.isEmpty == false {
            dataLogs.append(contentsOf: logs)
        }
    }
    
    func addDataLogs(_ logs: [DataLogRequest], sensor: SahhaSensor) {
        if logs.isEmpty == false {
            dataLogs.append(contentsOf: logs)
        }
        if queriedSensors.contains(sensor) {
            queriedSensors.remove(sensor)
        }
    }
    
    private func saveDataLogs(_ logs: [DataLogRequest] = []) {
        
        if logs.isEmpty == false {
            dataLogs.append(contentsOf: logs)
        }
        
        let encoder = JSONEncoder()
        var encodedDataLogs: [Data] = []
        for dataLog in dataLogs {
            do {
                let data = try encoder.encode(dataLog)
                encodedDataLogs.append(data)
            } catch {
                // Fallback
            }
        }
        
        UserDefaults.standard.setValue(encodedDataLogs, forKey: "SahhaDataLogs")
    }
    
    private func loadDataLogs() -> [DataLogRequest] {
        let encodedDataLogs = UserDefaults.standard.array(forKey: "SahhaDataLogs") as? [Data] ?? []
        var savedDataLogs: [DataLogRequest] = []
        let decoder = JSONDecoder()
        for encodedDataLog in encodedDataLogs {
            do {
                let dataLog = try decoder.decode(DataLogRequest.self, from: encodedDataLog)
                savedDataLogs.append(dataLog)
            } catch {
                break
            }
        }
        
        return savedDataLogs
    }
    
    private func startPostingDataLogs() {
        saveDataLogs()
        for _ in 0..<10 {
            if dataLogs.isEmpty {
                break
            } else {
                postPendingDataLogs()
            }
        }
    }
    
    private func postPendingDataLogs() {
        
        let requestCount: Int = min(dataLogs.count, maxDataLogRequestLimit)
        if requestCount > 0 {
            let dataLogRequests: [DataLogRequest] = Array(dataLogs.prefix(maxDataLogRequestLimit))
            dataLogs.removeFirst(dataLogRequests.count)
            
            if Sahha.settings?.environment == .sandbox {
                
                // Additional logging for Sandbox environment
                var requests: [DataLogRequest] = []
                
                for var request in dataLogRequests {
                    var postDateTimes = request.postDateTimes ?? []
                    postDateTimes.append(Date().toDateTime)
                    request.postDateTimes = postDateTimes
                    requests.append(request)
                }
                
                postDataLogs(requests)
                
            } else {
                postDataLogs(dataLogRequests)
            }
        } else {
            saveDataLogs()
        }
    }
    
    private func postDataLogs(_ requests: [DataLogRequest]) {
        
        func onSuccess() {
            
            Task {
                postPendingDataLogs()
            }
        }
        
        func onFailure(_ requests: [DataLogRequest]) {
            
            Task {
                saveDataLogs(requests)
            }
        }
        
        APIController.postDataLog(body: requests) { result in
            
            switch result {
            case .success(_):
                onSuccess()
            case .failure(let error):
                print(error.localizedDescription)
                onFailure(requests)
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
        queriedSensors.insert(sensor)
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
    UserDefaults.standard.set(date: date, forKey: sensor.keyName)
}

fileprivate func getAnchorDate(sensor: SahhaSensor) -> Date? {
    UserDefaults.standard.date(forKey: sensor.keyName)
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
    var recordingMethod: RecordingMethodIdentifier = .UNKNOWN
    if let wasUserEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber, wasUserEntered.boolValue == true {
        recordingMethod = .MANUAL_ENTRY
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
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppStart), name: UIApplication.didFinishLaunchingNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppResume), name: UIApplication.didBecomeActiveNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppPause), name: UIApplication.willResignActiveNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onAppDestroy), name: UIApplication.willTerminateNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onDeviceUnlock), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(onDeviceLock), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
            
            onAppCreate()
        }
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
            setAnchor(nil, sensor: sensor)
        }
        setAnchorDate(nil, sensor: .activity_summary)
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
    
    private func querySensor(_ sensor: SahhaSensor) {
        
        guard Self.isAvailable, Sahha.isAuthenticated else {
            return
        }
        
        if let objectType = sensor.objectType {
            
            Self.store.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { status, error in
                switch status {
                case .unnecessary:
                    if let sampleType = sensor.objectType as? HKSampleType {
                        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)
                        let anchor = getAnchor(sensor: sensor)
                        let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] newQuery, samplesOrNil, deletedObjectsOrNil, anchorOrNil, errorOrNil in
                            if let error = errorOrNil {
                                self?.filterError(error, path: "HealthActivity", method: "postSensorData", body: "let query = HKAnchoredObjectQuery")
                                Task {
                                    await Self.dataManager.addDataLogs([], sensor: sensor)
                                }
                                return
                            }
                            guard let newAnchor = anchorOrNil, let samples = samplesOrNil, samples.isEmpty == false else {
                                Task {
                                    await Self.dataManager.addDataLogs([], sensor: sensor)
                                }
                                return
                            }
                            
                            setAnchor(newAnchor, sensor: sensor)
                            
                            switch sensor.logType {
                            case .sleep:
                                guard let categorySamples = samples as? [HKCategorySample] else {
                                    print("Sahha | Sleep samples in incorrect format")
                                    Task {
                                        await Self.dataManager.addDataLogs([], sensor: sensor)
                                    }
                                    return
                                }
                                self?.createSleepLogs(sensor: sensor, samples: categorySamples)
                            case .exercise:
                                guard let workoutSamples = samples as? [HKWorkout] else {
                                    print("Sahha | Exercise samples in incorrect format")
                                    Task {
                                        await Self.dataManager.addDataLogs([], sensor: sensor)
                                    }
                                    return
                                }
                                self?.createExerciseLogs(sensor: sensor, samples: workoutSamples)
                            default:
                                guard let quantitySamples = samples as? [HKQuantitySample] else {
                                    print("Sahha | \(sensor.rawValue) samples in incorrect format")
                                    Task {
                                        await Self.dataManager.addDataLogs([], sensor: sensor)
                                    }
                                    return
                                }
                                self?.createHealthLogs(sensor: sensor, samples: quantitySamples)
                            }
                        }
                        Task {
                            await Self.dataManager.querySensor(sensor)
                            Self.store.execute(query)
                        }
                    }
                default:
                    break
                }
            }
        }
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
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_total, value: activitySummary.appleStandHours.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                if #available(iOS 16.0, *), let value = activitySummary.standHoursGoal?.doubleValue(for: .count()) {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                } else {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .stand_hours_daily_goal, value: activitySummary.appleStandHoursGoal.doubleValue(for: .count()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                }
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_total, value: activitySummary.appleMoveTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .move_time_daily_goal, value: activitySummary.appleMoveTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_total, value: activitySummary.appleExerciseTime.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                if #available(iOS 16.0, *), let value = activitySummary.exerciseTimeGoal?.doubleValue(for: .minute()) {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: value, source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                } else {
                                    requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .exercise_time_daily_goal, value: activitySummary.appleExerciseTimeGoal.doubleValue(for: .minute()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                }
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_total, value: activitySummary.activeEnergyBurned.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                                
                                requests.append(DataLogRequest(UUID(), logType: logType, activitySummary: .active_energy_burned_daily_goal, value: activitySummary.activeEnergyBurnedGoal.doubleValue(for: .largeCalorie()), source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: date, endDate: date))
                            }
                            
                            await Self.dataManager.addDataLogs(requests, sensor: .activity_summary)
                        }
                    }
                    
                    Task {
                        await Self.dataManager.querySensor(.activity_summary)
                        Self.store.execute(query)
                    }
                }
            default:
                return
            }
        }
        
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
                
                if sensor == .sleep {
                    self?.getSleepStats(startDateTime: startDateTime, endDateTime: endDateTime, callback: callback)
                    return
                }
                
                guard let quantityType = sensor.objectType as? HKQuantityType else {
                    callback("Stats are not available for \(sensor.rawValue)", [])
                    return
                }
                
                let start = Calendar.current.startOfDay(for: startDateTime)
                var end = Calendar.current.date(byAdding: .day, value: 1, to: endDateTime) ?? endDateTime
                end = Calendar.current.startOfDay(for: end)
                var dateComponents = DateComponents()
                dateComponents.day = 1
                
                let options: HKStatisticsOptions
                switch sensor {
                case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose, .vo2_max, .oxygen_saturation, .respiratory_rate, .sleeping_wrist_temperature, .basal_body_temperature, .body_temperature, .basal_metabolic_rate, .height, .weight:
                    options = HKStatisticsOptions.discreteAverage
                default:
                    options = HKStatisticsOptions.cumulativeSum
                }
                let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
                let query = HKStatisticsCollectionQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options, anchorDate: start, intervalComponents: dateComponents)
                
                query.initialResultsHandler = {
                    _, results, error in
                    
                    guard let results = results else {
                        if let error = error {
                            print(error.localizedDescription)
                        }
                        callback("error", [])
                        return
                    }
                    
                    var stats: [SahhaStat] = []
                    
                    for result in results.statistics() {
                        var quantity: HKQuantity?
                        switch sensor {
                        case .heart_rate, .resting_heart_rate, .walking_heart_rate_average, .heart_rate_variability_sdnn, .blood_pressure_systolic, .blood_pressure_diastolic, .blood_glucose, .vo2_max, .oxygen_saturation, .respiratory_rate, .sleeping_wrist_temperature, .basal_body_temperature, .body_temperature, .basal_metabolic_rate, .height, .weight:
                            quantity = result.averageQuantity()
                        default:
                            quantity = result.sumQuantity()
                        }
                        if let quantity = quantity, let unit: HKUnit = sensor.unit {
                            let value: Double = quantity.doubleValue(for: unit)
                            var sources: [String] = []
                            for source in result.sources ?? [] {
                                sources.append(source.bundleIdentifier)
                            }
                            let stat = SahhaStat(id: UUID().uuidString, type: sensor.rawValue, value: value, unit: sensor.unitString, startDateTime: result.startDate, endDateTime: result.endDate, sources: sources)
                            stats.append(stat)
                        }
                    }
                    
                    callback(nil, stats)
                }
                
                Self.store.execute(query)
                
            default:
                callback("User permission is not granted for \(sensor.keyName)", [])
                return
            }
        }
    }
    
    private func getSleepStats(startDateTime: Date, endDateTime: Date, callback: @escaping (_ error: String?, _ stats: [SahhaStat])->Void)  {
        
        var start = Calendar.current.date(byAdding: .day, value: -1, to: startDateTime) ?? startDateTime
        start = Calendar.current.startOfDay(for: start)
        start = Calendar.current.date(bySetting: .hour, value: 12, of: start) ?? start
        var end = Calendar.current.startOfDay(for: endDateTime)
        end = Calendar.current.date(bySetting: .hour, value: 12, of: end) ?? end
        
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
            let day = 86400.0
            var rollingInterval = DateInterval(start: start, duration: day)
            while rollingInterval.end <= end {
                
                var sleepStats: Dictionary<SleepStage, (value: Double, sources: Set<String>)> = [:]
                for stage in SleepStage.allCases {
                    sleepStats[stage] = (value: 0, sources: [])
                }
                
                for sample in samples {
                    if let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
                        if let intersection = sampleInterval.intersection(with: rollingInterval) {
                            let sampleTime = intersection.duration / 60
                            let sampleSource = sample.sourceRevision.source.bundleIdentifier
                            if isInBed(sleepStage) {
                                sleepStats[.sleep_stage_in_bed]?.value += sampleTime
                                sleepStats[.sleep_stage_in_bed]?.sources.insert(sampleSource)
                            } else if isAsleep(sleepStage) {
                                sleepStats[.sleep_stage_sleeping]?.value += sampleTime
                                sleepStats[.sleep_stage_sleeping]?.sources.insert(sampleSource)
                                switch sleepStage {
                                case .asleepREM:
                                    sleepStats[.sleep_stage_rem]?.value += sampleTime
                                    sleepStats[.sleep_stage_rem]?.sources.insert(sampleSource)
                                case .asleepCore:
                                    sleepStats[.sleep_stage_light]?.value += sampleTime
                                    sleepStats[.sleep_stage_light]?.sources.insert(sampleSource)
                                case .asleepDeep:
                                    sleepStats[.sleep_stage_deep]?.value += sampleTime
                                    sleepStats[.sleep_stage_deep]?.sources.insert(sampleSource)
                                default:
                                    sleepStats[.sleep_stage_unknown]?.value += sampleTime
                                    sleepStats[.sleep_stage_unknown]?.sources.insert(sampleSource)
                                    break
                                }
                            }
                        }
                    }
                }
                
                for (key, value) in sleepStats {
                    let stat = SahhaStat(id: UUID().uuidString, type: key == .sleep_stage_sleeping ? "sleep" : key.rawValue, value: value.value, unit: SahhaSensor.sleep.unitString, startDateTime: rollingInterval.start, endDateTime: rollingInterval.end, sources: Array(value.sources))
                    stats.append(stat)
                }
                
                rollingInterval = DateInterval(start: rollingInterval.end, duration: day)
            }
            callback(nil, stats)
        }
        Self.store.execute(query)
    }
    
    internal func getSamples(sensor: SahhaSensor, startDateTime: Date, endDateTime: Date, callback: @escaping (_ error: String?, _ samples: [SahhaSample])->Void)  {
        
        guard Self.isAvailable else {
            return
        }
        
        guard let objectType = sensor.objectType else {
            callback("Samples are not available for \(sensor.rawValue)", [])
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
                        
                        switch sensor.logType {
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
                                let sahhaSample = SahhaSample(id: categorySample.uuid.uuidString, type: sleepStage.rawValue, value: value, unit: sensor.unitString, startDateTime: categorySample.startDate, endDateTime: categorySample.endDate, recordingMethod: recordingMethod, source: categorySample.sourceRevision.source.bundleIdentifier)
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
                                let sahhaSample = SahhaSample(id: workoutSample.uuid.uuidString, type: "exercise_" + workoutSample.workoutActivityType.name, value: value, unit: sensor.unitString, startDateTime: workoutSample.startDate, endDateTime: workoutSample.endDate, recordingMethod: recordingMethod, source: workoutSample.sourceRevision.source.bundleIdentifier)
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
                                let sahhaSample = SahhaSample(id: quantitySample.uuid.uuidString, type: sensor.rawValue, value: value, unit: sensor.unitString, startDateTime: quantitySample.startDate, endDateTime: quantitySample.endDate, recordingMethod: recordingMethod, source: quantitySample.sourceRevision.source.bundleIdentifier)
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
            let request = DataLogRequest(UUID(), logType: "device", dataType: appLogType.rawValue, value: 0, unit: "", source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
            
            await Self.dataManager.addDataLogs([request])
        }
    }
    
    private func createDeviceLog(_ isLocked: Bool) {
        
        Task {
            guard await Self.dataManager.containsSensor(.device_lock) else {
                return
            }
            
            let request = DataLogRequest(UUID(), sensor: .device_lock, value: isLocked ? 1 : 0, source: SahhaConfig.appId, recordingMethod: .AUTOMATICALLY_RECORDED, deviceType: SahhaConfig.deviceType, startDate: Date(), endDate: Date())
            
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
    
    private func createSleepLogs(sensor: SahhaSensor, samples: [HKCategorySample]) {
        
        Task {
            
            var requests: [DataLogRequest] = []
            for sample in samples {
                
                let sleepStage: SleepStage = Self.getSleepStage(sample: sample)
                let difference = Calendar.current.dateComponents([.minute], from: sample.startDate, to: sample.endDate)
                let value = Double(difference.minute ?? 0)
                
                let request = DataLogRequest(sample.uuid, sensor: .sleep, dataType: sleepStage.rawValue, value: value, source: sample.sourceRevision.source.bundleIdentifier, recordingMethod: getRecordingMethod(sample), deviceType: sample.sourceRevision.productType ?? "type_unknown", startDate: sample.startDate, endDate: sample.endDate)
                
                requests.append(request)
            }
            
            await Self.dataManager.addDataLogs(requests, sensor: sensor)
        }
    }
    
    private func createExerciseLogs(sensor: SahhaSensor, samples: [HKWorkout]) {
        
        Task {
            
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
                        let request = DataLogRequest(UUID(), sensor: .exercise, dataType: dataType, value: 1, source: source, recordingMethod: recordingMethod, deviceType: deviceType, startDate: workoutActivity.startDate, endDate: endDate, parentId: sampleId)
                        requests.append(request)
                    }
                }
            }
            
            await Self.dataManager.addDataLogs(requests, sensor: sensor)
        }
    }
    
    private func createHealthLogs(sensor: SahhaSensor, samples: [HKQuantitySample]) {
        
        Task {
            
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
                    additionalProperties = [DataLogPropertyIdentifier.measurementLocation.rawValue: stringValue]
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
                    additionalProperties = [DataLogPropertyIdentifier.measurementMethod.rawValue: stringValue]
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
                    additionalProperties = [DataLogPropertyIdentifier.motionContext.rawValue: stringValue]
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
                    additionalProperties = [DataLogPropertyIdentifier.relationToMeal.rawValue: relationToMeal.rawValue]
                }
                
                if additionalProperties.isEmpty == false {
                    request.additionalProperties = additionalProperties
                }
                
                requests.append(request)
            }
            await Self.dataManager.addDataLogs(requests, sensor: sensor)
        }
    }
    
}
