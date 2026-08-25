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
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let dayCellHeight: CGFloat = 34

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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("이번 달")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)

                Spacer()

                Text(rateText)
                    .font(DesignTokens.Typography.headline)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.Color.accent)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(DesignTokens.Typography.captionStrong)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankDayCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: dayCellHeight)
                }

                ForEach(monthDays) { day in
                    CalendarDayCell(day: day, height: dayCellHeight)
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let day: HabitCalendarDay
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundStyle)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderStyle, lineWidth: borderWidth)
                }

            Text("\(day.dayNumber)")
                .font(DesignTokens.Typography.captionStrong)
                .monospacedDigit()
                .foregroundStyle(foregroundStyle)
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundStyle: Color {
        switch day.status {
        case .completed:
            DesignTokens.Color.accent.opacity(0.86)
        case .missed:
            DesignTokens.Color.missed.opacity(0.72)
        case .pending:
            .clear
        case .future:
            .clear
        }
    }

    private var foregroundStyle: Color {
        switch day.status {
        case .completed:
            .white
        case .missed:
            DesignTokens.Color.textSecondary.opacity(0.78)
        case .pending:
            DesignTokens.Color.accent
        case .future:
            DesignTokens.Color.textSecondary.opacity(0.45)
        }
    }

    private var borderStyle: Color {
        switch day.status {
        case .completed:
            DesignTokens.Color.accent.opacity(0.86)
        case .pending:
            DesignTokens.Color.accent.opacity(0.72)
        case .missed:
            DesignTokens.Color.hairline.opacity(0.70)
        case .future:
            .clear
        }
    }

    private var borderWidth: CGFloat {
        day.status == .pending ? 1.5 : 1
    }

    private var accessibilityLabel: String {
        "\(day.dateKey), \(day.status.rawValue)"
    }
}

#Preview {
    CalendarMonthView(records: [], now: Date())
}
