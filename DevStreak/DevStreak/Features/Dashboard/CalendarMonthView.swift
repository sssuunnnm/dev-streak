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
    let isTrackingEnabled: Bool
    let repositoryCreatedAt: Date?
    let isExpandedLayout: Bool

    @State private var visibleMonth: Date

    private let dateService = DateService()
    private let calendarService = HabitCalendarService()
    private let monthRangePolicy = CalendarMonthRangePolicy()
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]

    init(
        records: [DailyRecord],
        now: Date,
        isTrackingEnabled: Bool = true,
        repositoryCreatedAt: Date? = nil,
        isExpandedLayout: Bool = false
    ) {
        self.records = records
        self.now = now
        self.isTrackingEnabled = isTrackingEnabled
        self.repositoryCreatedAt = repositoryCreatedAt
        self.isExpandedLayout = isExpandedLayout
        _visibleMonth = State(initialValue: DateService().startOfMonth(containing: now) ?? now)
    }

    private var monthDays: [HabitCalendarDay] {
        calendarService.days(
            containing: visibleMonth,
            records: records,
            now: now,
            isTrackingEnabled: isTrackingEnabled,
            trackingStartDate: repositoryCreatedAt
        )
    }

    private var monthlyRate: MonthlyCompletionRate {
        calendarService.monthlyCompletionRate(
            containing: visibleMonth,
            records: records,
            now: now,
            isTrackingEnabled: isTrackingEnabled,
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
        monthRangePolicy.earliestVisibleMonth(
            now: now,
            records: records,
            isTrackingEnabled: isTrackingEnabled,
            repositoryCreatedAt: repositoryCreatedAt
        )
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

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 7)
    }

    private var gridSpacing: CGFloat {
        isExpandedLayout ? 12 : 8
    }

    private var dayCellHeight: CGFloat {
        isExpandedLayout ? 52 : 34
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpandedLayout ? 24 : 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleText)
                    .font(isExpandedLayout ? DesignTokens.Typography.title3 : DesignTokens.Typography.headline)
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
                    .font(isExpandedLayout ? DesignTokens.Typography.title3 : DesignTokens.Typography.headline)
                    .monospacedDigit()
                    .foregroundStyle(DesignTokens.Color.accent)
            }

            LazyVGrid(columns: columns, spacing: gridSpacing) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(isExpandedLayout ? DesignTokens.Typography.subheadline : DesignTokens.Typography.captionStrong)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankDayCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: dayCellHeight)
                }

                ForEach(monthDays) { day in
                    CalendarDayCell(
                        day: day,
                        height: dayCellHeight,
                        isExpandedLayout: isExpandedLayout
                    )
                }
            }
        }
        .onChange(of: records.map(\.dateKey)) {
            clampVisibleMonth()
        }
        .onChange(of: dateService.dateKey(for: now)) {
            clampVisibleMonth()
        }
        .onChange(of: isTrackingEnabled) {
            clampVisibleMonth()
        }
        .onChange(of: repositoryCreatedAt) {
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
        monthRangePolicy.clampedMonth(
            month,
            now: now,
            records: records,
            isTrackingEnabled: isTrackingEnabled,
            repositoryCreatedAt: repositoryCreatedAt
        )
    }
}

private struct CalendarDayCell: View {
    let day: HabitCalendarDay
    let height: CGFloat
    let isExpandedLayout: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundStyle)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderStyle, lineWidth: borderWidth)
                }

            Text("\(day.dayNumber)")
                .font(isExpandedLayout ? DesignTokens.Typography.headline : DesignTokens.Typography.captionStrong)
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
