//
//  WaveformView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let color: Color
    let barSpacing: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        levels: [Float],
        color: Color = .accentColor,
        barSpacing: CGFloat = 2
    ) {
        self.levels = levels
        self.color = color
        self.barSpacing = barSpacing
    }
    
    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let totalSpacing = barSpacing * CGFloat(count - 1)
            let barWidth = max((geo.size.width - totalSpacing) / CGFloat(count), 1.5)
            
            ZStack {
                Capsule()
                    .fill(.primary.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 4)
                
                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(levels.indices, id: \.self) { index in
                        let clamped = CGFloat(max(Constants.waveformMinLevel, min(levels[index], 1.0)))
                        let barHeight = max(clamped * geo.size.height, 2)
                        
                        RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.92), color.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: barHeight)
                            .animation(
                                reduceMotion ? nil : .interpolatingSpring(stiffness: 220, damping: 24),
                                value: levels[index]
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    WaveformView(
        levels: (0..<Constants.waveformBarCount).map { _ in Float.random(in: 0.1...1.0) },
        color: .blue
    )
    .frame(height: 60)
    .padding()
    .background(Color.black.opacity(0.1))
}
