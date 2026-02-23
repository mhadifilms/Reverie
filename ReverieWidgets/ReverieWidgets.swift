//
//  ReverieWidgets.swift
//  ReverieWidgets
//
//  Created by Muhammad Hadi Yusufali on 2/22/26.
//

import WidgetKit
import SwiftUI
import AppIntents

#if canImport(UIKit)
import UIKit

// MARK: - Widget Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let trackTitle: String?
    let trackArtist: String?
    let albumArt: Data?
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
}

// MARK: - Widget Provider

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            trackTitle: "Song Title",
            trackArtist: "Artist Name",
            albumArt: nil,
            isPlaying: false,
            currentTime: 0,
            duration: 180
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let entry = NowPlayingEntry(
            date: Date(),
            trackTitle: "Song Title",
            trackArtist: "Artist Name",
            albumArt: nil,
            isPlaying: false,
            currentTime: 0,
            duration: 180
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        // Read current track from UserDefaults (shared between app and widget)
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")

        let trackTitle = sharedDefaults?.string(forKey: "currentTrackTitle")
        let trackArtist = sharedDefaults?.string(forKey: "currentTrackArtist")
        let albumArt = sharedDefaults?.data(forKey: "currentTrackAlbumArt")
        let isPlaying = sharedDefaults?.bool(forKey: "isPlaying") ?? false
        let currentTime = sharedDefaults?.double(forKey: "currentTime") ?? 0
        let duration = sharedDefaults?.double(forKey: "duration") ?? 0

        let entry = NowPlayingEntry(
            date: Date(),
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            albumArt: albumArt,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration
        )

        // Update every 10 seconds when playing, every 5 minutes when not
        let nextUpdate = isPlaying ? Date().addingTimeInterval(10) : Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Widget Views

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallNowPlayingWidget(entry: entry)
        case .systemMedium:
            MediumNowPlayingWidget(entry: entry)
        case .systemLarge:
            LargeNowPlayingWidget(entry: entry)
        case .accessoryCircular:
            CircularNowPlayingWidget(entry: entry)
        case .accessoryRectangular:
            RectangularNowPlayingWidget(entry: entry)
        case .accessoryInline:
            InlineNowPlayingWidget(entry: entry)
        default:
            SmallNowPlayingWidget(entry: entry)
        }
    }
}

struct SmallNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        ZStack {
            if let artData = entry.albumArt,
               let image = UIImage(data: artData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ContainerRelativeShape()
                    .fill(.quaternary)
            }

            VStack {
                Spacer()

                VStack(spacing: 4) {
                    if let title = entry.trackTitle {
                        Text(title)
                            .font(.caption.bold())
                            .lineLimit(1)

                        if let artist = entry.trackArtist {
                            Text(artist)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: ContainerRelativeShape())
            }
        }
        .widgetAccentable()
    }
}

struct MediumNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        HStack(spacing: 12) {
            // Album art
            Group {
                if let artData = entry.albumArt,
                   let image = UIImage(data: artData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .widgetAccentable()

            VStack(alignment: .leading, spacing: 6) {
                if let title = entry.trackTitle {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)

                    if let artist = entry.trackArtist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Interactive controls
                    HStack(spacing: 20) {
                        Button(intent: SkipBackwardIntent()) {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)

                        Button(intent: SkipForwardIntent()) {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(.primary)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(.secondary)

                        Text("No track playing")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            Spacer()
        }
        .padding()
    }
}

struct LargeNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        VStack(spacing: 16) {
            // Album art
            Group {
                if let artData = entry.albumArt,
                   let image = UIImage(data: artData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .widgetAccentable()

            if let title = entry.trackTitle {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if let artist = entry.trackArtist {
                        Text(artist)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                // Progress bar
                if entry.duration > 0 {
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.quaternary)
                                    .frame(height: 4)

                                Capsule()
                                    .fill(.primary)
                                    .frame(width: geometry.size.width * (entry.currentTime / entry.duration), height: 4)
                            }
                        }
                        .frame(height: 4)

                        HStack {
                            Text(formatTime(entry.currentTime))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatTime(entry.duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Interactive controls
                HStack(spacing: 32) {
                    Button(intent: SkipBackwardIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                    }
                    .buttonStyle(.plain)

                    Button(intent: SkipForwardIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.primary)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No track playing")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CircularNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        ZStack {
            if let artData = entry.albumArt,
               let image = UIImage(data: artData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .widgetAccentable()
            } else {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }

            // Progress ring
            if entry.duration > 0 && entry.isPlaying {
                Circle()
                    .trim(from: 0, to: entry.currentTime / entry.duration)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
            }
        }
    }
}

struct RectangularNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let artData = entry.albumArt,
                   let image = UIImage(data: artData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .widgetAccentable()
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let title = entry.trackTitle {
                        Text(title)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .widgetAccentable()

                        if let artist = entry.trackArtist {
                            Text(artist)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                            Text("Not playing")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Play/Pause button
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .tint(.primary)
            }

            // Progress bar
            if entry.duration > 0 {
                GeometryReader { geometry in
                    Capsule()
                        .fill(.quaternary)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.primary)
                                .frame(width: geometry.size.width * (entry.currentTime / entry.duration))
                                .widgetAccentable()
                        }
                }
                .frame(height: 3)
            }
        }
    }
}

struct InlineNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        HStack(spacing: 4) {
            if let title = entry.trackTitle {
                Image(systemName: entry.isPlaying ? "play.fill" : "pause.fill")
                    .font(.caption2)
                    .widgetAccentable()

                Text(title)
                    .widgetAccentable()

                if let artist = entry.trackArtist {
                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(artist)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.caption2)
                Text("No track playing")
            }
        }
        .font(.caption)
    }
}

// MARK: - Widget Configuration

@available(iOS 17.0, *)
struct ReverieNowPlayingWidget: Widget {
    let kind: String = "ReverieNowPlaying"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    if let artData = entry.albumArt,
                       let image = UIImage(data: artData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 40)
                            .opacity(0.3)
                    } else {
                        Color.clear
                    }
                }
        }
        .configurationDisplayName("Now Playing")
        .description("See what's currently playing in Reverie.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Small Widget - Playing", as: .systemSmall) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Midnight City",
        trackArtist: "M83",
        albumArt: nil,
        isPlaying: true,
        currentTime: 125,
        duration: 245
    )
}

#Preview("Medium Widget - Playing", as: .systemMedium) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Lose Yourself to Dance",
        trackArtist: "Daft Punk",
        albumArt: nil,
        isPlaying: true,
        currentTime: 180,
        duration: 354
    )
}

#Preview("Large Widget", as: .systemLarge) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Strobe",
        trackArtist: "deadmau5",
        albumArt: nil,
        isPlaying: false,
        currentTime: 0,
        duration: 0
    )
}

#Preview("Lock Screen - Circular", as: .accessoryCircular) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "One More Time",
        trackArtist: "Daft Punk",
        albumArt: nil,
        isPlaying: true,
        currentTime: 45,
        duration: 320
    )
}

#Preview("Lock Screen - Rectangular", as: .accessoryRectangular) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "The Less I Know The Better",
        trackArtist: "Tame Impala",
        albumArt: nil,
        isPlaying: true,
        currentTime: 120,
        duration: 217
    )
}

#Preview("Lock Screen - Inline", as: .accessoryInline) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Get Lucky",
        trackArtist: "Daft Punk",
        albumArt: nil,
        isPlaying: true,
        currentTime: 90,
        duration: 248
    )
}

#Preview("Widget - Not Playing", as: .systemMedium) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: nil,
        trackArtist: nil,
        albumArt: nil,
        isPlaying: false,
        currentTime: 0,
        duration: 0
    )
}

#endif
