//
//  SahhaSample.swift
//  Sahha
//
//  Created by Matthew on 2024-12-18.
//
import Foundation

public struct SahhaSample: Comparable, Codable {
    public var id: String
    public var category: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDateTime: Date
    public var endDateTime: Date
    public var recordingMethod: String
    public var source: String
    public var stats: [SahhaStat]
    
    public init(id: String, category: String, type: String, value: Double, unit: String, startDateTime: Date, endDateTime: Date, recordingMethod: String, source: String, stats: [SahhaStat] = []) {
        self.id = id
        self.category = category
        self.type = type
        self.value = value
        self.unit = unit
        self.startDateTime = startDateTime
        self.endDateTime = endDateTime
        self.recordingMethod = recordingMethod
        self.source = source
        self.stats = stats
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
        try container.encode(recordingMethod, forKey: .recordingMethod)
        try container.encode(source, forKey: .source)
        try container.encode(stats, forKey: .stats)
    }
    
    public static func < (lhs: SahhaSample, rhs: SahhaSample) -> Bool {
        return lhs.startDateTime < rhs.startDateTime
    }
    
    public static func > (lhs: SahhaSample, rhs: SahhaSample) -> Bool {
        return lhs.startDateTime > rhs.startDateTime
    }
}
