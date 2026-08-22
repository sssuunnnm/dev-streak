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
        enum PaperlogyWeight {
            case regular
            case medium
            case semiBold
            case bold

            var postScriptName: String {
                switch self {
                case .regular:
                    return "Paperlogy-4Regular"
                case .medium:
                    return "Paperlogy-5Medium"
                case .semiBold:
                    return "Paperlogy-6SemiBold"
                case .bold:
                    return "Paperlogy-7Bold"
                }
            }
        }

        static func paperlogy(
            size: CGFloat,
            weight: PaperlogyWeight = .regular,
            relativeTo textStyle: Font.TextStyle = .body
        ) -> Font {
            Font.custom(weight.postScriptName, size: size, relativeTo: textStyle)
        }

        static let body = paperlogy(size: 16, relativeTo: .body)
        static let caption = paperlogy(size: 12, weight: .medium, relativeTo: .caption)
        static let captionStrong = paperlogy(size: 12, weight: .semiBold, relativeTo: .caption)
        static let footnote = paperlogy(size: 13, relativeTo: .footnote)
        static let subheadline = paperlogy(size: 15, relativeTo: .subheadline)
        static let headline = paperlogy(size: 17, weight: .semiBold, relativeTo: .headline)
        static let title = paperlogy(size: 34, weight: .bold, relativeTo: .largeTitle)
        static let title3 = paperlogy(size: 20, weight: .semiBold, relativeTo: .title3)
        static let heroMetric = paperlogy(size: 49, weight: .bold, relativeTo: .largeTitle)
        static let widgetMetric = paperlogy(size: 38, weight: .bold, relativeTo: .title)
        static let roundedTitle = paperlogy(size: 20, weight: .semiBold, relativeTo: .title3)
        static let roundedMetric = paperlogy(size: 22, weight: .bold, relativeTo: .title2)
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
