//
//  IdeaModelTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import SwiftData
import Testing
@testable import DevStreak

@MainActor
struct IdeaModelTests {
    @Test func invalidStatusRawValueFallsBackToInbox() {
        let idea = Idea(title: "Status fallback", status: .used)

        idea.statusRawValue = "unknown"

        #expect(idea.status == .inbox)
    }

    @Test func dailyRecordAndIdeaCanShareModelContainerSchema() throws {
        let schema = Schema([
            DailyRecord.self,
            Idea.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        context.insert(DailyRecord(dateKey: "2026-08-22", status: .manualCompleted))
        context.insert(Idea(title: "Schema idea", tags: ["swift"]))

        try context.save()
    }

    @Test func notesOnlyIdeaCanBeCreated() {
        let idea = Idea(title: "", notes: "SwiftData migration 정리 방법 찾아보기")

        #expect(idea.title.isEmpty)
        #expect(idea.notes == "SwiftData migration 정리 방법 찾아보기")
        #expect(idea.displayTitle == "SwiftData migration 정리 방법 찾아보기")
    }

    @Test func notesOnlyPreviewUsesRemainingMemoText() {
        let idea = Idea(
            title: "",
            notes: """
            SwiftData migration 정리 방법 찾아보기
            오늘 모델 변경하면서 확인한 내용 정리
            """
        )

        #expect(idea.displayTitle == "SwiftData migration 정리 방법 찾아보기")
        #expect(idea.displayPreview == "오늘 모델 변경하면서 확인한 내용 정리")
    }

    @Test func existingTitleAndTagsRemainDisplayCompatible() {
        let idea = Idea(
            title: "기존 제목",
            notes: "기존 메모",
            tags: ["swift", "blog"]
        )

        #expect(idea.displayTitle == "기존 제목")
        #expect(idea.displayPreview == "기존 메모")
        #expect(idea.tags == ["swift", "blog"])
    }
}
