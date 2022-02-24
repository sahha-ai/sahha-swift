//
//  MovementModel.swift
//  
//
//  Created by Matthew on 2/11/22.
//

import Foundation
import CoreMotion.CMMotionActivity

// movement type: (0) standing, (1) walking, (2) running, (3) cycling, or (4) driving

enum MovementTypeIdentifer: Int {
    case standing = 0
    case walking = 1
    case running = 2
    case cycling = 3
    case driving = 4
}

struct MovementRequest: Encodable {
    var movementType: Int
    var confidence: Double
    var startDateTime: String
    
    init(item: CMMotionActivity) {
        if item.stationary {
            self.movementType = MovementTypeIdentifer.standing.rawValue
        } else if item.walking {
            self.movementType = MovementTypeIdentifer.walking.rawValue
        } else if item.running {
            self.movementType = MovementTypeIdentifer.running.rawValue
        } else if item.cycling {
            self.movementType = MovementTypeIdentifer.cycling.rawValue
        } else if item.automotive {
            self.movementType = MovementTypeIdentifer.driving.rawValue
        } else {
            self.movementType = 0
        }
        switch item.confidence {
        case .low:
            self.confidence = 25
        case .medium:
            self.confidence = 50
        case .high:
            self.confidence = 75
        default:
            self.confidence = 0
        }
        self.startDateTime = item.startDate.toTimezoneFormat
    }
}
