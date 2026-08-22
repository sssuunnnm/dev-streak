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
    let entry: DevStreakWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DevStreak")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WidgetPalette.secondaryText)

                Spacer()

                Image(systemName: entry.displayState.isTodayCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(entry.displayState.isTodayCompleted ? WidgetPalette.accent : WidgetPalette.secondaryText)
            }

            Text(entry.displayState.goalText)
                .font(.system(size: 38, weight: .bold, design: .default))
                .foregroundStyle(WidgetPalette.primaryText)
                .monospacedDigit()
                .minimumScaleFactor(0.76)

            WidgetStreakRow(streak: entry.displayState.currentStreak)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "lightbulb")
                    .font(.caption2.weight(.semibold))

                Text(entry.displayState.pendingIdeaCount > 0 ? "Idea \(entry.displayState.pendingIdeaCount)개 대기 중" : "대기 중인 Idea 없음")
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(WidgetPalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
        .widgetURL(WidgetConstants.dashboardURL)
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
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.secondaryText)
        }
    }
}

private enum WidgetPalette {
    static let primaryText = Color(red: 0.08, green: 0.12, blue: 0.18)
    static let secondaryText = Color(red: 0.38, green: 0.47, blue: 0.57)
    static let accent = Color(red: 0.25, green: 0.40, blue: 0.58)
    static let streak = Color(red: 0.72, green: 0.43, blue: 0.16)
}

struct DevStreakWidget: Widget {
    let kind = WidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakWidgetProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DevStreak")
        .description("오늘 기록 상태를 보여줍니다.")
        .supportedFamilies([.systemSmall])
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
