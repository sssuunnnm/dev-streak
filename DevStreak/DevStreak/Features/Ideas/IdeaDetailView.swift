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
                VStack(alignment: .leading, spacing: 12) {
                    if !idea.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(idea.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Color.primaryText)
                    }

                    Text(idea.notes.isEmpty ? "메모가 없습니다." : idea.notes)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(idea.notes.isEmpty ? DesignTokens.Color.textSecondary : DesignTokens.Color.primaryText)
                }
                .padding(.vertical, 4)
            }

            if !idea.tags.isEmpty {
                Section("태그") {
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
                .disabled(!promptService.canCreatePrompt(for: idea))

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
                        Label("메모로 복구", systemImage: "arrow.uturn.backward")
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
                        .font(DesignTokens.Typography.footnote)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
        }
        .navigationTitle("아이디어 메모")
        .font(DesignTokens.Typography.body)
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
        .confirmationDialog("이 메모를 삭제할까요?", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("삭제", role: .destructive, action: deleteIdea)
            Button("취소", role: .cancel) {}
        }
    }

    private func writeWithClaude() {
        guard promptService.canCreatePrompt(for: idea) else {
            actionMessage = "메모를 입력한 뒤 Claude로 보낼 수 있습니다."
            return
        }

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
