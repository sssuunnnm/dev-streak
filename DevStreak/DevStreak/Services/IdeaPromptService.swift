//
//  IdeaPromptService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct IdeaPromptService {
    func prompt(for idea: Idea) -> String {
        """
        Dev Archive에 다음 주제로 글을 작성하려고 합니다.

        주제:
        \(idea.title)

        메모:
        \(idea.notes)

        태그:
        \(idea.tags.joined(separator: ", "))

        CONVENTIONS.md와 DESIGN_RULES.md의 규칙을 따라주세요.
        기존 Dev Archive의 글 스타일과 구조도 참고해주세요.
        """
    }
}
