//
//  DateService.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import Foundation

nonisolated struct DateService {
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

    func dateTime(for dateKey: String, hour: Int, minute: Int) -> Date? {
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
            day: day,
            hour: hour,
            minute: minute
        ))
    }

    func dateComponents(for dateKey: String, hour: Int, minute: Int) -> DateComponents? {
        guard let date = dateTime(for: dateKey, hour: hour, minute: minute) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
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

    func monthDateKeys(containing date: Date) -> [String] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return []
        }

        return dayRange.compactMap { day -> String? in
            guard let monthDate = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else {
                return nil
            }

            return dateKey(for: monthDate)
        }
    }

    func dayNumber(for dateKey: String) -> Int? {
        guard let date = date(from: dateKey) else {
            return nil
        }

        return calendar.component(.day, from: date)
    }

    func monthTitle(containing date: Date) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year,
              let month = components.month else {
            return ""
        }

        return String(format: "%04d.%02d", year, month)
    }

    func leadingBlankDayCount(containing date: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return 0
        }

        let weekday = calendar.component(.weekday, from: interval.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    func compare(_ leftDateKey: String, _ rightDateKey: String) -> ComparisonResult? {
        guard let leftDate = date(from: leftDateKey),
              let rightDate = date(from: rightDateKey) else {
            return nil
        }

        return calendar.compare(leftDate, to: rightDate, toGranularity: .day)
    }
}

nonisolated extension Calendar {
    static var devStreakCurrent: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }
}
