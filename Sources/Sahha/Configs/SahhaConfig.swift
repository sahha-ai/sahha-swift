// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI

public enum SahhaEnvironment: String {
    case development
    case sandbox
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
    case gender
    case date_of_birth
    case sleep
    case steps
    case floors_climbed
    case running_speed
    case running_power
    case running_ground_contact_time
    case running_stride_length
    case running_vertical_oscillation
    case six_minute_walk_test_distance
    case stair_ascent_speed
    case stair_descent_speed
    case walking_speed
    case walking_steadiness
    case walking_asymmetry_percentage
    case walking_double_support_percentage
    case walking_step_length
    case heart_rate
    case resting_heart_rate
    case walking_heart_rate_average
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case blood_glucose
    case vo2_max
    case oxygen_saturation
    case respiratory_rate
    case active_energy_burned
    case basal_energy_burned
    case total_energy_burned
    case basal_metabolic_rate
    case time_in_daylight
    case body_temperature
    case basal_body_temperature
    case sleeping_wrist_temperature
    case height
    case weight
    case lean_body_mass
    case body_mass_index
    case body_fat
    case body_water_mass
    case bone_mass
    case waist_circumference
    case stand_time
    case move_time
    case exercise_time
    case activity_summary
    case device_lock
    case exercise
    case energy_consumed
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
    
    static var apiBasePath: String {
        switch Sahha.settings?.environment ?? .sandbox {
        case .production:
            return "https://api.sahha.ai/api/v1/"
        case .sandbox:
            return "https://sandbox-api.sahha.ai/api/v1/"
        case .development:
            return "https://development-api.sahha.ai/api/v1/"
        }
    }
    
    static let sdkVersion: String = "1.2.3"
    
    static let appId: String = Bundle.main.bundleIdentifier ?? ""
            
    static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    
    static var deviceId: String {
        if let uuid = UIDevice.current.identifierForVendor?.uuidString {
            return uuid
        } else if let uuid = UserDefaults.standard.string(forKey: "deviceId") {
            return uuid
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.set(uuid, forKey: "deviceId")
            return uuid
        }
    }
        
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
    
    static var timeZone = Date().toUTCOffsetFormat
}
