//
//  GitHubContentPathMatcherTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Testing
@testable import DevStreak

struct GitHubContentPathMatcherTests {
    private let matcher = GitHubContentPathMatcher()

    @Test func articlesPathCountsAsWritingContent() {
        #expect(matcher.isWritingContentPath("src/content/articles/swiftdata.md"))
    }

    @Test func projectsPathCountsAsWritingContent() {
        #expect(matcher.isWritingContentPath("src/content/projects/devstreak.md"))
    }

    @Test func referencesPathCountsAsWritingContent() {
        #expect(matcher.isWritingContentPath("src/content/references/widgetkit.md"))
    }

    @Test func snippetsPathCountsAsWritingContent() {
        #expect(matcher.isWritingContentPath("src/content/snippets/date-service.md"))
    }

    @Test func unrelatedSourceCodeDoesNotCountAsWritingContent() {
        #expect(!matcher.isWritingContentPath("src/components/Button.tsx"))
        #expect(!matcher.isWritingContentPath("src/content/drafts/example.md"))
    }
}
