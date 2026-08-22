//
//  SoftDepthCard.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct SoftDepthCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = DesignTokens.Spacing.card, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(DesignTokens.Color.surfaceElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                            .stroke(DesignTokens.Color.hairline, lineWidth: 1)
                    }
            }
    }
}
