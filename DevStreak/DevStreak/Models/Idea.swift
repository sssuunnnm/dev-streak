//
//  Idea.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation
import SwiftData

enum IdeaStatus: String, Codable, CaseIterable, Identifiable {
    case inbox
    case used
    case archived

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .inbox:
            "Inbox"
        case .used:
            "Used"
        case .archived:
            "Archived"
        }
    }
}

@Model
final class Idea {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var tagsRawValue: String
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date

    var tags: [String] {
        get {
            guard let data = tagsRawValue.data(using: .utf8),
                  let decodedTags = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }

            return decodedTags
        }
        set {
            tagsRawValue = Self.encode(tags: TagNormalizer.normalize(newValue))
        }
    }

    var status: IdeaStatus {
        get {
            IdeaStatus(rawValue: statusRawValue) ?? .inbox
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        tags: [String] = [],
        status: IdeaStatus = .inbox,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.tagsRawValue = Self.encode(tags: TagNormalizer.normalize(tags))
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func update(title: String, notes: String, tags: [String], now: Date = .now) {
        self.title = title
        self.notes = notes
        self.tags = tags
        self.updatedAt = now
    }

    func updateStatus(_ status: IdeaStatus, now: Date = .now) {
        self.status = status
        self.updatedAt = now
    }

    private static func encode(tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return encoded
    }
}
