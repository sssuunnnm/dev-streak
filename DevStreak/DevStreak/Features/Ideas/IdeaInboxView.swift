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
            .padding(.top, 12)
            .padding(.bottom, 10)

            List {
                if filteredIdeas.isEmpty {
                    ContentUnavailableView(
                        selectedStatus.title,
                        systemImage: emptySystemImage,
                    description: Text(emptyMessage)
                    )
                } else {
                    ForEach(filteredIdeas) { idea in
                        NavigationLink {
                            IdeaDetailView(idea: idea)
                        } label: {
                            IdeaRowView(idea: idea)
                        }
                        .listRowSeparator(.visible)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Idea Inbox")
        .font(DesignTokens.Typography.body)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewIdea = true
                } label: {
                    Label("새 Idea", systemImage: "plus")
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
            "아직 Idea가 없습니다."
        case .used:
            "사용한 Idea가 없습니다."
        case .archived:
            "보관한 Idea가 없습니다."
        }
    }

    private var emptySystemImage: String {
        switch selectedStatus {
        case .inbox:
            "tray"
        case .used:
            "checkmark.circle"
        case .archived:
            "archivebox"
        }
    }

    private func refreshWidgetSnapshot() {
        widgetSnapshotService.updateSnapshot(records: records, ideas: ideas)
    }
}

private struct IdeaRowView: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: idea.status.iconName)
                    .font(.caption.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(idea.status.tint)

                Text(idea.title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Color.primaryText)
            }

            if !idea.notes.isEmpty {
                Text(idea.notes)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(2)
            }

            if !idea.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(idea.tags, id: \.self) { tag in
                            TagChip(title: tag)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 9)
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

private extension IdeaStatus {
    var iconName: String {
        switch self {
        case .inbox:
            "lightbulb"
        case .used:
            "checkmark.circle"
        case .archived:
            "archivebox"
        }
    }

    var tint: Color {
        switch self {
        case .inbox:
            DesignTokens.Color.accent
        case .used:
            DesignTokens.Color.success
        case .archived:
            DesignTokens.Color.textSecondary
        }
    }
}

#Preview {
    NavigationStack {
        IdeaInboxView()
    }
    .modelContainer(for: [DailyRecord.self, Idea.self], inMemory: true)
}
