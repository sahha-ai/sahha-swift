// Copyright © 2022 Sahha. All rights reserved.

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
        self.steps = Int(truncating: item.numberOfSteps)
        self.floorsAscended = Int(truncating: item.floorsAscended ?? 0)
        self.floorsDescended = Int(truncating: item.floorsDescended ?? 0)
        self.distance = Double(truncating: item.distance ?? 0)
        self.currentPace = Double(truncating: item.currentPace ?? 0)
        self.averagePace = Double(truncating: item.averageActivePace ?? 0)
        self.currentCadence = Double(truncating: item.currentCadence ?? 0)
        self.startDateTime = item.startDate.toTimezoneFormat
        self.endDateTime = item.endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}
