//
//  ManualCompletionConfirmationStateTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Testing
@testable import DevStreak

struct ManualCompletionConfirmationStateTests {
    @Test func requestingCompletionOnlyPresentsConfirmation() {
        var state = ManualCompletionConfirmationState()
        let didComplete = false

        state.request()

        #expect(state.isPresented)
        #expect(!didComplete)
    }

    @Test func confirmingCompletionRunsManualCompletionAction() {
        var state = ManualCompletionConfirmationState()
        var didComplete = false

        state.request()
        state.confirm {
            didComplete = true
        }

        #expect(!state.isPresented)
        #expect(didComplete)
    }

    @Test func cancellingCompletionDoesNotRunManualCompletionAction() {
        var state = ManualCompletionConfirmationState()
        let didComplete = false

        state.request()
        state.cancel()

        #expect(!state.isPresented)
        #expect(!didComplete)
    }
}
