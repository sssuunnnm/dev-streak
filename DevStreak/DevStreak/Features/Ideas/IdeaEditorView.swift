//
//  IdeaEditorView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftData
import SwiftUI

struct IdeaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let idea: Idea?

    @State private var title: String
    @State private var notes: String
    @State private var tagsText: String
    @State private var saveErrorMessage: String?

    init(idea: Idea? = nil) {
        self.idea = idea
        _title = State(initialValue: idea?.title ?? "")
        _notes = State(initialValue: idea?.notes ?? "")
        _tagsText = State(initialValue: idea?.tags.joined(separator: ", ") ?? "")
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedTitle.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("제목", text: $title)
                    .font(.title3.weight(.semibold))
            } header: {
                Text("제목")
            }

            Section {
                TextEditor(text: $notes)
                    .frame(minHeight: 160)
            } header: {
                Text("메모")
            }

            Section {
                TextField("swift, ios", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("태그")
            }

            if let saveErrorMessage {
                Section {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(idea == nil ? "새 Idea" : "Idea 수정")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(!canSave)
            }
        }
    }

    private func save() {
        let now = Date()
        let normalizedTags = TagNormalizer.normalizeCommaSeparated(tagsText)

        if let idea {
            idea.update(
                title: normalizedTitle,
                notes: notes,
                tags: normalizedTags,
                now: now
            )
        } else {
            let idea = Idea(
                title: normalizedTitle,
                notes: notes,
                tags: normalizedTags,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(idea)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "Idea를 저장하지 못했습니다."
        }
    }
}

#Preview {
    NavigationStack {
        IdeaEditorView()
    }
    .modelContainer(for: Idea.self, inMemory: true)
}
