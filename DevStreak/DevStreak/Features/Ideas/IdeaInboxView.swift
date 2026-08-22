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
    @Query(sort: \DailyRecord.dateKey, order: .reverse) private var records: [DailyRecord]

    @State private var selectedStatus = IdeaStatus.inbox
    @State private var isShowingNewIdea = false

    private let widgetSnapshotService = WidgetSnapshotService()

    private var filteredIdeas: [Idea] {
        ideas.filter { $0.status == selectedStatus }
    }

    private var widgetRefreshSignature: String {
        ideas
            .map { "\($0.id.uuidString):\($0.statusRawValue)" }
            .sorted()
            .joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Idea 상태", selection: $selectedStatus) {
                ForEach(IdeaStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignTokens.Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if filteredIdeas.isEmpty {
                IdeaEmptyState(
                    title: selectedStatus.title,
                    message: emptyMessage
                )
            } else {
                List {
                    ForEach(filteredIdeas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            IdeaRowView(idea: idea)
                        }
                        .listRowSeparator(.visible)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("아이디어 메모")
        .font(DesignTokens.Typography.body)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewIdea = true
                } label: {
                    Label("새 메모", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewIdea) {
            NavigationStack {
                IdeaEditorView()
            }
        }
        .task {
            refreshWidgetSnapshot()
        }
        .onChange(of: widgetRefreshSignature) { _, _ in
            refreshWidgetSnapshot()
        }
    }

    private var emptyMessage: String {
        switch selectedStatus {
        case .inbox:
            "아직 적어둔 메모가 없습니다."
        case .used:
            "사용한 메모가 없습니다."
        case .archived:
            "보관한 메모가 없습니다."
        }
    }

    private func refreshWidgetSnapshot() {
        widgetSnapshotService.updateSnapshot(records: records, ideas: ideas)
    }
}

private struct IdeaEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 17, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .frame(width: 36, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DesignTokens.Color.accentSoft.opacity(0.45))
                }

            Text(title)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.primaryText)

            Text(message)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.page)
    }
}

private struct IdeaRowView: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(idea.displayTitle)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Color.primaryText)
                .lineLimit(2)

            if let preview = idea.displayPreview {
                Text(preview)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(idea.createdAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    .monospacedDigit()

                Text(idea.status.title)
            }
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .padding(.vertical, 10)
    }
}

struct TagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(DesignTokens.Color.surface)
                    .overlay {
                        Capsule()
                            .stroke(DesignTokens.Color.hairline)
                    }
            }
    }
}

#Preview {
    NavigationStack {
        IdeaInboxView()
    }
    .modelContainer(for: [DailyRecord.self, Idea.self], inMemory: true)
}
