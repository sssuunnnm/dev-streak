//
//  IdeaInboxView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftData
import SwiftUI

struct IdeaInboxView: View {
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    @State private var selectedStatus = IdeaStatus.inbox
    @State private var isShowingNewIdea = false

    private var filteredIdeas: [Idea] {
        ideas.filter { $0.status == selectedStatus }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Idea Status", selection: $selectedStatus) {
                ForEach(IdeaStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                if filteredIdeas.isEmpty {
                    ContentUnavailableView(
                        selectedStatus.title,
                        systemImage: "tray",
                        description: Text(emptyMessage)
                    )
                } else {
                    ForEach(filteredIdeas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            IdeaRowView(idea: idea)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Idea Inbox")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewIdea = true
                } label: {
                    Label("New Idea", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewIdea) {
            NavigationStack {
                IdeaEditorView()
            }
        }
    }

    private var emptyMessage: String {
        switch selectedStatus {
        case .inbox:
            "No ideas yet."
        case .used:
            "No used ideas yet."
        case .archived:
            "No archived ideas yet."
        }
    }
}

private struct IdeaRowView: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(idea.title)
                .font(.headline)

            if !idea.notes.isEmpty {
                Text(idea.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !idea.tags.isEmpty {
                Text(idea.tags.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        IdeaInboxView()
    }
    .modelContainer(for: Idea.self, inMemory: true)
}
