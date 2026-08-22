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
            "메모"
        case .used:
            "사용함"
        case .archived:
            "보관함"
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

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return firstMeaningfulNoteLine ?? "제목 없는 메모"
    }

    var displayPreview: String? {
        let meaningfulLines = notes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return meaningfulLines.dropFirst().first
        }

        return meaningfulLines.first
    }

    var hasMemoContent: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var firstMeaningfulNoteLine: String? {
        notes
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func encode(tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return encoded
    }
}
