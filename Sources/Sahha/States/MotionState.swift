// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import CoreMotion

fileprivate let motionKey = "motionActivityDate"
fileprivate let pedometerKey = "pedometerActivityDate"

public class MotionState {
    
    public enum MotionActivityStatus: Int {
        case unknown /// Motion activity support is unknown
        case unavailable /// Motion activity is not supported by the User's device
        case disabled /// Motion activity has been disabled by the User
        case enabled /// Motion activity has been enabled by the User
    
        public var description: String {
            String(describing: self)
        }
    }
    
    @Published public private(set) var activityStatus: MotionActivityStatus = .unknown
    
    private let pedometer: CMPedometer = CMPedometer()
    private let isAvailable: Bool = CMPedometer.isStepCountingAvailable()
    private var activationCallback: ((MotionActivityStatus)-> Void)?
    
    init() {
        print("motion")
                
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func configure() {
    }
    
    @objc private func onAppOpen() {
        print("motion open")
        checkAuthorization()
        if let callback = activationCallback {
            callback(activityStatus)
            activationCallback = nil
        }
        checkHistory()
    }
    
    private func checkAuthorization() {
        guard isAvailable else {
            activityStatus = .unavailable
            return
        }
        switch CMPedometer.authorizationStatus() {
        case .authorized:
            activityStatus = .enabled
        case .restricted, .denied:
            activityStatus = .disabled
        default:
            activityStatus = .unknown
        }
    }
    
    /// Activate Motion - callback with result of change to MotionActivityStatus
    public func activate(_ callback: @escaping (MotionActivityStatus)->Void) {
        
        guard activityStatus == .unknown else {
            callback(activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.pedometer.queryPedometerData(from: Date(), to: Date()) {[weak self] data, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("bad")
                        print(error.localizedDescription)
                    } else {
                        print("good")
                    }
                    if let self = self {
                        self.checkAuthorization()
                        callback(self.activityStatus)
                    }
                }
            }
        }
    }
    
    public func promptUserToActivate(_ callback: @escaping (MotionActivityStatus)->Void) {
        if activityStatus == .disabled {
            self.activationCallback = callback
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:]) { _ in
            }
        } else {
            callback(activityStatus)
        }
    }
    
    func checkHistory() {
        if activityStatus == .enabled {
            getPedometerHistoryData { [weak self] data in
                var requests: [PedometerRequest] = []
                for item in data {
                    let request = PedometerRequest(item: item)
                    requests.append(request)
                }
                if requests.isEmpty == false {
                    // post data
                    self?.postPemoterRange(data: requests)
                }
            }
        }
    }
    
    private func getPedometerHistoryData(callback: @escaping ([CMPedometerData])->Void) {
        if activityStatus == .enabled {
            let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let lastDate = UserDefaults.standard.date(forKey: pedometerKey) ?? lastWeek
            let numberOfDays = Calendar.current.dateComponents([.day], from: lastDate, to: lastWeek).day ?? 0
            var date = numberOfDays > 0 ? lastWeek : lastDate
            var datas: [CMPedometerData] = []
            var finalCall = false
            while Calendar.current.isDateInToday(date) == false {
                let year = Calendar.current.component(.year, from: date)
                let month = Calendar.current.component(.month, from: date)
                let day = Calendar.current.component(.day, from: date)
                for hour in 0...23 {
                    for quarter in 0...3 {
                        var dateComponents = DateComponents()
                        dateComponents.year = year
                        dateComponents.month = month
                        dateComponents.day =  day
                        dateComponents.hour = hour
                        dateComponents.minute = quarter * 15
                        let startTime = Calendar.current.date(from: dateComponents) ?? Date()
                        let endTime = Calendar.current.date(byAdding: .minute, value: 15, to: startTime) ?? Date()
                        if Calendar.current.isDateInToday(endTime) {
                            finalCall = true
                        }
                        getPedometerHistory(startTime, endTime, finalCall) { value, data in
                            if let data = data {
                                datas.append(data)
                            }
                            if value {
                                callback(datas)
                            }
                        }
                    }
                }
                // increment date
                date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? Date()
            }
        }
    }
    
    private func getPedometerHistory(_ from: Date, _ to: Date, _ final: Bool, callback: @escaping (Bool, CMPedometerData?) -> Void) {
        pedometer.queryPedometerData(from: from, to: to) { data, error in
            if let error = error {
                print(error.localizedDescription)
                callback(final,nil)
            } else if let data = data {
                if data.numberOfSteps.intValue > 0 {
                    callback(final,data)
                } else if let value = data.floorsAscended, value.floatValue > 0 {
                    callback(final,data)
                } else if let value = data.floorsDescended, value.floatValue > 0 {
                    callback(final,data)
                } else {
                    callback(final,nil)
                }
            }
        }
    }
    
    private func postPemoterRange(data: [PedometerRequest]) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postPemoterRange(data: newData)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postPemoterRange(data: oldData)
        } else {
            // fill in
        }
    }
}
