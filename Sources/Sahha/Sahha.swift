// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public struct SahhaSettings {
    public let environment: SahhaEnvironment /// development or production
    public var framework: SahhaFramework = .ios_swift /// automatically set by sdk
    public var sensors: Set<SahhaSensor> /// list of
    
    public init(environment: SahhaEnvironment, sensors: Set<SahhaSensor>? = nil) {
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
    }
}

private enum SahhaStorage: String {
    case timeZone
    case sdkVersion
    case appVersion
    case systemVersion
    
    var getValue: String {
        return UserDefaults.standard.string(forKey: self.rawValue) ?? ""
    }
    
    func setValue(_ value: String) {
        UserDefaults.standard.set(value, forKey: self.rawValue)
    }
}

public class Sahha {
    internal static var appId: String = ""
    internal static var appSecret: String = ""
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
        checkDeviceInfo()
    }
    
    @objc static private func onAppClose() {
    }
    
    // MARK: - Authentication
    
    public static var isAuthenticated: Bool {
        return SahhaCredentials.isAuthenticated
    }
    
    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void) {
        
        Self.appId = appId
        Self.appSecret = appSecret
        
        APIController.postProfileToken(body: ProfileTokenRequest(externalId: externalId)) { result in
            switch result {
            case .success(let response):
                SahhaCredentials.setCredentials(profileToken: response.profileToken, refreshToken: response.refreshToken)
                checkDeviceInfo()
                callback(nil, true)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    public static func deauthenticate() {
        SahhaCredentials.deleteCredentials()
    }
    
    // MARK: - Device Info
    
    private static func checkDeviceInfo() {
        if SahhaCredentials.isAuthenticated, SahhaStorage.sdkVersion.getValue != SahhaConfig.sdkVersion || SahhaStorage.appVersion.getValue != SahhaConfig.appVersion || SahhaStorage.systemVersion.getValue != SahhaConfig.systemVersion || SahhaStorage.timeZone.getValue != SahhaConfig.timeZone {
            putDeviceInfo { _, success in
                if success {
                    // Save the latest values
                    SahhaStorage.sdkVersion.setValue(SahhaConfig.sdkVersion)
                    SahhaStorage.appVersion.setValue(SahhaConfig.appVersion)
                    SahhaStorage.systemVersion.setValue(SahhaConfig.systemVersion)
                    SahhaStorage.timeZone.setValue(SahhaConfig.timeZone)
                }
            }
        }
    }
    
    private static func putDeviceInfo(callback: @escaping (String?, Bool) -> Void) {
        let body = ErrorModel(sdkId: settings.framework.rawValue, sdkVersion: SahhaConfig.sdkVersion, appId: SahhaConfig.appId, appVersion: SahhaConfig.appVersion, deviceType: SahhaConfig.deviceType, deviceModel: SahhaConfig.deviceModel, system: SahhaConfig.system, systemVersion: SahhaConfig.systemVersion, timeZone: SahhaConfig.timeZone)
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
    
    public static func analyze(dates:(startDate: Date, endDate: Date)? = nil, callback: @escaping (String?, String?) -> Void) {
        APIController.postAnalyzation(body: AnalyzationRequest(startDate: dates?.startDate, endDate: dates?.endDate)) { result in
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
    
    // MARK: - Feedback
    
    public static func postSurvey(_ survey: SahhaSurvey, callback: @escaping (String?, Bool) -> Void) {
        APIController.postSurvey(body: survey) { result in
            switch result {
            case .success(_):
                callback(nil, true)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    // MARK: - Settings
    
    public static func openAppSettings() {
        DispatchQueue.main.async {
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:]) { _ in
            }
        }
    }
}

