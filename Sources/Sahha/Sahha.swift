import SwiftUI
import UIKit

public class Sahha {
    private var healthState = HealthState()
    private var motionState = MotionState()
    
    public static var shared = Sahha()
    
    public private(set) var text = "Hello, Swifty People!"
    public private(set) var bundleId = Bundle.main.bundleIdentifier ?? "Unknown"
    
    private init() {
        print("sahha")
        let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(activate), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(deactivate), name: UIApplication.willResignActiveNotification, object: nil)
    }

    public func setup() {
        // force init of shared instance
        print("setup")
    }
    
    @objc private func activate() {
        print("Sahha activate")
    }
    
    @objc private func deactivate() {
        print("Sahha deactivate")
    }
    
    public func getBundleId() -> String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }
}

