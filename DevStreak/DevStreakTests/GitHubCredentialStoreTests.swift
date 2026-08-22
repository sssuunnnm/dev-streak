//
//  GitHubCredentialStoreTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Security
import Testing
@testable import DevStreak

struct GitHubCredentialStoreTests {
    @Test func savesLoadsAndDeletesTokenThroughTokenStore() throws {
        let tokenStore = FakeGitHubTokenStore()
        let store = GitHubCredentialStore(tokenStore: tokenStore)

        try store.saveToken("  github_pat_test  ")

        #expect(try store.loadToken() == "github_pat_test")
        #expect(try store.hasToken())
        #expect(try store.authorizationHeader() == "Bearer github_pat_test")

        try store.deleteToken()

        #expect(try store.loadToken() == nil)
        #expect(try !store.hasToken())
        #expect(try store.authorizationHeader() == nil)
    }

    @Test func emptyTokenDeletesStoredToken() throws {
        let tokenStore = FakeGitHubTokenStore()
        let store = GitHubCredentialStore(tokenStore: tokenStore)

        try store.saveToken("github_pat_test")
        try store.saveToken("   ")

        #expect(try store.loadToken() == nil)
    }

    @Test func loadFailureIsPropagated() throws {
        let tokenStore = FakeGitHubTokenStore(loadError: .keychainFailure(errSecInteractionNotAllowed))
        let store = GitHubCredentialStore(tokenStore: tokenStore)

        #expect(throws: GitHubCredentialError.keychainFailure(errSecInteractionNotAllowed)) {
            _ = try store.loadToken()
        }

        #expect(throws: GitHubCredentialError.keychainFailure(errSecInteractionNotAllowed)) {
            _ = try store.authorizationHeader()
        }
    }
}

private final class FakeGitHubTokenStore: GitHubTokenStoreProtocol {
    private var token: String?
    private let loadError: GitHubCredentialError?

    init(loadError: GitHubCredentialError? = nil) {
        self.loadError = loadError
    }

    func loadToken() throws -> String? {
        if let loadError {
            throw loadError
        }

        return token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}
