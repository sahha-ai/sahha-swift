// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public struct SahhaSettings {
    public let environment: SahhaEnvironment /// sandbox or production
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
    internal static var settings = SahhaSettings(environment: .sandbox)
    private static var health = HealthActivity()

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
    
    public static var profileToken: String? {
        return SahhaCredentials.profileToken
    }
    
    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void) {
        
        Self.appId = appId
        Self.appSecret = appSecret
        
        APIController.postProfileToken(body: ProfileTokenRequest(externalId: externalId)) { result in
            switch result {
            case .success(let response):
                if SahhaCredentials.setCredentials(profileToken: response.profileToken, refreshToken: response.refreshToken) {
                    putDeviceInfo()
                    callback(nil, true)
                } else {
                    let errorMessage: String = "Sahha Credentials could not be set"
                    Sahha.postError(framework: .ios_swift, message: errorMessage, path: "Sahha", method: "authenticate", body: "hidden")
                    callback(errorMessage, false)
                }
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping (String?, Bool) -> Void) {
        
        if SahhaCredentials.setCredentials(profileToken: profileToken, refreshToken: refreshToken) {
            putDeviceInfo()
            callback(nil, true)
        } else {
            let errorMessage: String = "Sahha Credentials could not be set"
            Sahha.postError(framework: .ios_swift, message: errorMessage, path: "Sahha", method: "authenticate", body: "hidden")
            callback(errorMessage, false)
        }
    }
    
    public static func deauthenticate(callback: @escaping (String?, Bool) -> Void) {
        if SahhaCredentials.deleteCredentials() {
            health.clearAllData()
            callback(nil, true)
            return
        }
        callback("Sahha | Deauthenticate method failed", false)
    }
    
    // MARK: - Device Info
    
    private static func checkDeviceInfo() {
        if SahhaCredentials.isAuthenticated {
            if SahhaStorage.sdkVersion.getValue != SahhaConfig.sdkVersion || SahhaStorage.appVersion.getValue != SahhaConfig.appVersion || SahhaStorage.systemVersion.getValue != SahhaConfig.systemVersion || SahhaStorage.timeZone.getValue != SahhaConfig.timeZone {
                putDeviceInfo()
            }
        }
    }
    
    private static func putDeviceInfo() {
        let body = SahhaErrorModel(sdkId: settings.framework.rawValue, sdkVersion: SahhaConfig.sdkVersion, appId: SahhaConfig.appId, appVersion: SahhaConfig.appVersion, deviceType: SahhaConfig.deviceType, deviceModel: SahhaConfig.deviceModel, system: SahhaConfig.system, systemVersion: SahhaConfig.systemVersion, timeZone: SahhaConfig.timeZone)
        APIController.putDeviceInfo(body: body) { result in
            switch result {
            case .success(_):
                // Save the latest values
                SahhaStorage.sdkVersion.setValue(SahhaConfig.sdkVersion)
                SahhaStorage.appVersion.setValue(SahhaConfig.appVersion)
                SahhaStorage.systemVersion.setValue(SahhaConfig.systemVersion)
                SahhaStorage.timeZone.setValue(SahhaConfig.timeZone)
            case .failure(let error):
                print(error.message)
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
        APIController.patchDemographic(body: demographic) { result in
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
    
    public static func getSensorStatus(callback: @escaping (String?, SahhaSensorStatus)->Void) {
        health.checkAuthorization { error, status in
            callback(error, status)
        }
    }
    
    public static func enableSensors(callback: @escaping (String?, SahhaSensorStatus)->Void) {
        health.activate { error, status in
            callback(error, status)
        }
    }
    
    // MARK: - Analyzation
    
    public static func analyze(dates:(startDate: Date, endDate: Date)? = nil, callback: @escaping (String?, String?) -> Void) {
        APIController.getAnalysis(body: AnalysisRequest(startDate: dates?.startDate, endDate: dates?.endDate)) { result in
            switch result {
            case .success(let response):
                if let object = try? JSONSerialization.jsonObject(with: response.data, options: []),
                   let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
                   let prettyPrintedString = String(data: data, encoding: .utf8) {
                    callback(nil, prettyPrintedString)
                } else {
                    Sahha.postError(message: "Analyzation data encoding error", path: "Sahha", method: "analyze", body: "if let object = try? JSONSerialization.jsonObject")
                    callback("Analyzation data encoding error", nil)
                }
            case .failure(let error):
                callback(error.message, nil)
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
    
    // MARK: - Test
    
    public static func testData() {
        health.clearTestData()
        health.postSensorData(healthType: .active_energy_burned)
    }
    
    // MARK: - Errors
    
    public static func postError(framework: SahhaFramework = .ios_swift, message: String, path: String, method: String, body: String) {
        let error = SahhaErrorModel(errorLocation: framework.rawValue, errorMessage: message, codePath: path, codeMethod: method, codeBody: body)
        APIController.postError(error, source: .app)
    }
}

