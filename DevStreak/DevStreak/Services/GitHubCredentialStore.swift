//
//  GitHubCredentialStore.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation
import Security

enum GitHubCredentialError: Error, Equatable {
    case keychainFailure(OSStatus)
}

protocol GitHubTokenStoreProtocol {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

struct GitHubCredentialStore {
    private let tokenStore: GitHubTokenStoreProtocol

    init(tokenStore: GitHubTokenStoreProtocol = KeychainGitHubTokenStore()) {
        self.tokenStore = tokenStore
    }

    func loadToken() -> String? {
        try? tokenStore.loadToken()
    }

    func hasToken() -> Bool {
        loadToken()?.isEmpty == false
    }

    func saveToken(_ token: String) throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            try tokenStore.deleteToken()
            return
        }

        try tokenStore.saveToken(trimmedToken)
    }

    func deleteToken() throws {
        try tokenStore.deleteToken()
    }

    func authorizationHeader() -> String? {
        guard let token = loadToken(), !token.isEmpty else {
            return nil
        }

        return "Bearer \(token)"
    }
}

struct KeychainGitHubTokenStore: GitHubTokenStoreProtocol {
    private let service: String
    private let account: String

    init(
        service: String = "com.sssuunnnm.DevStreak.github",
        account: String = "dev-archive.pat"
    ) {
        self.service = service
        self.account = account
    }

    func loadToken() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw GitHubCredentialError.keychainFailure(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ] as CFDictionary)

            guard updateStatus == errSecSuccess else {
                throw GitHubCredentialError.keychainFailure(updateStatus)
            }

            return
        }

        guard status == errSecSuccess else {
            throw GitHubCredentialError.keychainFailure(status)
        }
    }

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GitHubCredentialError.keychainFailure(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
