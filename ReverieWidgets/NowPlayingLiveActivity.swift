//
//  NowPlayingLiveActivity.swift
//  ReverieWidgets
//
//  Created by Claude on 2/23/26.
//

import ActivityKit
import AppIntents
import UIKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

struct NowPlayingAttributes: ActivityAttributes {
    // Fixed properties (set once when activity starts)
    var trackTitle: String
    var artistName: String
    var albumArtData: Data

    // Dynamic properties (updated throughout playback)
    public struct ContentState: Codable, Hashable {
        var isPlaying: Bool
        var progress: Double      // 0.0 – 1.0
        var elapsedSeconds: Int
        var totalSeconds: Int
    }
}

// MARK: - Live Activity Widget

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / Banner
            LockScreenBannerView(context: context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedAlbumArt(data: context.attributes.albumArtData)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedControls(isPlaying: context.state.isPlaying)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.trackTitle)
                            .font(.caption.bold())
                            .lineLimit(1)

                        Text(context.attributes.artistName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomBar(state: context.state)
                }
            } compactLeading: {
                CompactAlbumArt(data: context.attributes.albumArtData)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.variableColor.iterative, isActive: context.state.isPlaying)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .font(.caption2)
            }
            .widgetURL(URL(string: "reverie://now-playing"))
            .keylineTint(.accentColor)
        }
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<NowPlayingAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Album art
                albumArtView
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Title + Artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.trackTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(context.attributes.artistName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                // Controls
                HStack(spacing: 16) {
                    Button(intent: SkipBackwardIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)

                    Button(intent: SkipForwardIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                }
            }

            // Progress bar
            ProgressBarView(
                progress: context.state.progress,
                elapsed: context.state.elapsedSeconds,
                total: context.state.totalSeconds
            )
        }
        .padding()
    }

    @ViewBuilder
    private var albumArtView: some View {
        if let image = uiImage(from: context.attributes.albumArtData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.5))
                }
        }
    }
}

// MARK: - Dynamic Island Expanded Components

private struct ExpandedAlbumArt: View {
    let data: Data

    var body: some View {
        if let image = uiImage(from: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct ExpandedControls: View {
    let isPlaying: Bool

    var body: some View {
        Button(intent: PlayPauseIntent()) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }
}

private struct ExpandedBottomBar: View {
    let state: NowPlayingAttributes.ContentState

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 3)

                    Capsule()
                        .fill(.primary)
                        .frame(width: geometry.size.width * max(0, min(state.progress, 1)), height: 3)
                }
            }
            .frame(height: 3)

            // Time + controls
            HStack {
                Text(formatTime(state.elapsedSeconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                HStack(spacing: 24) {
                    Button(intent: SkipBackwardIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Button(intent: SkipForwardIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(formatTime(state.totalSeconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Compact Dynamic Island

private struct CompactAlbumArt: View {
    let data: Data

    var body: some View {
        if let image = uiImage(from: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        } else {
            Image(systemName: "music.note")
                .font(.caption2)
        }
    }
}

// MARK: - Shared Components

private struct ProgressBarView: View {
    let progress: Double
    let elapsed: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 3)

                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * max(0, min(progress, 1)), height: 3)
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatTime(elapsed))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()

                Spacer()

                Text(formatTime(total))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

private func uiImage(from data: Data) -> UIImage? {
    guard !data.isEmpty else { return nil }
    return UIImage(data: data)
}

// MARK: - Previews

#Preview("Lock Screen Banner", as: .content, using: NowPlayingAttributes(
    trackTitle: "Midnight City",
    artistName: "M83",
    albumArtData: Data()
)) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(isPlaying: true, progress: 0.45, elapsedSeconds: 110, totalSeconds: 245)
    NowPlayingAttributes.ContentState(isPlaying: false, progress: 0.45, elapsedSeconds: 110, totalSeconds: 245)
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: NowPlayingAttributes(
    trackTitle: "Get Lucky",
    artistName: "Daft Punk",
    albumArtData: Data()
)) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(isPlaying: true, progress: 0.6, elapsedSeconds: 149, totalSeconds: 248)
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: NowPlayingAttributes(
    trackTitle: "Lose Yourself to Dance",
    artistName: "Daft Punk",
    albumArtData: Data()
)) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(isPlaying: true, progress: 0.35, elapsedSeconds: 124, totalSeconds: 354)
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: NowPlayingAttributes(
    trackTitle: "Strobe",
    artistName: "deadmau5",
    albumArtData: Data()
)) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(isPlaying: true, progress: 0.1, elapsedSeconds: 62, totalSeconds: 620)
}
