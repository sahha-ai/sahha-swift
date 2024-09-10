// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public struct SahhaSettings {
    public let environment: SahhaEnvironment /// sandbox or production
    public var framework: SahhaFramework = .ios_swift /// automatically set by sdk
    
    public init(environment: SahhaEnvironment) {
        self.environment = environment
    }
}

public class Sahha {
    internal static var appId: String = ""
    internal static var appSecret: String = ""
    internal static var settings: SahhaSettings? = nil
    internal static var health = HealthActivity()
    
    public static func configure(_ settings: SahhaSettings, callback: (() -> Void)? = nil) {
        
        // Check if settings have been set already
        guard Self.settings == nil else {
            
            // Change settings only
            Self.settings = settings
            
            // Avoid configuring SDK twice
            print("Sahha | SDK reconfigured")
            
            // Do optional callback
            callback?()
            return
        }
        
        // Settings are empty - set them and continue with configure
        Self.settings = settings
        
        SahhaCredentials.configure()
        
        health.configure()
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
                
        print("Sahha | SDK configured")
        
        // Do optional callback
        callback?()
        
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
        return SahhaCredentials.token?.profileToken
    }
    
    private static func setToken(_ token: TokenResponse, callback: @escaping (String?, Bool) -> Void) {
        if SahhaCredentials.setToken(token) {
            putDeviceInfo()
            health.querySensors()
            callback(nil, true)
        } else {
            let errorMessage: String = "Sahha Credentials could not be set"
            Sahha.postError(framework: .ios_swift, message: errorMessage, path: "Sahha", method: "authenticate", body: "hidden")
            callback(errorMessage, false)
        }
    }
    
    public static func authenticate(appId: String, appSecret: String, externalId: String, callback: @escaping (String?, Bool) -> Void) {
        
        Self.appId = appId
        Self.appSecret = appSecret
        
        APIController.postProfileToken(body: ProfileTokenRequest(externalId: externalId)) { result in
            switch result {
            case .success(let response):
                setToken(response, callback: callback)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    public static func authenticate(profileToken: String, refreshToken: String, callback: @escaping (String?, Bool) -> Void) {
        
        let token = TokenResponse(profileToken: profileToken, refreshToken: refreshToken)
        setToken(token, callback: callback)
    }
    
    public static func deauthenticate(callback: @escaping (String?, Bool) -> Void) {
        if SahhaCredentials.deleteCredentials() {
            
            health.clearData()
            
            callback(nil, true)
            return
        }
        callback("Sahha | Deauthenticate method failed", false)
    }
    
    // MARK: - Device Info
    
    private static func checkDeviceInfo() {
        if SahhaCredentials.isAuthenticated {
            if SahhaStorage.getValue(.sdkVersion) != SahhaConfig.sdkVersion || SahhaStorage.getValue(.appVersion) != SahhaConfig.appVersion || SahhaStorage.getValue(.systemVersion) != SahhaConfig.systemVersion || SahhaStorage.getValue(.timeZone) != SahhaConfig.timeZone {
                putDeviceInfo()
            }
        }
    }
    
    private static func putDeviceInfo() {
        let body = SahhaErrorModel(sdkId: settings?.framework.rawValue ?? SahhaFramework.ios_swift.rawValue, sdkVersion: SahhaConfig.sdkVersion, appId: SahhaConfig.appId, appVersion: SahhaConfig.appVersion, deviceType: SahhaConfig.deviceType, deviceModel: SahhaConfig.deviceModel, system: SahhaConfig.system, systemVersion: SahhaConfig.systemVersion, timeZone: SahhaConfig.timeZone)
        APIController.putDeviceInfo(body: body) { result in
            switch result {
            case .success(_):
                // Save the latest values
                SahhaStorage.setValue(SahhaConfig.sdkVersion, for: .sdkVersion)
                SahhaStorage.setValue(SahhaConfig.appVersion, for: .appVersion)
                SahhaStorage.setValue(SahhaConfig.systemVersion, for: .systemVersion)
                SahhaStorage.setValue(SahhaConfig.timeZone, for: .timeZone)
            case .failure(let error):
                print(error.message)
            }
        }
    }
    
    // MARK: - Demographic
    
    public static func getDemographic(callback: @escaping (String?, SahhaDemographic?) -> Void) {
        
        if let demographic = SahhaCredentials.getDemographic() {
            callback(nil, demographic)
        } else {
            APIController.getDemographic { result in
                switch result {
                case .success(let response):
                    // Save the result
                    SahhaCredentials.setDemographic(response)
                    callback(nil, response)
                case .failure(let error):
                    print(error.message)
                    callback(error.message, nil)
                }
            }
        }
    }
    
    public static func postDemographic(_ demographic: SahhaDemographic, callback: @escaping (String?, Bool) -> Void) {
        APIController.patchDemographic(body: demographic) { result in
            switch result {
            case .success(_):
                // Save the result
                SahhaCredentials.setDemographic(demographic)
                callback(nil, true)
            case .failure(let error):
                print(error.message)
                callback(error.message, false)
            }
        }
    }
    
    // MARK: - Sensors
    
    public static func getSensorStatus(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        health.getSensorStatus(sensors) { error, status in
            callback(error, status)
        }
    }
    
    public static func enableSensors(_ sensors: Set<SahhaSensor>, callback: @escaping (String?, SahhaSensorStatus)->Void) {
        
        health.enableSensors(sensors) { error, status in
            callback(error, status)
        }
    }
    
    // MARK: - Analyzation
    
    public static func getScores(_ scores: [SahhaScoreTypeIdentifier], dates:(startDate: Date, endDate: Date)? = nil, callback: @escaping (String?, String?) -> Void) {
        APIController.getScores(scores, dates: dates) { result in
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
    
    // MARK: - Errors
    
    public static func postError(framework: SahhaFramework = .ios_swift, message: String, path: String, method: String, body: String) {
        let error = SahhaErrorModel(errorLocation: framework.rawValue, errorMessage: message, codePath: path, codeMethod: method, codeBody: body)
        APIController.postError(error, source: .app)
    }

}

