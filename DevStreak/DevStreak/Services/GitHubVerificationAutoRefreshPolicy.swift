//
//  GitHubVerificationAutoRefreshPolicy.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct GitHubVerificationAutoRefreshPolicy {
    static let defaultCooldown: TimeInterval = 30 * 60

    let cooldown: TimeInterval

    init(cooldown: TimeInterval = Self.defaultCooldown) {
        self.cooldown = cooldown
    }

    func shouldRunAutomaticVerification(
        now: Date,
        lastAutomaticVerificationAt: Date?,
        isTaskRunning: Bool,
        isTodayAlreadyGitHubVerified: Bool = false
    ) -> Bool {
        guard !isTodayAlreadyGitHubVerified else {
            return false
        }

        guard !isTaskRunning else {
            return false
        }

        guard let lastAutomaticVerificationAt else {
            return true
        }

        return now.timeIntervalSince(lastAutomaticVerificationAt) >= cooldown
    }
}
