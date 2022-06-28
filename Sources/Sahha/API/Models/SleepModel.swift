// 

import Foundation

enum SleepStage: String {
    case unknown = "unknown"
    case inBed = "in bed"
    case asleep = "asleep"
    case awake = "awake"
}

struct SleepRequest: Encodable, Hashable {
    var sleepStage: String
    var durationInMinutes: Int
    var source: String
    var manuallyEntered: Bool
    var startDateTime: String
    var endDateTime: String
    var createdAt: String
    
    init(stage: SleepStage, source: String, manuallyEntered: Bool, startDate: Date, endDate: Date) {
        self.sleepStage = stage.rawValue
        self.source = source
        self.manuallyEntered = manuallyEntered
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.durationInMinutes = difference.minute ?? 0
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}
