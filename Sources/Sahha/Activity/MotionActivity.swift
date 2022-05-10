// Copyright © 2022 Sahha. All rights reserved.

import SwiftUI
import CoreMotion

public class MotionActivity {
    
    private let movementKey = "movementActivityDate"
    private let pedometerKey = "pedometerActivityDate"
    
    internal private(set) var activityStatus: SahhaSensorStatus = .pending
    public private(set) var activityHistory: [CMPedometerData] = []

    private let activitySensors: Set<SahhaSensor> = [.pedometer]
    private var enabledSensors: Set<SahhaSensor> = []
    private let pedometer: CMPedometer = CMPedometer()
    private let isAvailable: Bool = CMPedometer.isStepCountingAvailable()
    
    internal init() {
        print("Sahha | Motion init")
        //UserDefaults.standard.removeObject(forKey: movementKey)
        //UserDefaults.standard.removeObject(forKey: pedometerKey)
    }
    
    internal func configure(sensors: Set<SahhaSensor>) {
        enabledSensors = activitySensors.intersection(sensors)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppOpen), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onAppClose), name: UIApplication.willResignActiveNotification, object: nil)
        
        print("Sahha | Motion configured")
    }
    
    @objc private func onAppOpen() {
        checkAuthorization { [weak self] _ in
            if Sahha.settings.postSensorDataManually == false {
                self?.postSensorData(.pedometer)
            }
        }
    }
    
    @objc private func onAppClose() {
    }
    
    private func checkAuthorization(_ callback: ((SahhaSensorStatus)->Void)? = nil) {
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
        print("Sahha | Motion activity status : \(activityStatus.description)")
        callback?(activityStatus)
    }
    
    /// Activate Motion - callback with result of change to ActivityStatus
    public func activate(_ callback: @escaping (SahhaSensorStatus)->Void) {
        
        guard activityStatus == .pending else {
            callback(activityStatus)
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.pedometer.queryPedometerData(from: Date(), to: Date()) {[weak self] data, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Sahha | Pedometer error")
                        print(error.localizedDescription)
                    }
                    self?.checkAuthorization({ newStatus in
                        callback(newStatus)
                    })
                }
            }
        }
    }
    
    internal func postSensorData(_ sensor: SahhaSensor, callback:((_ error: String?, _ success: Bool)-> Void)? = nil) {
        
        guard enabledSensors.contains(sensor) else {
            callback?("Sahha | \(sensor.rawValue) sensor is missing from Sahha.configure()", false)
            return
        }
        
        guard activityStatus == .enabled else {
            callback?("Sahha | Motion activity is not enabled", false)
            return
        }
        
        switch sensor {
        case .pedometer:
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
                    callback?("Sahha | No new Motion activity since last post", false)
                }
            }
        default:
            callback?("Sahha | \(sensor.rawValue) sensor is not available", false)
        }
    }
    
    private func getPedometerHistoryData(callback: @escaping ([CMPedometerData])->Void) {
        if activityStatus == .enabled {
            let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let lastDate = UserDefaults.standard.date(forKey: pedometerKey) ?? lastWeek
            let numberOfMinutes = Calendar.current.dateComponents([.minute], from: lastDate, to: Date()).minute ?? 0
            guard numberOfMinutes > 360 else {
                // Minimum of 6 hours between history checks
                callback([])
                return
            }
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
            // TODO: post to API
            // Save date key
            UserDefaults.standard.set(date: Date(), forKey: pedometerKey)
            callback?(nil, true)
        }
    }
}
