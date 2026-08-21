//
//  TagNormalizer.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import Foundation

enum TagNormalizer {
    static func normalize(_ tags: [String]) -> [String] {
        var seenTags = Set<String>()
        var normalizedTags: [String] = []

        for tag in tags {
            let normalizedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTag.isEmpty,
                  !seenTags.contains(normalizedTag) else {
                continue
            }

            seenTags.insert(normalizedTag)
            normalizedTags.append(normalizedTag)
        }

        return normalizedTags
    }

    static func normalizeCommaSeparated(_ tagsText: String) -> [String] {
        normalize(tagsText.split(separator: ",", omittingEmptySubsequences: false).map(String.init))
    }
}
