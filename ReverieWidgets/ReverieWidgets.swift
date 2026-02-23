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

// MARK: - Queue Track (for Up Next in Large widget)

struct QueueTrack: Codable, Identifiable {
    let id: String
    let title: String
    let artist: String
}

// MARK: - Widget Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let trackTitle: String?
    let trackArtist: String?
    let albumArt: Data?
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let upNext: [QueueTrack]
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
            duration: 180,
            upNext: [
                QueueTrack(id: "1", title: "Next Song", artist: "Artist"),
                QueueTrack(id: "2", title: "Another Song", artist: "Artist"),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.reverie.shared")

        let trackTitle = sharedDefaults?.string(forKey: "currentTrackTitle")
        let trackArtist = sharedDefaults?.string(forKey: "currentTrackArtist")
        let albumArt = sharedDefaults?.data(forKey: "currentTrackAlbumArt")
        let isPlaying = sharedDefaults?.bool(forKey: "isPlaying") ?? false
        let currentTime = sharedDefaults?.double(forKey: "currentTime") ?? 0
        let duration = sharedDefaults?.double(forKey: "duration") ?? 0

        // Read up-next queue (JSON-encoded array of QueueTrack)
        var upNext: [QueueTrack] = []
        if let queueData = sharedDefaults?.data(forKey: "upNextQueue") {
            upNext = (try? JSONDecoder().decode([QueueTrack].self, from: queueData)) ?? []
        }

        let entry = NowPlayingEntry(
            date: Date(),
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            albumArt: albumArt,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration,
            upNext: Array(upNext.prefix(4))
        )

        let nextUpdate = isPlaying ? Date().addingTimeInterval(10) : Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
}

// MARK: - Widget View Router

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

// MARK: - systemSmall: Album art fills widget, title overlaid with gradient

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

// MARK: - systemMedium: Album art left, title+artist+controls right

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

// MARK: - systemLarge: Current track (medium layout) + Up Next queue

struct LargeNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        VStack(spacing: 0) {
            // Current track section (medium-style layout)
            if let title = entry.trackTitle {
                HStack(spacing: 12) {
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
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .widgetAccentable()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)

                        if let artist = entry.trackArtist {
                            Text(artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Progress bar
                        if entry.duration > 0 {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(.quaternary)
                                        .frame(height: 3)

                                    Capsule()
                                        .fill(.primary)
                                        .frame(width: geometry.size.width * (entry.currentTime / entry.duration), height: 3)
                                }
                            }
                            .frame(height: 3)
                        }

                        // Controls
                        HStack(spacing: 20) {
                            Button(intent: SkipBackwardIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.body)
                            }
                            .buttonStyle(.plain)

                            Button(intent: PlayPauseIntent()) {
                                Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            Button(intent: SkipForwardIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.body)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            if entry.duration > 0 {
                                Text(formatTime(entry.currentTime))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()

                                Text("/")
                                    .font(.caption2)
                                    .foregroundStyle(.quaternary)

                                Text(formatTime(entry.duration))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.bottom, 12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                    Text("No track playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Up Next section
            if !entry.upNext.isEmpty {
                Divider()
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("UP NEXT")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)

                    ForEach(entry.upNext) { track in
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(track.title)
                                    .font(.caption)
                                    .lineLimit(1)

                                Text(track.artist)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
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

// MARK: - accessoryCircular: Album art cropped to circle

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

// MARK: - accessoryRectangular: Title + artist + progress bar

struct RectangularNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            Spacer()

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

// MARK: - accessoryInline: "Title - Artist" text

struct InlineNowPlayingWidget: View {
    let entry: NowPlayingEntry

    var body: some View {
        if let title = entry.trackTitle {
            if let artist = entry.trackArtist {
                Text("\(title) - \(artist)")
            } else {
                Text(title)
            }
        } else {
            Text("Reverie")
        }
    }
}

// MARK: - Widget Configuration

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
        duration: 245,
        upNext: []
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
        duration: 354,
        upNext: []
    )
}

#Preview("Large Widget - Playing", as: .systemLarge) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Strobe",
        trackArtist: "deadmau5",
        albumArt: nil,
        isPlaying: true,
        currentTime: 142,
        duration: 620,
        upNext: [
            QueueTrack(id: "1", title: "One More Time", artist: "Daft Punk"),
            QueueTrack(id: "2", title: "Midnight City", artist: "M83"),
            QueueTrack(id: "3", title: "The Less I Know The Better", artist: "Tame Impala"),
            QueueTrack(id: "4", title: "Get Lucky", artist: "Daft Punk"),
        ]
    )
}

#Preview("Large Widget - Empty Queue", as: .systemLarge) {
    ReverieNowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        trackTitle: "Strobe",
        trackArtist: "deadmau5",
        albumArt: nil,
        isPlaying: false,
        currentTime: 0,
        duration: 620,
        upNext: []
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
        duration: 320,
        upNext: []
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
        duration: 217,
        upNext: []
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
        duration: 248,
        upNext: []
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
        duration: 0,
        upNext: []
    )
}

#endif
