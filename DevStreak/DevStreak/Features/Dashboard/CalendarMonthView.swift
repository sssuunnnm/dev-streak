//
//  CalendarMonthView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct CalendarMonthView: View {
    let records: [DailyRecord]
    let now: Date

    private let dateService = DateService()
    private let calendarService = HabitCalendarService()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    private var monthDays: [HabitCalendarDay] {
        calendarService.days(containing: now, records: records, now: now)
    }

    private var monthlyRate: MonthlyCompletionRate {
        calendarService.monthlyCompletionRate(containing: now, records: records, now: now)
    }

    private var leadingBlankDayCount: Int {
        dateService.leadingBlankDayCount(containing: now)
    }

    private var rateText: String {
        guard monthlyRate.eligibleDays > 0 else {
            return "0%"
        }

        return monthlyRate.rate.formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateService.monthTitle(containing: now))
                        .font(.headline)

                    Text("\(monthlyRate.completedDays) / \(monthlyRate.eligibleDays) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(rateText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankDayCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(monthDays) { day in
                    CalendarDayCell(day: day)
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let day: HabitCalendarDay

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundStyle)

            Text("\(day.dayNumber)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(foregroundStyle)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundStyle: Color {
        switch day.status {
        case .completed:
            .green
        case .missed:
            .red.opacity(0.15)
        case .pending:
            .blue.opacity(0.18)
        case .future:
            .clear
        }
    }

    private var foregroundStyle: Color {
        switch day.status {
        case .completed:
            .white
        case .missed:
            .red
        case .pending:
            .blue
        case .future:
            .secondary.opacity(0.45)
        }
    }

    private var accessibilityLabel: String {
        "\(day.dateKey), \(day.status.rawValue)"
    }
}

#Preview {
    CalendarMonthView(records: [], now: Date())
}
