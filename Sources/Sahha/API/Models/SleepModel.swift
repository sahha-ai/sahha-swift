// 

import Foundation

enum SleepStage: String {
    case inBed = "in bed"
    case asleep = "asleep"
    case awake = "awake"
}

struct SleepRequest: Encodable, Hashable {
    var sleepStage: String
    var durationInMinutes: Int
    var startDateTime: String
    var endDateTime: String
    var createdAt: String
    
    init(stage: SleepStage, startDate: Date, endDate: Date) {
        sleepStage = stage.rawValue
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.durationInMinutes = difference.minute ?? 0
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}
