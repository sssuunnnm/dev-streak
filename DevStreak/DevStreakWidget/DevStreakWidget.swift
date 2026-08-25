//
//  DevStreakWidget.swift
//  DevStreakWidget
//
//  Created by Codex on 8/22/26.
//

import SwiftUI
import WidgetKit

struct DevStreakWidgetEntry: TimelineEntry {
    let date: Date
    let displayState: WidgetDisplayState
}

struct DevStreakWidgetProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()
    private let dateKeyProvider = WidgetDateKeyProvider()

    func placeholder(in context: Context) -> DevStreakWidgetEntry {
        DevStreakWidgetEntry(
            date: Date(),
            displayState: WidgetDisplayState(
                dateKey: "2026-08-22",
                isTodayCompleted: false,
                currentStreak: 7,
                pendingIdeaCount: 3,
                recentDays: WidgetRecentDay.previewWeek,
                updatedAt: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DevStreakWidgetEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DevStreakWidgetEntry>) -> Void) {
        let now = Date()
        let entry = entry(for: now)
        let nextRefresh = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 1, to: now) ?? now

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func entry(for date: Date) -> DevStreakWidgetEntry {
        let currentDateKey = dateKeyProvider.dateKey(for: date)
        let snapshot = store.load(fallbackDateKey: currentDateKey)
        let displayState = WidgetDisplayState.make(snapshot: snapshot, currentDateKey: currentDateKey)

        return DevStreakWidgetEntry(date: date, displayState: displayState)
    }
}

private enum DevStreakWidgetMode {
    case streak
    case today
}

private struct DevStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: DevStreakWidgetEntry
    let mode: DevStreakWidgetMode

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemMedium:
                DevStreakMediumWidgetView(entry: entry)
            case .accessoryCircular:
                switch mode {
                case .streak:
                    DevStreakAccessoryCircularView(entry: entry)
                case .today:
                    DevStreakTodayAccessoryCircularView(entry: entry)
                }
            case .accessoryRectangular:
                DevStreakAccessoryRectangularView(entry: entry)
            case .accessoryInline:
                DevStreakAccessoryInlineView(entry: entry)
            default:
                switch mode {
                case .streak:
                    DevStreakSmallWidgetView(entry: entry)
                case .today:
                    DevStreakTodaySmallWidgetView(entry: entry)
                }
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(WidgetConstants.dashboardURL)
    }
}

private struct DevStreakSmallWidgetView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DevStreak")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.primaryText)

                Text("연속 기록")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(entry.displayState.currentStreak)")
                    .font(WidgetTypography.mediumMetric)
                    .foregroundStyle(WidgetPalette.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)

                Text("일")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.primaryText)
            }

            Spacer(minLength: 0)

            WidgetIdeaMemoCountView(count: entry.displayState.pendingIdeaCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct DevStreakTodaySmallWidgetView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DevStreak")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.primaryText)

                Text("오늘 기록")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
            }

            WidgetTodayStatusMark(isCompleted: entry.displayState.isTodayCompleted, size: 70)

            Spacer(minLength: 0)

            WidgetIdeaMemoCountView(count: entry.displayState.pendingIdeaCount)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct DevStreakMediumWidgetView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevStreak")
                        .font(WidgetTypography.captionStrong)
                        .foregroundStyle(WidgetPalette.primaryText)

                    Text("연속 기록")
                        .font(WidgetTypography.captionStrong)
                        .foregroundStyle(WidgetPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(entry.displayState.currentStreak)일")
                    .font(WidgetTypography.mediumMetric)
                    .foregroundStyle(WidgetPalette.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
            }

            WidgetRecentDaysStrip(days: entry.displayState.recentDays, style: .regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WidgetIdeaMemoCountView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lightbulb")
                .font(.caption.weight(.medium))
                .symbolRenderingMode(.hierarchical)

            Text("아이디어 메모 \(count)개")
                .font(WidgetTypography.captionStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(WidgetPalette.secondaryText)
    }
}

private struct WidgetTodayStatusMark: View {
    let isCompleted: Bool
    let size: CGFloat

    private var text: String {
        isCompleted ? "O" : "X"
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(isCompleted ? WidgetPalette.accent : WidgetPalette.secondaryText)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(isCompleted ? "오늘 기록 완료" : "오늘 기록 미완료")
    }
}

private enum WidgetRecentDaysStripStyle {
    case regular
    case compact

    var showsDayNumbers: Bool {
        self == .regular
    }

    var markerSize: CGSize {
        switch self {
        case .regular:
            CGSize(width: 18, height: 13)
        case .compact:
            CGSize(width: 13, height: 10)
        }
    }

    var lineOffset: CGFloat {
        switch self {
        case .regular:
            -5.5
        case .compact:
            -4.0
        }
    }
}

private struct WidgetRecentDaysStrip: View {
    let days: [WidgetRecentDay]
    let style: WidgetRecentDaysStripStyle

    private var displayDays: [WidgetRecentDay] {
        days.isEmpty ? WidgetRecentDay.previewWeek : days
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(WidgetPalette.track)
                .frame(height: 2)
                .padding(.horizontal, style.markerSize.width / 2)
                .offset(y: style.lineOffset)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(displayDays) { day in
                    VStack(spacing: 6) {
                        if style.showsDayNumbers {
                            Text("\(day.dayNumber)")
                                .font(WidgetTypography.caption)
                                .foregroundStyle(day.isToday ? WidgetPalette.primaryText : WidgetPalette.mutedText)
                                .monospacedDigit()
                        }

                        RoundedRectangle(cornerRadius: 8)
                            .fill(day.isCompleted ? WidgetPalette.accent : WidgetPalette.track)
                            .frame(width: style.markerSize.width, height: style.markerSize.height)
                            .overlay {
                                if day.isToday && !day.isCompleted {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(WidgetPalette.accent.opacity(0.45), lineWidth: 1.2)
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct DevStreakAccessoryCircularView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        Gauge(value: min(Double(entry.displayState.currentStreak), 7.0), in: 0.0...7.0) {
            Text("연속 기록")
        } currentValueLabel: {
            VStack(spacing: 1) {
                Text("\(entry.displayState.currentStreak)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()

                Text("연속 기록")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.8)
            }
            .widgetAccentable()
        } minimumValueLabel: {
            Text("")
        } maximumValueLabel: {
            Text("7")
                .font(.system(size: 6, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct DevStreakTodayAccessoryCircularView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        Gauge(value: entry.displayState.isTodayCompleted ? 1.0 : 0.0, in: 0.0...1.0) {
            Text("오늘 기록")
        } currentValueLabel: {
            Text(entry.displayState.isTodayCompleted ? "O" : "X")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.8)
            .widgetAccentable()
        } minimumValueLabel: {
            Text("")
        } maximumValueLabel: {
            Text("")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

private struct DevStreakAccessoryRectangularView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DevStreak")
                .font(.caption.weight(.semibold))

            Text("오늘 \(entry.displayState.goalText)")
                .font(.headline.weight(.semibold))
                .monospacedDigit()

            Text("연속 기록 \(entry.displayState.currentStreak)일")
                .font(.caption2)
                .monospacedDigit()
        }
        .widgetAccentable()
    }
}

private struct DevStreakAccessoryInlineView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        Text("DevStreak · \(entry.displayState.goalText) · \(entry.displayState.currentStreak)일")
            .widgetAccentable()
    }
}

private enum WidgetPalette {
    static let primaryText = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let secondaryText = Color(red: 0.38, green: 0.47, blue: 0.57)
    static let mutedText = Color(red: 0.66, green: 0.73, blue: 0.81)
    static let accent = Color(red: 0.25, green: 0.40, blue: 0.58)
    static let track = Color(red: 0.83, green: 0.88, blue: 0.93)
    static let streak = Color(red: 0.72, green: 0.43, blue: 0.16)
}

private enum WidgetTypography {
    static let caption = Font.caption2.weight(.medium)
    static let captionStrong = Font.caption.weight(.semibold)
    static let metric = Font.title.weight(.bold)
    static let mediumMetric = Font.largeTitle.weight(.bold)
}

struct DevStreakWidget: Widget {
    let kind = WidgetConstants.streakWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakWidgetProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry, mode: .streak)
        }
        .configurationDisplayName("DevStreak 연속 기록")
        .description("연속 기록과 최근 기록 흐름을 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct DevStreakTodayWidget: Widget {
    let kind = WidgetConstants.todayWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakWidgetProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry, mode: .today)
        }
        .configurationDisplayName("DevStreak 오늘 기록")
        .description("오늘 기록 달성 여부를 보여줍니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

@main
struct DevStreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        DevStreakWidget()
        DevStreakTodayWidget()
    }
}

private struct WidgetDateKeyProvider {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

private extension DevStreakWidgetEntry {
    static let preview = DevStreakWidgetEntry(
        date: Date(),
        displayState: WidgetDisplayState(
            dateKey: "2026-08-22",
            isTodayCompleted: true,
            currentStreak: 3,
            pendingIdeaCount: 2,
            recentDays: WidgetRecentDay.previewWeek,
            updatedAt: Date()
        )
    )
}

private extension WidgetRecentDay {
    static let previewWeek = [
        WidgetRecentDay(dateKey: "2026-08-16", dayNumber: 16, isCompleted: true, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-17", dayNumber: 17, isCompleted: true, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-18", dayNumber: 18, isCompleted: true, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-19", dayNumber: 19, isCompleted: false, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-20", dayNumber: 20, isCompleted: true, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-21", dayNumber: 21, isCompleted: true, isToday: false),
        WidgetRecentDay(dateKey: "2026-08-22", dayNumber: 22, isCompleted: true, isToday: true)
    ]
}

#Preview("Small", as: .systemSmall) {
    DevStreakWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Small Today", as: .systemSmall) {
    DevStreakTodayWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Medium", as: .systemMedium) {
    DevStreakWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Circular", as: .accessoryCircular) {
    DevStreakWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Circular Today", as: .accessoryCircular) {
    DevStreakTodayWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Rectangular", as: .accessoryRectangular) {
    DevStreakWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}

#Preview("Inline", as: .accessoryInline) {
    DevStreakWidget()
} timeline: {
    DevStreakWidgetEntry.preview
}
