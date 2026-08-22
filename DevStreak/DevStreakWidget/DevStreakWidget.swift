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

struct DevStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    let entry: DevStreakWidgetEntry

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemMedium:
                DevStreakMediumWidgetView(entry: entry)
            case .accessoryCircular:
                DevStreakAccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                DevStreakAccessoryRectangularView(entry: entry)
            case .accessoryInline:
                DevStreakAccessoryInlineView(entry: entry)
            default:
                DevStreakSmallWidgetView(entry: entry)
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(WidgetConstants.dashboardURL)
    }
}

private struct DevStreakSmallWidgetView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DevStreak")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.secondaryText)

                Spacer()

                Image(systemName: entry.displayState.isTodayCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(entry.displayState.isTodayCompleted ? WidgetPalette.accent : WidgetPalette.secondaryText)
            }

            Text(entry.displayState.goalText)
                .font(WidgetTypography.metric)
                .foregroundStyle(WidgetPalette.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.76)

            WidgetStreakRow(streak: entry.displayState.currentStreak)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "lightbulb")
                    .font(.caption2.weight(.semibold))

                Text(entry.displayState.pendingIdeaCount > 0 ? "메모 \(entry.displayState.pendingIdeaCount)개 대기 중" : "대기 중인 메모 없음")
                    .font(WidgetTypography.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(WidgetPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct DevStreakMediumWidgetView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DevStreak")
                    .font(WidgetTypography.captionStrong)
                    .foregroundStyle(WidgetPalette.secondaryText)

                Text(entry.displayState.goalText)
                    .font(WidgetTypography.mediumMetric)
                    .foregroundStyle(WidgetPalette.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.78)

                Text(entry.displayState.isTodayCompleted ? "오늘 기록 완료" : "오늘 기록 대기")
                    .font(WidgetTypography.caption)
                    .foregroundStyle(WidgetPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                WidgetMetricBlock(label: "연속 기록", value: "\(entry.displayState.currentStreak)일")
                WidgetMetricBlock(label: "아이디어 메모", value: "\(entry.displayState.pendingIdeaCount)개")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WidgetMetricBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(label)
                .font(WidgetTypography.caption)
                .foregroundStyle(WidgetPalette.secondaryText)

            Text(value)
                .font(WidgetTypography.captionStrong)
                .foregroundStyle(WidgetPalette.primaryText)
                .monospacedDigit()
        }
    }
}

private struct WidgetStreakRow: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(WidgetPalette.streak)

            Text("\(streak)일")
                .font(WidgetTypography.captionStrong)
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.secondaryText)
        }
    }
}

private struct DevStreakAccessoryCircularView: View {
    let entry: DevStreakWidgetEntry

    var body: some View {
        Gauge(value: entry.displayState.isTodayCompleted ? 1.0 : 0.0, in: 0.0...1.0) {
            Text("DevStreak")
        } currentValueLabel: {
            Text(entry.displayState.goalText)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .monospacedDigit()
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
    static let accent = Color(red: 0.25, green: 0.40, blue: 0.58)
    static let streak = Color(red: 0.72, green: 0.43, blue: 0.16)
}

private enum WidgetTypography {
    static let caption = Font.caption2.weight(.medium)
    static let captionStrong = Font.caption.weight(.semibold)
    static let metric = Font.title.weight(.bold)
    static let mediumMetric = Font.largeTitle.weight(.bold)
}

struct DevStreakWidget: Widget {
    let kind = WidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakWidgetProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DevStreak")
        .description("오늘 기록 상태를 보여줍니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct DevStreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        DevStreakWidget()
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
            updatedAt: Date()
        )
    )
}

#Preview("Small", as: .systemSmall) {
    DevStreakWidget()
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
