//
//  IdeaDetailView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftData
import SwiftUI
import UIKit

struct IdeaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Bindable var idea: Idea

    private let promptService = IdeaPromptService()

    @State private var isShowingEditor = false
    @State private var isShowingDeleteConfirmation = false
    @State private var actionMessage: String?

    var body: some View {
        List {
            Section("Title") {
                Text(idea.title)
            }

            Section("Notes") {
                Text(idea.notes.isEmpty ? "No notes." : idea.notes)
                    .foregroundStyle(idea.notes.isEmpty ? .secondary : .primary)
            }

            Section("Tags") {
                if idea.tags.isEmpty {
                    Text("No tags.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(idea.tags.joined(separator: ", "))
                }
            }

            Section("Status") {
                Text(idea.status.title)
            }

            Section {
                Button {
                    writeWithClaude()
                } label: {
                    Label("Write with Claude", systemImage: "doc.on.clipboard")
                }

                Button {
                    updateStatus(.used)
                } label: {
                    Label("Mark as Used", systemImage: "checkmark.circle")
                }
                .disabled(idea.status == .used)

                if idea.status == .archived {
                    Button {
                        updateStatus(.inbox)
                    } label: {
                        Label("Restore to Inbox", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        updateStatus(.archived)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Idea")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                IdeaEditorView(idea: idea)
            }
        }
        .confirmationDialog("Delete this idea?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteIdea)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func writeWithClaude() {
        UIPasteboard.general.string = promptService.prompt(for: idea)
        actionMessage = "Prompt copied to clipboard."

        guard let url = URL(string: "https://claude.ai/") else {
            return
        }

        openURL(url)
    }

    private func updateStatus(_ status: IdeaStatus) {
        idea.updateStatus(status)
        _ = saveChanges()
    }

    private func deleteIdea() {
        modelContext.delete(idea)

        if saveChanges() {
            dismiss()
        }
    }

    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            actionMessage = "Could not save changes."
            return false
        }
    }
}

#Preview {
    NavigationStack {
        IdeaDetailView(idea: Idea(title: "SwiftData and Widgets", notes: "App Group notes", tags: ["swift", "ios"]))
    }
    .modelContainer(for: Idea.self, inMemory: true)
}
