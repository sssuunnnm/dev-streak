//
//  GitHubDailyRecordUpdater.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum GitHubDailyRecordUpdate {
    case created(DailyRecord)
    case updated(DailyRecord)
    case unchanged(DailyRecord)

    var record: DailyRecord {
        switch self {
        case .created(let record), .updated(let record), .unchanged(let record):
            record
        }
    }

    var requiresSave: Bool {
        switch self {
        case .created, .updated:
            return true
        case .unchanged:
            return false
        }
    }

    var shouldRunCompletionSideEffects: Bool {
        true
    }
}

struct GitHubDailyRecordUpdater {
    func applyVerified(dateKey: String, records: [DailyRecord], now: Date = .now) -> GitHubDailyRecordUpdate {
        if let record = records.first(where: { $0.dateKey == dateKey }) {
            guard record.status != .githubVerified else {
                return .unchanged(record)
            }

            record.status = .githubVerified
            record.completedAt = record.completedAt ?? now
            return .updated(record)
        }

        let record = DailyRecord(
            dateKey: dateKey,
            status: .githubVerified,
            completedAt: now,
            createdAt: now
        )

        return .created(record)
    }
}
