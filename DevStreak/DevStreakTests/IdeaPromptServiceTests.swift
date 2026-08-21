//
//  IdeaPromptServiceTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Testing
@testable import DevStreak

@MainActor
struct IdeaPromptServiceTests {
    @Test func promptIncludesTitleNotesAndTags() {
        let idea = Idea(
            title: "SwiftData와 Widget 데이터 공유",
            notes: "App Group과 timeline reload 정리",
            tags: ["swift", "ios"]
        )
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("SwiftData와 Widget 데이터 공유"))
        #expect(prompt.contains("App Group과 timeline reload 정리"))
        #expect(prompt.contains("swift, ios"))
    }

    @Test func promptIncludesRepositoryConventionInstructions() {
        let idea = Idea(title: "테스트")
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("CONVENTIONS.md"))
        #expect(prompt.contains("DESIGN_RULES.md"))
    }

    @Test func promptCanBeGeneratedWhenNotesAndTagsAreEmpty() {
        let idea = Idea(title: "Empty detail idea")
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("Empty detail idea"))
        #expect(prompt.contains("메모:"))
        #expect(prompt.contains("태그:"))
    }

    @Test func generatingPromptDoesNotMarkIdeaAsUsed() {
        let idea = Idea(title: "Draft idea", status: .inbox)

        _ = IdeaPromptService().prompt(for: idea)

        #expect(idea.status == .inbox)
    }
}
