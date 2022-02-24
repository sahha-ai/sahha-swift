//
//  HealthModel.swift
//  
//
//  Created by Matthew on 2/11/22.
//

import Foundation

enum HealthTypeIdentifer: String {
    case timeAsleep
    case timeInBed
    case stepCount
    case flightsClimbed
    case distanceWalkingRunning
    case walkingSpeed
    case walkingDoubleSupportPercentage
    case walkingAsymmetryPercentage
    case walkingStepLength
}

struct HealthTypeRequest: Encodable {
    var dataType: String
    var details: [HealthRequest]
    
    init(_ identifier: HealthTypeIdentifer, value: [HealthRequest]) {
        self.dataType = identifier.rawValue
        self.details = value
    }
}

struct HealthRequest: Encodable {
    var count: Double
    var startDateTime: String
    var endDateTime: String
    var createdAt: String
    
    init(count: Double, startDate: Date, endDate: Date) {
        self.count = count
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}

