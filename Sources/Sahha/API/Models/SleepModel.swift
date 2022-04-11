// 

import Foundation

struct SleepRequest: Encodable {
    var minutesSlept: Int
    var startDateTime: String
    var endDateTime: String
    var createdAt: String
    
    init(startDate: Date, endDate: Date) {
        let difference = Calendar.current.dateComponents([.minute], from: startDate, to: endDate)
        self.minutesSlept = difference.minute ?? 0
        self.startDateTime = startDate.toTimezoneFormat
        self.endDateTime = endDate.toTimezoneFormat
        self.createdAt = Date().toTimezoneFormat
    }
}
