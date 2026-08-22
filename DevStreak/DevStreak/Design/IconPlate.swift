//
//  IconPlate.swift
//  DevStreak
//
//  Created by Codex on 8/22/26.
//

import SwiftUI

struct IconPlate: View {
    let systemName: String
    var tint: Color = DesignTokens.Color.accent
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
        .frame(width: size, height: size)
    }
}
