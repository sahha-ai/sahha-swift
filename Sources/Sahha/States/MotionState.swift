// Copyright © 2022 Sahha. All rights reserved.

import Foundation
import CoreMotion

fileprivate let movementKey = "movementActivityDate"
fileprivate let pedometerKey = "pedometerActivityDate"

class MotionState: NSObject, ObservableObject {
    var isAvailable: Bool = false
    var isAuthorized: Bool = false
    var isDenied: Bool = false
    
    private let motionManager: CMMotionManager = CMMotionManager()
    private let motionActivityManager: CMMotionActivityManager = CMMotionActivityManager()
    private let pedometer: CMPedometer = CMPedometer()
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    @discardableResult func checkAuthorization() -> Bool {
        isAvailable = CMMotionActivityManager.isActivityAvailable() && CMPedometer.isStepCountingAvailable()
        isAuthorized = CMMotionActivityManager.authorizationStatus() == .authorized
        isDenied = CMMotionActivityManager.authorizationStatus() == .denied || CMMotionActivityManager.authorizationStatus() == .restricted
        return isAuthorized
    }
    
    func requestPermission() {
        // Trigger permissions dialogue
        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            // Stop tracking
            self?.motionActivityManager.stopActivityUpdates()
        }
    }
    
    func checkHistory() {
        getMovementHistoryData() { [weak self] data in
            var requests: [MovementRequest] = []
            var lastRequest: MovementRequest?
            for item in data {
                let request = MovementRequest(item: item)
                if request.movementType >= 0 {
                    if request.movementType > 0 || request.movementType != lastRequest?.movementType ?? -1 {
                        // Add unique stationary movements and all active movements
                        requests.append(request)
                        lastRequest = request
                    }
                }
            }
            if requests.isEmpty == false {
                // post data
            }
        }
        getPedometerHistoryData { [weak self] data in
            var requests: [PedometerRequest] = []
            for item in data {
                let request = PedometerRequest(item: item)
                requests.append(request)
            }
            if requests.isEmpty == false {
                // post data
            }
        }
    }
    
    private func getMovementHistoryData(callback: @escaping ([CMMotionActivity])->Void) {
        if isAvailable, isAuthorized {
            let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let lastDate = UserDefaults.standard.date(forKey: movementKey) ?? lastWeek
            let numberOfDays = Calendar.current.dateComponents([.day], from: lastDate, to: lastWeek).day ?? 0
            let date = numberOfDays > 0 ? lastWeek : lastDate
            if Calendar.current.isDateInToday(date) == false {
                motionActivityManager.queryActivityStarting(from: date, to: Date(), to: .main) { data, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print(error.localizedDescription)
                            callback([])
                            return
                        }
                        if let data = data {
                            callback(data)
                            return
                        }
                        callback([])
                        return
                    }
                }
            }
        }
    }
    
    private func getPedometerHistoryData(callback: @escaping ([CMPedometerData])->Void) {
        if CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() == .authorized {
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
    
    private func postMovementRange(data: [MovementRequest]) {
        if data.count > 1000 {
            // Split elements and post
            let newData = Array(data.prefix(1000))
            postMovementRange(data: newData)
            // Remove elements and recurse
            let oldData = Array(data[newData.count..<data.count])
            postMovementRange(data: oldData)
        } else {
            // fill in
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
