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
    let repositoryCreatedAt: Date?

    @State private var visibleMonth: Date

    private let dateService = DateService()
    private let calendarService = HabitCalendarService()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let dayCellHeight: CGFloat = 34

    init(records: [DailyRecord], now: Date, repositoryCreatedAt: Date? = nil) {
        self.records = records
        self.now = now
        self.repositoryCreatedAt = repositoryCreatedAt
        _visibleMonth = State(initialValue: DateService().startOfMonth(containing: now) ?? now)
    }

    private var monthDays: [HabitCalendarDay] {
        calendarService.days(
            containing: visibleMonth,
            records: records,
            now: now,
            trackingStartDate: repositoryCreatedAt
        )
    }

    private var monthlyRate: MonthlyCompletionRate {
        calendarService.monthlyCompletionRate(
            containing: visibleMonth,
            records: records,
            now: now,
            trackingStartDate: repositoryCreatedAt
        )
    }

    private var leadingBlankDayCount: Int {
        dateService.leadingBlankDayCount(containing: visibleMonth)
    }

    private var currentMonth: Date {
        dateService.startOfMonth(containing: now) ?? now
    }

    private var earliestVisibleMonth: Date {
        let threeYearStart = dateService
            .addingMonths(-36, to: currentMonth)
            .flatMap { dateService.startOfMonth(containing: $0) } ?? currentMonth
        let repositoryCreatedMonth = repositoryCreatedAt
            .flatMap { dateService.startOfMonth(containing: $0) }
        let firstCompletedMonth = records
            .filter { $0.status.isCompleted }
            .compactMap { dateService.date(from: $0.dateKey) }
            .min()
            .flatMap { dateService.startOfMonth(containing: $0) }

        guard let trackingStartMonth = repositoryCreatedMonth ?? firstCompletedMonth else {
            return currentMonth
        }

        return dateService.compareMonth(trackingStartMonth, threeYearStart) == .orderedAscending
            ? threeYearStart
            : trackingStartMonth
    }

    private var isCurrentMonthVisible: Bool {
        dateService.isSameMonth(visibleMonth, currentMonth)
    }

    private var canMoveToPreviousMonth: Bool {
        dateService.compareMonth(visibleMonth, earliestVisibleMonth) == .orderedDescending
    }

    private var titleText: String {
        isCurrentMonthVisible ? "이번 달" : dateService.monthTitle(containing: visibleMonth)
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
                Text(titleText)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)

                Spacer()

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveToPreviousMonth ? DesignTokens.Color.textSecondary : DesignTokens.Color.textSecondary.opacity(0.35))
                .disabled(!canMoveToPreviousMonth)
                .accessibilityLabel("이전 달")

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(!isCurrentMonthVisible ? DesignTokens.Color.textSecondary : DesignTokens.Color.textSecondary.opacity(0.35))
                .disabled(isCurrentMonthVisible)
                .accessibilityLabel("다음 달")

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
        .onChange(of: records.map(\.dateKey)) {
            clampVisibleMonth()
        }
        .onChange(of: dateService.dateKey(for: now)) {
            clampVisibleMonth()
        }
    }

    private func moveMonth(by months: Int) {
        guard let nextMonth = dateService.addingMonths(months, to: visibleMonth) else {
            return
        }

        visibleMonth = clampedMonth(nextMonth)
    }

    private func clampVisibleMonth() {
        visibleMonth = clampedMonth(visibleMonth)
    }

    private func clampedMonth(_ month: Date) -> Date {
        let normalizedMonth = dateService.startOfMonth(containing: month) ?? month

        if dateService.compareMonth(normalizedMonth, currentMonth) == .orderedDescending {
            return currentMonth
        }

        if dateService.compareMonth(normalizedMonth, earliestVisibleMonth) == .orderedAscending {
            return earliestVisibleMonth
        }

        return normalizedMonth
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
        case .pending, .future, .untracked:
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
        case .untracked:
            DesignTokens.Color.textSecondary.opacity(0.30)
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
        case .future, .untracked:
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
