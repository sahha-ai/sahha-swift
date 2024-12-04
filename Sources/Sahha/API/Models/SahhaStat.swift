// Copyright © 2024 Sahha. All rights reserved.
import Foundation

public enum SahhaStatInterval: String  {
    case hour
    case day
}

public struct SahhaStat: Comparable {
    public var id: String
    public var sensor: SahhaSensor
    public var value: Double
    public var unit: String
    public var startDate: Date
    public var endDate: Date
    
    public init(id: String, sensor: SahhaSensor, value: Double, unit: String, startDate: Date, endDate: Date) {
        self.id = id
        self.sensor = sensor
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
    }
    
    public static func < (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value < rhs.value
    }
    
    public static func > (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value > rhs.value
    }
}
