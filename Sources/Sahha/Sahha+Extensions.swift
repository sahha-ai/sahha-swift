// Copyright © 2022 Sahha. All rights reserved.

import Foundation

// MARK: UserDefaults

extension UserDefaults {
    func set(date: Date?, forKey key: String){
        self.set(date, forKey: key)
    }
    func date(forKey key: String) -> Date? {
        return self.value(forKey: key) as? Date
    }
}

// MARK: Date

public extension Date {
    var toDateTimeFormat: String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy HH:mm:ss")
        return dateFormatter.string(from: self)
    }
    var toTimezoneFormat: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssxxx" // Example: "2021-10-27T16:34:06-06:00"
        return dateFormatter.string(from: self)
    }
    var toDMYFormat: String {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
        return dateFormatter.string(from: self)
    }
    var toUTCOffsetFormat: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ZZZZZ"
        return dateFormatter.string(from: self)
    }
}

// MARK: Calendar

extension Calendar {
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from) // <1>
        let toDate = startOfDay(for: to) // <2>
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate) // <3>
        
        return numberOfDays.day ?? 0
    }
}
