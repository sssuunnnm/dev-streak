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
}
