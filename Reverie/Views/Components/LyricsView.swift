//
//  LyricsView.swift
//  Reverie
//
//  Phase 2D: Synced lyrics display with auto-scroll, tap-to-seek, blur background.
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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    // Top spacer so first line can be centered
                    Spacer()
                        .frame(height: 120)

                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = index == activeIndex
                        let isPast = activeIndex != nil && index < activeIndex!

                        Text(line.text)
                            .font(.title2)
                            .fontWeight(isActive ? .bold : .medium)
                            .foregroundStyle(
                                isActive ? .primary :
                                isPast ? .secondary.opacity(0.5) :
                                .secondary.opacity(0.7)
                            )
                            .scaleEffect(isActive ? 1.05 : 1.0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 4)
                            .id(line.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSeek(line.time)
                            }
                            .animation(.easeInOut(duration: 0.3), value: isActive)
                    }

                    // Bottom spacer so last line can be centered
                    Spacer()
                        .frame(height: 200)
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
                guard !hasUserScrolled, let newIndex = newIndex,
                      newIndex < lines.count else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)

                Color.white

                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
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
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)

                Color.white

                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
            }
        )
    }
}
