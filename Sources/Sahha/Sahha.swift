// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import UIKit

public class Sahha {
    private var healthState = HealthState()
    private var motionState = MotionState()
    
    public private(set) var text = "Hello, Swifty People!"
    public private(set) var bundleId = Bundle.main.bundleIdentifier ?? "Unknown"
    
    private init() {
        print("Sahha init")
    }

    public static func configure() {
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(Sahha.activate), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(Sahha.deactivate), name: UIApplication.willResignActiveNotification, object: nil)
        
        Credentials.getCredentials()
        
        print("Sahha ready")
    }
    
    @objc static private func activate() {
        print("Sahha activate")
    }
    
    @objc static private func deactivate() {
        print("Sahha deactivate")
    }
    
    public func getBundleId() -> String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    public static func authenticate(customerId: String, profileId: String, callback: @escaping (String) -> Void) {
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
                callback(response.token)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK: Credentials
    
    public static func getCredentials() -> (customerId: String, profileId: String, token: String) {
        return (Credentials.customerId ?? "", Credentials.profileId ?? "", Credentials.token ?? "")
    }
    
    public static func setCredentials(customerId: String, profileId: String, token: String) {
        Credentials.setCredentials(customer: customerId, profile: profileId, token: token)
    }
    
    public static func deleteCredentials() {
        Credentials.deleteCredentials()
    }
}

