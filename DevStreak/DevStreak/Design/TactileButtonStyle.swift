//
//  TactileButtonStyle.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct TactileButtonStyle: ButtonStyle {
    var tint: Color = DesignTokens.Color.accent
    var isProminent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.headline)
            .foregroundStyle(isProminent ? .white : tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .fill(isProminent ? tint : tint.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                            .stroke(isProminent ? Color.clear : DesignTokens.Color.hairline, lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
