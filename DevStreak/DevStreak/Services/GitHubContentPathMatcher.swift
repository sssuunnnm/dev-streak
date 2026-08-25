//
//  GitHubContentPathMatcher.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

nonisolated struct GitHubContentPathMatcher {
    private let contentPrefixes = [
        "src/content/articles/",
        "src/content/projects/",
        "src/content/references/",
        "src/content/snippets/"
    ]

    func isWritingContentPath(_ path: String) -> Bool {
        contentPrefixes.contains { path.hasPrefix($0) }
    }

    func containsWritingContentPath(_ paths: [String]) -> Bool {
        paths.contains { isWritingContentPath($0) }
    }
}
