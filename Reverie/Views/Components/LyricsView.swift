//
//  LyricsView.swift
//  Reverie
//
//  Restyled to match the Canopy.html ScreenLyrics spec: centered
//  display-serif lines at 22-28pt, rgba(1) on the current + next line,
//  rgba(0.35-0.6) on surrounding context, gentle auto-centering with a
//  3-second pause when the user scrolls manually.
//

import SwiftUI

struct LyricsView: View {
    let lines: [LRCParser.LyricLine]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var hasUserScrolled = false
    @State private var scrollResetTask: Task<Void, Never>?

    private var activeIndex: Int? {
        LRCParser.activeLine(at: currentTime, in: lines)
    }

    @ViewBuilder
    private func lyricRow(index: Int, line: LRCParser.LyricLine) -> some View {
        let distance = distanceFromActive(index: index)
        let (opacity, weight, size): (Double, Font.Weight, CGFloat) = styleFor(distance: distance)
        Text(line.text)
            .font(.system(size: size, weight: weight, design: .serif))
            .foregroundStyle(Color.white.opacity(opacity))
            .kerning(-0.3)
            .lineSpacing(4)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 8)
            .id(line.id)
            .contentShape(Rectangle())
            .onTapGesture { onSeek(line.time) }
            .animation(.easeInOut(duration: 0.3), value: activeIndex)
    }

    /// Distance from the current active line (0 = active, ±n = away). Used to
    /// taper opacity and weight so the active + next line "sing" and others
    /// fade into context, matching the spec's rgba opacity ladder.
    private func distanceFromActive(index: Int) -> Int {
        guard let active = activeIndex else { return Int.max }
        return index - active
    }

    private func styleFor(distance: Int) -> (Double, Font.Weight, CGFloat) {
        switch distance {
        case 0:  return (1.00, .bold, 28)
        case 1:  return (1.00, .semibold, 26)
        case -1: return (0.60, .medium, 22)
        case 2:  return (0.55, .medium, 22)
        case -2...(-1): return (0.45, .regular, 22)
        case 3...Int.max: return (0.35, .regular, 22)
        default: return (0.25, .regular, 22)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 120)
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        lyricRow(index: index, line: line)
                    }
                    Color.clear.frame(height: 200)
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    hasUserScrolled = true
                    scrollResetTask?.cancel()
                    scrollResetTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        if !Task.isCancelled {
                            hasUserScrolled = false
                        }
                    }
                }
            )
            .onChange(of: activeIndex) { _, newIndex in
                guard !hasUserScrolled,
                      let newIndex = newIndex,
                      newIndex < lines.count else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 80)
                Color.white
                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 80)
            }
        )
    }
}

// MARK: - Plain Lyrics View (non-synced fallback)

struct PlainLyricsView: View {
    let lyrics: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(lyrics)
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(Color.white.opacity(0.75))
                .kerning(-0.3)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                Color.white
                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
            }
        )
    }
}
