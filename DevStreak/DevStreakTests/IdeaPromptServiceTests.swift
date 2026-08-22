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
    @Test func promptUsesMemoContent() {
        let idea = Idea(
            title: "SwiftData와 Widget 데이터 공유",
            notes: "App Group과 timeline reload 정리",
            tags: ["swift", "ios"]
        )
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("App Group과 timeline reload 정리"))
    }

    @Test func promptIncludesRepositoryConventionInstructions() {
        let idea = Idea(title: "테스트", notes: "메모")
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("CONVENTIONS.md"))
        #expect(prompt.contains("DESIGN_RULES.md"))
    }

    @Test func emptyNotesCannotCreatePrompt() {
        let idea = Idea(title: "Empty detail idea", notes: " \n ")

        #expect(!IdeaPromptService().canCreatePrompt(for: idea))
    }

    @Test func promptUsesNaturalMemoCenteredFormat() {
        let idea = Idea(
            title: "SwiftUI 테스트",
            notes: "Dashboard 구조 정리",
            tags: ["swiftui", "testing"]
        )
        let prompt = IdeaPromptService().prompt(for: idea)

        #expect(prompt.contains("우선 CONVENTIONS.md와 DESIGN_RULES.md를 따르고"))
        #expect(prompt.contains("\nDashboard 구조 정리\n"))
        #expect(prompt.contains("이러한 주제로 글을 써보고 싶은데 기술적/흐름적으로 괜찮은지 검토해줘."))
        #expect(!prompt.contains("제목:"))
        #expect(!prompt.contains("태그:"))
        #expect(!prompt.contains("메모:"))
        #expect(!prompt.contains("주제:"))
    }

    @Test func generatingPromptDoesNotMarkIdeaAsUsed() {
        let idea = Idea(title: "Draft idea", notes: "Draft memo", status: .inbox)

        _ = IdeaPromptService().prompt(for: idea)

        #expect(idea.status == .inbox)
    }
}
