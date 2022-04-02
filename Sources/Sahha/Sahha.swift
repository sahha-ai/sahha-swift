// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public struct SahhaSettings {
    public let environment: SahhaEnvironment
    public let sensors: Set<SahhaSensor>
    public let postActivityManually: Bool
    
    public init(environment: SahhaEnvironment, sensors: Set<SahhaSensor>? = nil, postActivityManually: Bool? = nil) {
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
        self.postActivityManually = postActivityManually ?? false
    }
}

public class Sahha {
    public static var settings = SahhaSettings(environment: .development)
    public static var health = HealthActivity()
    public static var motion = MotionActivity()
    
    private init() {
        print("Sahha | SDK init")
    }

    /** Configure the Sahha SDK
    - Parameters:
    - environment: SahhaEnvironment // Development or Production
    - sensors: Set<SahhaSensor> = [.sleep, .pedometer, .device] // A list of sensors to monitor
    - postActivityManually: Bool = false // Override Sahha automatic data collection
     */
    public static func configure(_ settings: SahhaSettings
    ) {
        Self.settings = settings
        
        Credentials.getCredentials()
        
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
    
    public static func authenticate(customerId: String, profileId: String, callback: @escaping (String?, String?) -> Void) {
        APIController.postAuthentication(customerId: customerId, profileId: profileId) { result in
            switch result {
            case .success(let response):
                Credentials.setCredentials(customer: customerId, profile: profileId, token: response.token)
                callback(nil, "Sahha authorization success")
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Profile
    
    /*
    public static func getProfile(profileId: String, onComplete: @escaping (Result<ProfileResponse, ApiError>) -> Void) {
        APIController.getProfile(profileId: profileId) { result in
            
        }
    }
    
    public static func setProfile() {
        APIController.postDemographic(body: <#T##DemographicRequest#>) { <#Result<EmptyResponse, ApiError>#> in
            <#code#>
        }
    }
    */
    
    // MARK: - Analyzation
    
    public static func analyze(callback: @escaping (String?, String?) -> Void) {
        APIController.getAnalyzation { result in
            switch result {
            case .success(let response):
                do {
                    let jsonEncoder = JSONEncoder()
                    jsonEncoder.outputFormatting = .prettyPrinted
                    let jsonData = try jsonEncoder.encode(response)
                    let jsonString = String(data: jsonData, encoding: .utf8)
                    callback(nil, jsonString)
                } catch {
                    callback("Analyzation data encoding error", nil)
                }
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    public static func openAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:]) { _ in
        }
    }
}

