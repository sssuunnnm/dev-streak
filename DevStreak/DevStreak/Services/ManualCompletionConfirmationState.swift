//
//  ManualCompletionConfirmationState.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

struct ManualCompletionConfirmationState: Equatable {
    private(set) var isPresented = false

    mutating func request() {
        isPresented = true
    }

    mutating func cancel() {
        isPresented = false
    }

    mutating func confirm(_ completion: () -> Void) {
        isPresented = false
        completion()
    }
}
