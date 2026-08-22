//
//  GitHubVerificationHelpView.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct GitHubVerificationHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let items = [
        "DevStreak는 sssuunnnm/dev-archive 저장소의 활동을 읽기 전용으로 확인합니다.",
        "오늘 기술 블로그 콘텐츠 관련 commit이 확인되면 오늘 기록을 자동 완료할 수 있습니다.",
        "src/content/articles, projects, references, snippets 경로 변경만 기록으로 인정합니다.",
        "GitHub 저장소를 수정하거나 commit, PR을 생성하지 않습니다.",
        "네트워크 오류나 GitHub API 확인 실패는 오늘 미작성으로 처리하지 않습니다.",
        "더 안정적인 확인을 위해 개인 GitHub token을 연결할 수 있습니다.",
        "token은 Keychain에 저장됩니다."
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub 기록 확인이란?")
                        .font(DesignTokens.Typography.title3)
                        .foregroundStyle(DesignTokens.Color.primaryText)

                    Text("기술 블로그 작업을 앱이 대신 확인해 오늘 기록 상태에 반영하는 기능입니다.")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }

                Divider()
                    .overlay(DesignTokens.Color.hairline)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignTokens.Color.accent)
                                .padding(.top, 3)

                            Text(item)
                                .font(DesignTokens.Typography.body)
                                .foregroundStyle(DesignTokens.Color.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                NavigationLink {
                    GitHubConnectionSettingsView()
                } label: {
                    HStack(spacing: 8) {
                        Text("GitHub 연결 설정")
                            .font(DesignTokens.Typography.footnote)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DesignTokens.Color.accent)
                }
            }
            .padding(DesignTokens.Spacing.page)
        }
        .background(Color(.systemBackground))
        .navigationTitle("도움말")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .font(DesignTokens.Typography.body)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GitHubVerificationHelpView()
    }
}
