//
//  HeartModel.swift
//
//  Copyright © 2023 Sahha. All rights reserved.
//  Created by Matthew on 11/29/23.
//

import Foundation

struct HeartRequest: Encodable {
    var dataType: String
    var count: Double
    var unit: String?
    var source: String
    var recordingMethod: String
    var deviceType: String
    var startDateTime: String
    var endDateTime: String
    
    init(dataType: String, count: Double, unit: String?, source: String, recordingMethod: String, deviceType: String, startDate: Date, endDate: Date) {
        self.dataType = dataType
        self.count = count
        if let string = unit {
            self.unit = string
        }
        self.source = source
        self.recordingMethod = recordingMethod
        self.deviceType = deviceType
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
    }
}
