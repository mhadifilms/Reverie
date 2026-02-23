//
//  MenuBarPlayer.swift
//  Reverie
//
//  macOS menu bar player with Now Playing info and transport controls.
//

#if os(macOS)
import SwiftUI
import AppKit

struct MenuBarPlayerView: View {
    @Bindable var player: AudioPlayer
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            if let track = player.currentTrack {
                nowPlayingContent(track: track)
            } else {
                emptyState
            }

            Divider()
                .padding(.top, 8)

            // Footer
            HStack {
                Button("Open Reverie") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    // MARK: - Now Playing Content

    private func nowPlayingContent(track: ReverieTrack) -> some View {
        VStack(spacing: 12) {
            // Album art + track info
            HStack(spacing: 12) {
                albumArt(for: track)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Progress bar
            progressBar
                .padding(.horizontal, 16)

            // Transport controls
            transportControls
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Album Art

    private func albumArt(for track: ReverieTrack) -> some View {
        Group {
            if let artData = track.albumArtData,
               let nsImage = NSImage(data: artData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let progress = player.duration > 0
                    ? player.currentTime / player.duration
                    : 0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))

                    Capsule()
                        .fill(accentColor.gradient)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 3)

            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text("-" + formatTime(max(player.duration - player.currentTime, 0)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 24) {
            Spacer()

            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous Track")

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next Track")

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Not Playing")
                .font(.headline)

            Text("Play a track in Reverie to see it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
#endif
