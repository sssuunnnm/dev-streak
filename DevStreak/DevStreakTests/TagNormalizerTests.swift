//
//  TagNormalizerTests.swift
//  DevStreakTests
//
//  Created by Codex on 8/22/26.
//

import Testing
@testable import DevStreak

struct TagNormalizerTests {
    @Test func trimsTagWhitespace() {
        #expect(TagNormalizer.normalize([" swift ", "\nios\t"]) == ["swift", "ios"])
    }

    @Test func removesEmptyTags() {
        #expect(TagNormalizer.normalize(["swift", " ", "", "\n", "ios"]) == ["swift", "ios"])
    }

    @Test func removesDuplicateTags() {
        #expect(TagNormalizer.normalize(["swift", "ios", "swift", "ios"]) == ["swift", "ios"])
    }

    @Test func keepsInputOrder() {
        #expect(TagNormalizer.normalize(["swift", "swiftdata", "ios"]) == ["swift", "swiftdata", "ios"])
    }

    @Test func normalizesCommaSeparatedTags() {
        #expect(TagNormalizer.normalizeCommaSeparated(" swift, ios, swift, ,swiftdata ") == ["swift", "ios", "swiftdata"])
    }
}
