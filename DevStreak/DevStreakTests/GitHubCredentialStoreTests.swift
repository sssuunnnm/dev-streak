//
//  GitHubCredentialStoreTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Testing
@testable import DevStreak

struct GitHubCredentialStoreTests {
    @Test func savesLoadsAndDeletesTokenThroughTokenStore() throws {
        let tokenStore = FakeGitHubTokenStore()
        let store = GitHubCredentialStore(tokenStore: tokenStore)

        try store.saveToken("  github_pat_test  ")

        #expect(store.loadToken() == "github_pat_test")
        #expect(store.hasToken())
        #expect(store.authorizationHeader() == "Bearer github_pat_test")

        try store.deleteToken()

        #expect(store.loadToken() == nil)
        #expect(!store.hasToken())
        #expect(store.authorizationHeader() == nil)
    }

    @Test func emptyTokenDeletesStoredToken() throws {
        let tokenStore = FakeGitHubTokenStore()
        let store = GitHubCredentialStore(tokenStore: tokenStore)

        try store.saveToken("github_pat_test")
        try store.saveToken("   ")

        #expect(store.loadToken() == nil)
    }
}

private final class FakeGitHubTokenStore: GitHubTokenStoreProtocol {
    private var token: String?

    func loadToken() throws -> String? {
        token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}
