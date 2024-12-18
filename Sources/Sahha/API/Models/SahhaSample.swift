//
//  SahhaSample.swift
//  Sahha
//
//  Created by Matthew on 2024-12-18.
//
import Foundation

public struct SahhaSample: Comparable, Codable {
    public var id: String
    public var type: String
    public var value: Double
    public var unit: String
    public var startDate: Date
    public var endDate: Date
    public var source: String
    
    public init(id: String, type: String, value: Double, unit: String, startDate: Date, endDate: Date, source: String) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit
        self.startDate = startDate
        self.endDate = endDate
        self.source = source
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encode(startDate.toDateTime, forKey: .startDate)
        try container.encode(endDate.toDateTime, forKey: .endDate)
        try container.encode(source, forKey: .source)
    }
    
    public static func < (lhs: SahhaSample, rhs: SahhaSample) -> Bool {
        return lhs.startDate < rhs.startDate
    }
    
    public static func > (lhs: SahhaSample, rhs: SahhaSample) -> Bool {
        return lhs.endDate > rhs.endDate
    }
}
