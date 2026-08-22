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

    private var normalizedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !normalizedNotes.isEmpty
    }

    var body: some View {
        Form {
            Section {
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("나중에 글로 정리하고 싶은 내용을 간단히 남겨보세요.")
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                            .padding(.top, 8)
                            .padding(.horizontal, 5)
                    }

                    TextEditor(text: $notes)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                }
            }

            if let saveErrorMessage {
                Section {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("아이디어 메모")
        .font(DesignTokens.Typography.body)
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
                notes: normalizedNotes,
                tags: normalizedTags,
                now: now
            )
        } else {
            let idea = Idea(
                title: "",
                notes: normalizedNotes,
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
            saveErrorMessage = "메모를 저장하지 못했습니다."
        }
    }
}

#Preview {
    NavigationStack {
        IdeaEditorView()
    }
    .modelContainer(for: Idea.self, inMemory: true)
}
