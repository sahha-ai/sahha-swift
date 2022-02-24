//
//  PedometerModel.swift
//  
//
//  Created by Matthew on 2/11/22.
//

import Foundation
import CoreMotion.CMPedometer

struct PedometerRequest: Encodable {
    var steps: Int
    var floorsAscended: Int
    var floorsDescended: Int
    var distance: Double
    var currentPace: Double
    var averagePace: Double
    var currentCadence: Double
    var startDateTime: String
    var endDateTime: String
    var createdAt: String
    
    init(item: CMPedometerData) {
        self.steps = Int(item.numberOfSteps)
        self.floorsAscended = Int(item.floorsAscended ?? 0)
        self.floorsDescended = Int(item.floorsDescended ?? 0)
        self.distance = Double(item.distance ?? 0)
        self.currentPace = Double(item.currentPace ?? 0)
        self.averagePace = Double(item.averageActivePace ?? 0)
        self.currentCadence = Double(item.currentCadence ?? 0)
        self.startDateTime = item.startDate.toTimezoneFormat
        self.endDateTime = item.endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}
