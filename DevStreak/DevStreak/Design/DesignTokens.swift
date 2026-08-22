//
//  DesignTokens.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let page: CGFloat = 22
        static let section: CGFloat = 32
        static let card: CGFloat = 16
        static let compact: CGFloat = 8
        static let tight: CGFloat = 4
    }

    enum Radius {
        static let card: CGFloat = 12
        static let control: CGFloat = 9
        static let small: CGFloat = 7
    }

    enum Typography {
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)
        static let captionStrong = Font.system(size: 12, weight: .semibold)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let title = Font.system(size: 34, weight: .bold)
        static let title3 = Font.system(size: 20, weight: .semibold)
        static let heroMetric = Font.system(size: 49, weight: .bold)
        static let widgetMetric = Font.system(size: 38, weight: .bold)
        static let roundedTitle = Font.system(size: 20, weight: .semibold)
        static let roundedMetric = Font.system(size: 22, weight: .bold)
    }

    enum Color {
        static let accent = SwiftUI.Color(red: 0.25, green: 0.40, blue: 0.58)
        static let accentSoft = SwiftUI.Color(red: 0.25, green: 0.40, blue: 0.58).opacity(0.12)
        static let primaryText = SwiftUI.Color(red: 0.08, green: 0.12, blue: 0.18)
        static let streakWarm = SwiftUI.Color(red: 0.72, green: 0.43, blue: 0.16)
        static let streakWarmSoft = SwiftUI.Color(red: 0.72, green: 0.43, blue: 0.16).opacity(0.10)
        static let success = SwiftUI.Color.green
        static let successSoft = SwiftUI.Color.green.opacity(0.10)
        static let warning = SwiftUI.Color(red: 0.72, green: 0.43, blue: 0.16)
        static let warningSoft = SwiftUI.Color(red: 0.72, green: 0.43, blue: 0.16).opacity(0.10)
        static let missed = SwiftUI.Color(red: 0.93, green: 0.95, blue: 0.97)
        static let surface = SwiftUI.Color(red: 0.96, green: 0.97, blue: 0.98)
        static let surfaceElevated = SwiftUI.Color(red: 0.98, green: 0.99, blue: 1.00)
        static let textSecondary = SwiftUI.Color(red: 0.38, green: 0.47, blue: 0.57)
        static let hairline = SwiftUI.Color(red: 0.83, green: 0.87, blue: 0.91)
        static let highlight = SwiftUI.Color.white.opacity(0.0)
    }

    enum Depth {
        static let softShadowColor = SwiftUI.Color.black.opacity(0.0)
        static let ambientShadowColor = SwiftUI.Color.black.opacity(0.0)
        static let cardShadowRadius: CGFloat = 0
        static let cardShadowY: CGFloat = 0
        static let controlShadowRadius: CGFloat = 0
        static let controlShadowY: CGFloat = 0
    }
}
