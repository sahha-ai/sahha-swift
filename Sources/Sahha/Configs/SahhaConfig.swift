// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI

public enum SahhaEnvironment: String {
    case development
    case production
}

public enum SahhaSensor: String, CaseIterable {
    case sleep
    case pedometer
    case device
}

enum SahhaAppInfo: String {
    case sdkVersion
    case deviceModel
    case devicePlatform
    case devicePlatformVersion
}

public enum SahhaActivity: String {
    case motion
    case health
}
    
public enum SahhaError: Error {
    case woops
}

public enum SahhaActivityStatus: Int {
    case pending /// Activity support is pending User permission
    case unavailable /// Activity is not supported by the User's device
    case disabled /// Activity has been disabled by the User
    case enabled /// Activity has been enabled by the User

    public var description: String {
        String(describing: self)
    }
}

class SahhaConfig {

    init() {
    }
    
    static var apiBasePath: String {
        switch Sahha.settings.environment {
        case .production:
            return "https://api.sahha.ai/api/"
        case .development:
            return "https://sandbox-api.sahha.ai/api/"
        }
    }
            
    static let sdkVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    
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
    
    static let devicePlatform = UIDevice.current.systemName
    
    static let devicePlatformVersion = UIDevice.current.systemVersion
}
