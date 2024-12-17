// Copyright © 2024 Sahha. All rights reserved.
import Foundation

public enum SahhaStatInterval: String  {
    case hour
    case day
}

public struct SahhaStat: Comparable, Codable {
    public var id: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDate: Date
    public var endDate: Date
    public var sources: [String]
    
    public init(id: String, type: String, value: Double, unit: String, startDate: Date, endDate: Date, sources: [String]) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.sources = sources
        print(self.type, startDate.toDateTime, endDate.toDateTime, "\(value)", sources)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(startDate.toDateTime, forKey: .startDate)
        try container.encode(endDate.toDateTime, forKey: .endDate)
        try container.encode(sources, forKey: .sources)
    }
    
    public static func < (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value < rhs.value
    }
    
    public static func > (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value > rhs.value
    }
}
