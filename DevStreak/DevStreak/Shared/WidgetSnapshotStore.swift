//
//  WidgetSnapshotStore.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct WidgetSnapshotStore {
    private static let snapshotKey = "devstreak.widget.snapshot"

    private let defaults: UserDefaults?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults? = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let data = try? encoder.encode(snapshot) else {
            return false
        }

        defaults?.set(data, forKey: Self.snapshotKey)
        return defaults != nil
    }

    func load(fallbackDateKey: String = "") -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: Self.snapshotKey),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else {
            return .fallback(dateKey: fallbackDateKey)
        }

        return snapshot
    }

    func clear() {
        defaults?.removeObject(forKey: Self.snapshotKey)
    }
}
