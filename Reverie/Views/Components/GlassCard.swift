//
//  GlassCard.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI

/// Reusable Liquid Glass effect container
struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    init(
        cornerRadius: CGFloat = Constants.defaultCornerRadius,
        padding: CGFloat = Constants.defaultPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack {
                Text("Glass Card")
                    .font(.headline)
                Text("With Liquid Glass Effect")
                    .font(.caption)
            }
        }
        
        GlassCard(cornerRadius: 16, padding: 12) {
            HStack {
                Image(systemName: "music.note")
                Text("Custom Glass Card")
            }
        }
    }
    .padding()
    .background(Color.blue.gradient)
}
