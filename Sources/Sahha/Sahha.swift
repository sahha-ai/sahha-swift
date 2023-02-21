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

private enum SahhaStorage: String {
    case timezone
    case sdkVersion
    case appVersion
    case systemVersion
}

public class Sahha {
    internal static var settings = SahhaSettings(environment: .development)
    private static var health = HealthActivity()
    
    private init() {
        print("Sahha | SDK init")
    }

    public static func configure(_ settings: SahhaSettings, callback: (() -> Void)? = nil) {
        
        Self.settings = settings
                
        SahhaCredentials.getCredentials()
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
                                
        health.configure(sensors: settings.sensors, callback: callback)
        
        print("Sahha | SDK configured")
    }
    
    @objc static private func onAppOpen() {
        let defaults = UserDefaults.standard
        let currentTimezone = Date().toUTCOffsetFormat
        let timezone = defaults.string(forKey: SahhaStorage.timezone.rawValue) ?? ""
        let sdkVersion = defaults.string(forKey: SahhaStorage.sdkVersion.rawValue) ?? ""
        let appVersion = defaults.string(forKey: SahhaStorage.appVersion.rawValue) ?? ""
        let systemVersion = defaults.string(forKey: SahhaStorage.systemVersion.rawValue) ?? ""
        if timezone != currentTimezone || sdkVersion != SahhaConfig.sdkVersion || appVersion != SahhaConfig.appVersion || systemVersion != SahhaConfig.systemVersion {
            defaults.set(currentTimezone, forKey: SahhaStorage.timezone.rawValue)
            defaults.set(SahhaConfig.sdkVersion, forKey: SahhaStorage.sdkVersion.rawValue)
            defaults.set(SahhaConfig.appVersion, forKey: SahhaStorage.appVersion.rawValue)
            defaults.set(SahhaConfig.systemVersion, forKey: SahhaStorage.systemVersion.rawValue)
            putDeviceInfo { _, _ in }
        }
    }
    
    @objc static private func onAppClose() {
    }
    
    // MARK: - Authentication
    
    public static var isAuthenticated: Bool {
        return SahhaCredentials.isAuthenticated
    }
    
    @discardableResult public static func authenticate(profileToken: String, refreshToken: String) -> Bool {
        return SahhaCredentials.setCredentials(profileToken: profileToken, refreshToken: refreshToken)
    }
    
    public static func deauthenticate() {
        SahhaCredentials.deleteCredentials()
    }
    
    // MARK: - Device Info
    
    private static func putDeviceInfo(callback: @escaping (String?, Bool) -> Void) {
        let body = ErrorModel(sdkId: settings.framework.rawValue, sdkVersion: SahhaConfig.sdkVersion, appId: SahhaConfig.appId, appVersion: SahhaConfig.appVersion, deviceType: SahhaConfig.deviceType, deviceModel: SahhaConfig.deviceModel, system: SahhaConfig.system, systemVersion: SahhaConfig.systemVersion, timeZone: Date().toUTCOffsetFormat)
        APIController.putDeviceInfo(body: body) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
  
    // MARK: - Demographic
    
    public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void) {
        APIController.getDemographic { result in
            switch result {
            case .success(let response):
                callback(nil, response)
            case .failure(let error):
                print(error.message)
                callback(error.message, nil)
            }
        }
    }
    
    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void) {
        APIController.putDemographic(body: demographic) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    // MARK: - Sensors
    
    public static func getSensorStatus(callback: @escaping (SahhaSensorStatus)->Void) {
        callback(health.activityStatus)
    }
    
    public static func enableSensors(callback: @escaping (SahhaSensorStatus)->Void) {
        health.activate { newStatus in
            callback(newStatus)
        }
    }
    
    public static func postSensorData(callback: @escaping (String?, Bool) -> Void) {

        health.postSensorData(callback: callback)
    }
    
    // MARK: - Analyzation
    
    public static func analyze(dates:(startDate: Date, endDate: Date)? = nil, includeSourceData:Bool = false, callback: @escaping (String?, String?) -> Void) {
        APIController.postAnalyzation(body: AnalyzationRequest(startDate: dates?.startDate, endDate: dates?.endDate, includeSourceData: includeSourceData)) { result in
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
                print(error.message)
                callback(error.message, nil)
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

