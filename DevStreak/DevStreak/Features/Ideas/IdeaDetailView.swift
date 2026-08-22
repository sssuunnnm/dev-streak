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
            Section {
                Text(idea.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DesignTokens.Color.primaryText)
                    .padding(.vertical, 4)
            } header: {
                Text("제목")
            }

            Section("메모") {
                Text(idea.notes.isEmpty ? "메모가 없습니다." : idea.notes)
                    .foregroundStyle(idea.notes.isEmpty ? .secondary : .primary)
            }

            Section("태그") {
                if idea.tags.isEmpty {
                    Text("태그가 없습니다.")
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                } else {
                    FlowTagLayout(tags: idea.tags)
                }
            }

            Section("상태") {
                Label(idea.status.title, systemImage: idea.status.detailIconName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            Section {
                Button {
                    writeWithClaude()
                } label: {
                    Label("Claude로 글쓰기", systemImage: "doc.on.clipboard")
                }

                Button {
                    updateStatus(.used)
                } label: {
                    Label("사용함으로 표시", systemImage: "checkmark.circle")
                }
                .disabled(idea.status == .used)

                if idea.status == .archived {
                    Button {
                        updateStatus(.inbox)
                    } label: {
                        Label("Inbox로 복구", systemImage: "arrow.uturn.backward")
                    }
                } else {
                    Button {
                        updateStatus(.archived)
                    } label: {
                        Label("보관하기", systemImage: "archivebox")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    isShowingDeleteConfirmation = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
        }
        .navigationTitle("Idea")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditor = true
                } label: {
                    Label("수정", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            NavigationStack {
                IdeaEditorView(idea: idea)
            }
        }
        .confirmationDialog("이 Idea를 삭제할까요?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive, action: deleteIdea)
            Button("취소", role: .cancel) {}
        }
    }

    private func writeWithClaude() {
        UIPasteboard.general.string = promptService.prompt(for: idea)
        actionMessage = "프롬프트를 클립보드에 복사했습니다."

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
            actionMessage = "변경사항을 저장하지 못했습니다."
            return false
        }
    }
}

private struct FlowTagLayout: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(title: tag)
                }
            }
        }
    }
}

private extension IdeaStatus {
    var detailIconName: String {
        switch self {
        case .inbox:
            "tray"
        case .used:
            "checkmark.circle"
        case .archived:
            "archivebox"
        }
    }
}

#Preview {
    NavigationStack {
        IdeaDetailView(idea: Idea(title: "SwiftData and Widgets", notes: "App Group notes", tags: ["swift", "ios"]))
    }
    .modelContainer(for: Idea.self, inMemory: true)
}
