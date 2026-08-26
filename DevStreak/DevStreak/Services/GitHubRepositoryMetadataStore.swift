//
//  GitHubRepositoryMetadataStore.swift
//  DevStreak
//
//  Created by Codex on 8/26/26.
//

import Foundation

struct GitHubRepositoryMetadataStore {
    private let userDefaults: UserDefaults
    private let createdAtKey = "githubRepositoryCreatedAt"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var createdAt: Date? {
        let timestamp = userDefaults.double(forKey: createdAtKey)
        guard timestamp > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    func save(createdAt: Date?) {
        guard let createdAt else {
            return
        }

        userDefaults.set(createdAt.timeIntervalSince1970, forKey: createdAtKey)
    }

    func reset() {
        userDefaults.removeObject(forKey: createdAtKey)
    }
}
