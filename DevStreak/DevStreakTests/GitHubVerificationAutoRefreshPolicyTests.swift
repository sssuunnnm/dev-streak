//
//  GitHubVerificationAutoRefreshPolicyTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Testing
@testable import DevStreak

struct GitHubVerificationAutoRefreshPolicyTests {
    private let policy = GitHubVerificationAutoRefreshPolicy(cooldown: 30 * 60)

    @Test func firstVerificationCanRunAutomatically() {
        #expect(policy.shouldRunAutomaticVerification(
            now: Self.now,
            lastAutomaticVerificationAt: nil,
            isTaskRunning: false
        ))
    }

    @Test func noActivityCanRunAgainAfterCooldown() {
        #expect(policy.shouldRunAutomaticVerification(
            now: Self.now.addingTimeInterval(31 * 60),
            lastAutomaticVerificationAt: Self.now,
            isTaskRunning: false
        ))
    }

    @Test func transientFailureCanRunAgainAfterCooldown() {
        #expect(policy.shouldRunAutomaticVerification(
            now: Self.now.addingTimeInterval(30 * 60),
            lastAutomaticVerificationAt: Self.now,
            isTaskRunning: false
        ))
    }

    @Test func verifiedCanRunAgainAfterCooldown() {
        #expect(policy.shouldRunAutomaticVerification(
            now: Self.now.addingTimeInterval(60 * 60),
            lastAutomaticVerificationAt: Self.now,
            isTaskRunning: false
        ))
    }

    @Test func activeBeforeCooldownDoesNotRunAgain() {
        #expect(!policy.shouldRunAutomaticVerification(
            now: Self.now.addingTimeInterval(10 * 60),
            lastAutomaticVerificationAt: Self.now,
            isTaskRunning: false
        ))
    }

    @Test func runningTaskPreventsDuplicateVerification() {
        #expect(!policy.shouldRunAutomaticVerification(
            now: Self.now.addingTimeInterval(60 * 60),
            lastAutomaticVerificationAt: Self.now,
            isTaskRunning: true
        ))
    }

    private static let now = Date(timeIntervalSince1970: 1_787_321_600)
}
