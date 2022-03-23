// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public class Sahha {
    public static var health = HealthActivity()
    public static var motion = MotionActivity()
    
    public private(set) static var text = "Hello, Swifty People!"
    public private(set) static var bundleId = Bundle.main.bundleIdentifier ?? "Unknown"
    
    private init() {
        print("Sahha init")
    }

    public static func configure() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(Sahha.onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        
        Credentials.getCredentials()
        
        health.configure()
        
        motion.configure()
        
        print("Sahha ready")
    }
    
    @objc static private func onAppOpen() {
        print("Sahha open")
    }
    
    @objc static private func onAppClose() {
        print("Sahha close")
    }
    
    public static func getBundleId() -> String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    public static func authenticate(customerId: String, profileId: String, callback: @escaping (String?, String?) -> Void) {
        /*
        APIController.postAuthentication(body: AuthenticationRequest(customerId: customerId, profileId: profileId)) { result in
            switch result {
            case .success(let response):
                callback(response.token)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        */
        APIController.postAuthentication(customerId: customerId, profileId: profileId) { result in
            switch result {
            case .success(let response):
                Credentials.setCredentials(customer: customerId, profile: profileId, token: response.token)
                callback(nil, response.token)
            case .failure(let error):
                print(error.localizedDescription)
                callback(error.localizedDescription, nil)
            }
        }
    }
    
    // MARK: Credentials
    
    public static func getCredentials() -> (customerId: String, profileId: String, token: String) {
        return (Credentials.customerId ?? "", Credentials.profileId ?? "", Credentials.token ?? "")
    }
    
    public static func authenticate(customerId: String, profileId: String, token: String) {
        Credentials.setCredentials(customer: customerId, profile: profileId, token: token)
    }
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
    public static func deleteCredentials() {
        Credentials.deleteCredentials()
    }
    
    public static func analyze() -> String {
        return "";
    }
}

