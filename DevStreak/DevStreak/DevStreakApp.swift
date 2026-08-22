//
//  DevStreakApp.swift
//  DevStreak
//
//  Created by 이선민 on 8/21/26.
//

import SwiftUI
import SwiftData

@main
struct DevStreakApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DailyRecord.self,
            Idea.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(sharedModelContainer)
        .handlesExternalEvents(matching: ["dashboard"])
    }
}
