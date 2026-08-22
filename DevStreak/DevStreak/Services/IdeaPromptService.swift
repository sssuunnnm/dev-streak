//
//  IdeaPromptService.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

struct IdeaPromptService {
    func canCreatePrompt(for idea: Idea) -> Bool {
        idea.hasMemoContent
    }

    func prompt(for idea: Idea) -> String {
        let memo = idea.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "우선 CONVENTIONS.md와 DESIGN_RULES.md를 따르고, 기존 Dev Archive 글의 구조와 문체를 참고해줘.",
            "",
            memo,
            "",
            "이러한 주제로 글을 써보고 싶은데 기술적/흐름적으로 괜찮은지 검토해줘."
        ].joined(separator: "\n")
    }
}
