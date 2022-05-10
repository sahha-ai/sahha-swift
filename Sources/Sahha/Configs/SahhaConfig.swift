// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI

public enum SahhaEnvironment: String {
    case development
    case production
}

public enum SahhaFramework: String {
    case android_kotlin
    case ios_swift
    case react_native
    case flutter
    case capacitor
    case cordova
}

public enum SahhaSensor: String, CaseIterable {
    case sleep
    case pedometer
    case device
}

public enum SahhaSensorStatus: Int {
    case pending /// Sensor data is pending User permission
    case unavailable /// Sensor data is not supported by the User's device
    case disabled /// Sensor data has been disabled by the User
    case enabled /// Sensor data has been enabled by the User

    public var description: String {
        String(describing: self)
    }
}

class SahhaConfig {

    init() {
    }
    
    static var appAnalyticsKey: String {
        switch Sahha.settings.environment {
        case .production:
            return "f71d21ca-e775-4e37-8f77-27f65e548d17"
        case .development:
            return "7af31263-6536-4010-8bd8-3fa49c6089f6"
        }
    }
    
    static var apiBasePath: String {
        switch Sahha.settings.environment {
        case .production:
            return "https://api.sahha.ai/api/v1/"
        case .development:
            return "https://sandbox-api.sahha.ai/api/v1/"
        }
    }
    
    static let sdkVersion: String = "0.0.2"
    
    static let appId: String = Bundle.main.bundleIdentifier ?? ""
            
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        
    static let deviceType: String = UIDevice.current.model

    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        } ?? ""
        return modelCode
    }
    
    static let system = UIDevice.current.systemName
    
    static let systemVersion = UIDevice.current.systemVersion
}
