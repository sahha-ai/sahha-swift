// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import CoreMotion

fileprivate let pedometerKey = "pedometerActivityDate"

public class MotionActivity {
    
    public private(set) var activityStatus: SahhaActivityStatus = .pending
    public private(set) var activityHistory: [CMPedometerData] = []

    private let activitySensors: Set<SahhaSensor> = [.pedometer]
    private var enabledSensors: Set<SahhaSensor> = []
    private let pedometer: CMPedometer = CMPedometer()
    private let isAvailable: Bool = CMPedometer.isStepCountingAvailable()
    private var activationCallback: ((SahhaActivityStatus)-> Void)?
    
    init() {
        print("motion init")
    }
    
    func configure(sensors: Set<SahhaSensor>) {
        print("motion configure")
        enabledSensors = activitySensors.intersection(sensors)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc private func onAppOpen() {
        print("motion open")
        checkAuthorization { [weak self] newStatus in
            if let callback = self?.activationCallback {
                callback(newStatus)
                self?.activationCallback = nil
            }
            if SahhaConfig.postActivityManually == false {
                self?.postActivity()
            }
        }
    }
    
    @objc private func onAppClose() {
        print("motion close")
    }
    
    private func checkAuthorization(_ callback: ((SahhaActivityStatus)->Void)? = nil) {
        if isAvailable {
            switch CMPedometer.authorizationStatus() {
            case .authorized:
                activityStatus = .enabled
            case .restricted, .denied:
                activityStatus = .disabled
            default:
                activityStatus = .pending
            }
        }
        else {
            activityStatus = .unavailable
        }
        print("motion status : \(activityStatus.description)")
        callback?(activityStatus)
    }
    
    /// Activate Motion - callback with result of change to ActivityStatus
    public func activate(_ callback: @escaping (SahhaActivityStatus)->Void) {
        
        guard activityStatus == .pending else {
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
                    self?.checkAuthorization({ newStatus in
                        callback(newStatus)
                    })
                }
            }
        }
    }
    
    public func promptUserToActivate(_ callback: @escaping (SahhaActivityStatus)->Void) {
        if activityStatus == .disabled {
            activationCallback = callback
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:]) { _ in
            }
        } else {
            activate(callback)
        }
    }
    
    public func postActivity(callback:((_ error: String?, _ success: Bool)-> Void)? = nil) {
        guard enabledSensors.contains(.pedometer) else {
            callback?("Pedometer sensor is missing from Sahha.configure()", false)
            return
        }
        guard activityStatus == .enabled else {
            callback?("Motion activity is not enabled", false)
            return
        }
        getPedometerHistoryData { [weak self] data in
            self?.activityHistory = data
            var requests: [PedometerRequest] = []
            for item in data {
                let request = PedometerRequest(item: item)
                requests.append(request)
            }
            if requests.isEmpty == false {
                self?.postPemoterRange(data: requests, callback: callback)
            } else {
                callback?("No new Motion activity since last post", false)
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
    
    private func postPemoterRange(data: [PedometerRequest], callback:((_ error: String?, _ success: Bool)-> Void)? = nil) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postPemoterRange(data: newData)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postPemoterRange(data: oldData, callback: callback)
        } else {
            // fill in
            callback?(nil, true)
        }
    }
}
