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

fileprivate var dateTimeFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSZZZZZ" // Example: "2021-10-27T16:34:06-06:00"
    return dateFormatter
}

fileprivate var utcOffsetFormatter: DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "ZZZZZ" // Example: "-06:00"
    return dateFormatter
}

extension Date {
    var toDateTime: String {
        return dateTimeFormatter.string(from: self)
    }
    var toUTCOffsetFormat: String {
        return utcOffsetFormatter.string(from: self)
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
