//
//  DailyRecord.swift
//  DevStreak
//
//  Created by Codex on 8/21/26.
//

import Foundation
import SwiftData

enum DailyRecordStatus: String, Codable, CaseIterable {
    case pending
    case manualCompleted
    case githubVerified

    var isCompleted: Bool {
        switch self {
        case .pending:
            false
        case .manualCompleted, .githubVerified:
            true
        }
    }
}

@Model
final class DailyRecord {
    @Attribute(.unique) var dateKey: String
    var statusRawValue: String
    var completedAt: Date?
    var createdAt: Date

    var status: DailyRecordStatus {
        get {
            DailyRecordStatus(rawValue: statusRawValue) ?? .pending
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    init(
        dateKey: String,
        status: DailyRecordStatus,
        completedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.dateKey = dateKey
        self.statusRawValue = status.rawValue
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}
