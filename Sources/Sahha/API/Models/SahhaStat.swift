// Copyright © 2024 Sahha. All rights reserved.
import Foundation

public enum SahhaStatInterval: String  {
    case hour
    case day
}

public struct SahhaStat: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var aggregation: String
    public var periodicity: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var sources: [String]
    
    public init(id: String, category: String, type: String, aggregation: String, periodicity: String, value: Double, unit: String, startDateTime: Date, endDateTime: Date, sources: [String]) {
        self.id = id
        self.category = category
        self.type = type
        self.aggregation = aggregation
        self.periodicity = periodicity
        self.value = value
        self.unit = unit
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.sources = sources
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encode(startDateTime.toDateTime, forKey: .startDateTime)
        try container.encode(endDateTime.toDateTime, forKey: .endDateTime)
        try container.encode(sources, forKey: .sources)
    }
    
    public static func < (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value < rhs.value
    }
    
    public static func > (lhs: SahhaStat, rhs: SahhaStat) -> Bool {
        return lhs.value > rhs.value
    }
}
