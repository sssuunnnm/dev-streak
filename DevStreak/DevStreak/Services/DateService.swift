//
//  DateService.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import Foundation

struct DateService {
    var calendar: Calendar

    init(calendar: Calendar = .devStreakCurrent) {
        self.calendar = calendar
    }

    func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func todayKey(now: Date = .now) -> String {
        dateKey(for: now)
    }

    func date(from dateKey: String) -> Date? {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        ))
    }

    func addingDays(_ days: Int, to dateKey: String) -> String? {
        guard let date = date(from: dateKey),
              let adjustedDate = calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }

        return self.dateKey(for: adjustedDate)
    }

    func isPreviousDay(_ previous: String, before current: String) -> Bool {
        addingDays(1, to: previous) == current
    }
}

extension Calendar {
    static var devStreakCurrent: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
