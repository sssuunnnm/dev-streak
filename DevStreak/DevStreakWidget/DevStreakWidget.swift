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
        VStack(alignment: .leading, spacing: 10) {
            Text("DEV STREAK")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(entry.displayState.goalText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.8)

            VStack(alignment: .leading, spacing: 3) {
                Text("Current Streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("🔥 \(entry.displayState.currentStreak) days")
                    .font(.caption.weight(.semibold))
            }

            if entry.displayState.pendingIdeaCount > 0 {
                Text("\(entry.displayState.pendingIdeaCount) ideas waiting")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
        .widgetURL(WidgetConstants.dashboardURL)
    }
}

struct DevStreakWidget: Widget {
    let kind = WidgetConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DevStreakWidgetProvider()) { entry in
            DevStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("DevStreak")
        .description("Shows your daily writing status.")
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
