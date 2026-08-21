//
//  DashboardView.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.dateKey, order: .reverse) private var records: [DailyRecord]

    private let dateService = DateService()
    private let streakService = StreakService()

    @State private var saveErrorMessage: String?

    private var now: Date {
        Date()
    }

    private var todayKey: String {
        dateService.todayKey(now: now)
    }

    private var todayRecord: DailyRecord? {
        records.first { $0.dateKey == todayKey }
    }

    private var isTodayCompleted: Bool {
        todayRecord?.status.isCompleted == true
    }

    private var currentStreak: Int {
        streakService.currentStreak(records: records, now: now)
    }

    private var bestStreak: Int {
        streakService.bestStreak(records: records)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(todayKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(isTodayCompleted ? "1 / 1" : "0 / 1")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text(isTodayCompleted ? "Writing recorded for today." : "No writing activity yet.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Button(action: markTodayCompleted) {
                    Label(isTodayCompleted ? "Completed Today" : "Write Today", systemImage: isTodayCompleted ? "checkmark.circle.fill" : "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isTodayCompleted)

                HStack(spacing: 16) {
                    streakMetric(title: "Current Streak", value: currentStreak)
                    streakMetric(title: "Best Streak", value: bestStreak)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Activity")
                        .font(.headline)

                    if let todayRecord, todayRecord.status.isCompleted {
                        Text("Manual completion recorded today.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No writing activity yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("DevStreak")
        }
    }

    private func streakMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value) days")
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func markTodayCompleted() {
        let completionDate = Date()
        let completionDateKey = dateService.todayKey(now: completionDate)

        if let record = records.first(where: { $0.dateKey == completionDateKey }) {
            record.status = .manualCompleted
            record.completedAt = completionDate
        } else {
            let record = DailyRecord(
                dateKey: completionDateKey,
                status: .manualCompleted,
                completedAt: completionDate,
                createdAt: completionDate
            )
            modelContext.insert(record)
        }

        do {
            try modelContext.save()
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Could not save today's record."
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: DailyRecord.self, inMemory: true)
}
