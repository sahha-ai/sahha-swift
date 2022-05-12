// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public struct SahhaSettings {
    public let environment: SahhaEnvironment /// development or production
    public var framework: SahhaFramework = .ios_swift /// automatically set by sdk
    public var sensors: Set<SahhaSensor> /// list of
    public var postSensorDataManually: Bool
    
    public init(environment: SahhaEnvironment, sensors: Set<SahhaSensor>? = nil, postSensorDataManually: Bool? = nil) {
        self.environment = environment
        if let sensors = sensors {
            // If list is specified, add only those sensors
            self.sensors = sensors
        } else {
            // If list is nil, add all possible sensors
            var sensors: Set<SahhaSensor> = []
            for sensor in SahhaSensor.allCases {
                sensors.insert(sensor)
            }
            self.sensors = sensors
        }
        self.postSensorDataManually = postSensorDataManually ?? false
    }
}

public class Sahha {
    internal static var settings = SahhaSettings(environment: .development)
    private static var health = HealthActivity()
    private static var motion = MotionActivity()
    
    private static var sensorDataTasks: Set<SahhaSensor> = [] {
        didSet {
            if sensorDataTasks.count == 0, sensorDataInfo.count > 0 {
                var errorString: String?
                var success: Bool = true
                for item in sensorDataInfo {
                    if let error = item.value.error {
                        if let previousError = errorString {
                            errorString = previousError + " | " + error
                        } else {
                            errorString = error
                        }
                    }
                    if item.value.success == false {
                        success = false
                    }
                }
                postSensorDataCallback?(errorString, success)
                postSensorDataCallback = nil
                sensorDataInfo.removeAll()
                sensorDataTasks.removeAll()
            }
        }
    }
    private static var sensorDataInfo: [SahhaSensor:(error: String?, success: Bool)] = [:]
    private static var postSensorDataCallback: ((String?, Bool) -> Void)? = nil
    
    private init() {
        print("Sahha | SDK init")
    }

    public static func configure(_ settings: SahhaSettings
    ) {
        Self.settings = settings
        
        SahhaAnalytics.configure()
        
        SahhaCredentials.getCredentials()
                
        health.configure(sensors: settings.sensors)
        
        motion.configure(sensors: settings.sensors)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        
        print("Sahha | SDK configured")
    }
    
    /// Launch the Sahha SDK immediately after configure
    public static func launch() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    @objc static private func onAppOpen() {
    }
    
    @objc static private func onAppClose() {
    }
    
    // MARK: - Authentication
    
    @discardableResult public static func authenticate(profileToken: String, refreshToken: String) -> Bool {
        return SahhaCredentials.setCredentials(profileToken: profileToken, refreshToken: refreshToken)
    }
    
    public static func deauthenticate() {
        SahhaCredentials.deleteCredentials()
    }
  
    // MARK: - Demographic
    
    public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void) {
        APIController.getDemographic { result in
            switch result {
            case .success(let response):
                callback(nil, response)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void) {
        APIController.putDemographic(body: demographic) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, false)
            }
        }
    }
    
    // MARK: - Sensors
    
    public static func getSensorStatus(_ sensor: SahhaSensor, callback: @escaping (SahhaSensorStatus)->Void) {
        switch sensor {
        case .sleep:
            callback(health.activityStatus)
        case .pedometer:
            callback(motion.activityStatus)
        case .device:
            callback(.pending)
        }
    }
    
    public static func enableSensor(_ sensor: SahhaSensor, callback: @escaping (SahhaSensorStatus)->Void) {

        switch sensor {
        case .sleep:
            health.activate { newStatus in
                callback(newStatus)
            }
        case .pedometer:
            motion.activate { newStatus in
                callback(newStatus)
            }
        case .device:
            callback(.pending)
        }
    }
    
    public static func postSensorData(_ sensors: Set<SahhaSensor>? = nil, callback: @escaping (String?, Bool) -> Void) {
        
        var sensorList: Set<SahhaSensor>
        if let sensors = sensors {
            sensorList = sensors
        } else {
            // If list is nil, add all possible sensors
            sensorList = []
            for sensor in SahhaSensor.allCases {
                sensorList.insert(sensor)
            }
        }
        
        // Save callback
        postSensorDataCallback = callback

        // Add tasks
        for sensor in sensorList {
            switch sensor {
            case .sleep:
                if sensorDataTasks.contains(.sleep) == false {
                    sensorDataTasks.insert(.sleep)
                    health.postSensorData(.sleep) { error, success in
                        sensorDataInfo[.sleep] = (error: error, success: success)
                        sensorDataTasks.remove(.sleep)
                    }
                }
            case .pedometer:
                if sensorDataTasks.contains(.pedometer) == false {
                    sensorDataTasks.insert(.pedometer)
                    motion.postSensorData(.pedometer) { error, success in
                        sensorDataInfo[.pedometer] = (error: error, success: success)
                        sensorDataTasks.remove(.pedometer)
                    }
                }
            case .device:
                break
            }
        }
    }
    
    // MARK: - Analyzation
    
    public static func analyze(dates:(startDate: Date, endDate: Date)? = nil, callback: @escaping (String?, String?) -> Void) {
        var queryParams: [String: String] = [:]
        if let dates = dates {
            queryParams["startDate"] = dates.startDate.toTimezoneFormat
            queryParams["endDate"] = dates.endDate.toTimezoneFormat
        }
        APIController.getAnalyzation(queryParams: queryParams) { result in
            switch result {
            case .success(let response):
                if let object = try? JSONSerialization.jsonObject(with: response.data, options: []),
                   let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                   let prettyPrintedString = String(data: data, encoding: .utf8) {
                    callback(nil, prettyPrintedString)
                } else {
                    callback("Analyzation data encoding error", nil)
                }
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    public static func openAppSettings() {
        DispatchQueue.main.async {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:]) { _ in
            }
        }
    }
}

