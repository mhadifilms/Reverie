//
//  NowPlayingBar.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct NowPlayingBar: View {
    @Bindable var player: AudioPlayer
    let accentColor: Color
    @State private var isExpanded = false
    @Namespace private var nowPlayingNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if player.currentTrack != nil {
            miniBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onTapGesture {
                    if reduceMotion {
                        isExpanded.toggle()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: player.currentTrack?.id)
                #if os(macOS)
                .sheet(isPresented: $isExpanded) {
                    FullPlayerView(
                        player: player,
                        dominantColor: accentColor,
                        namespace: nowPlayingNamespace
                    )
                    .frame(minWidth: 520, minHeight: 680)
                }
                #else
                .sheet(isPresented: $isExpanded) {
                    FullPlayerView(
                        player: player,
                        dominantColor: accentColor,
                        namespace: nowPlayingNamespace
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
                #endif
        }
    }

    private var miniBar: some View {
        HStack(spacing: 12) {
            NowPlayingArtwork(
                imageData: player.currentTrack?.albumArtData,
                size: 44,
                cornerRadius: 8,
                shadowRadius: 0,
                namespace: nowPlayingNamespace,
                isSource: true
            )
            .accessibilityHidden(true)

            NowPlayingTrackInfo(
                title: player.currentTrack?.title ?? "",
                subtitle: player.currentTrack?.artist ?? "",
                alignment: .leading
            )
            .lineLimit(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                Button {
                    if reduceMotion {
                        player.togglePlayPause()
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            player.togglePlayPause()
                        }
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Next Track")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(barFillStyle)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.35), lineWidth: 0.5)
        }
        .tint(accentColor)
    }

    private var barFillStyle: AnyShapeStyle {
        if reduceTransparency {
            #if os(macOS)
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            #else
            return AnyShapeStyle(Color(.systemBackground))
            #endif
        }

        #if os(macOS)
        return AnyShapeStyle(.regularMaterial)
        #else
        return AnyShapeStyle(.ultraThinMaterial)
        #endif
    }
}

// MARK: - Full Player

struct FullPlayerView: View {
    @Bindable var player: AudioPlayer
    let dominantColor: Color
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 20) {
            header

            NowPlayingArtwork(
                imageData: player.currentTrack?.albumArtData,
                size: artworkSize,
                cornerRadius: 16,
                shadowRadius: 12,
                namespace: namespace,
                isSource: false
            )
            .accessibilityHidden(true)

            NowPlayingTrackInfo(
                title: player.currentTrack?.title ?? "",
                subtitle: player.currentTrack?.artist ?? "",
                detail: player.currentTrack?.album,
                alignment: .center
            )
            .multilineTextAlignment(.center)

            progressSection

            waveformSection

            playbackControls

            volumeSection

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .frame(minWidth: 520, minHeight: 640)
        .background(backgroundView.ignoresSafeArea())
        .tint(dominantColor)
    }

    private var header: some View {
        #if os(macOS)
        return AnyView(
            HStack {
                Text("Now Playing")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
        )
        #else
        return AnyView(
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 4)
        )
        #endif
    }

    private var artworkSize: CGFloat {
        #if os(macOS)
        return 240
        #else
        return 280
        #endif
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .accessibilityLabel("Playback Position")
            .accessibilityValue("\(formatTime(player.currentTime)) of \(formatTime(player.duration))")

            HStack {
                Text(formatTime(player.currentTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(player.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var waveformSection: some View {
        WaveformView(levels: player.waveformLevels, color: dominantColor)
            .frame(height: 56)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(waveformBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.separator.opacity(0.3), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var waveformBackground: AnyShapeStyle {
        if reduceTransparency {
            #if os(macOS)
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
            #else
            return AnyShapeStyle(Color(.systemBackground))
            #endif
        }

        #if os(macOS)
        return AnyShapeStyle(.thinMaterial)
        #else
        return AnyShapeStyle(.ultraThinMaterial)
        #endif
    }

    private var playbackControls: some View {
        HStack(spacing: 32) {
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous Track")

            Button {
                if reduceMotion {
                    player.togglePlayPause()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        player.togglePlayPause()
                    }
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Next Track")
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(player.volume) },
                    set: { player.volume = Float($0) }
                ),
                in: 0...1
            )
            .accessibilityLabel("Volume")

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundView: some View {
        ZStack {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
            #else
            Color(.systemBackground)
            #endif

            if !reduceTransparency {
                LinearGradient(
                    colors: [
                        dominantColor.opacity(0.18),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Shared Components

private struct NowPlayingArtwork: View {
    let imageData: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let namespace: Namespace.ID
    let isSource: Bool

    var body: some View {
        Group {
            if let imageData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
                #endif
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(shadowRadius > 0 ? 0.2 : 0), radius: shadowRadius, y: shadowRadius > 0 ? 6 : 0)
        .matchedGeometryEffect(id: "albumArt", in: namespace, isSource: isSource)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.25, weight: .light))
                    .foregroundStyle(.secondary)
            }
    }
}

private struct NowPlayingTrackInfo: View {
    let title: String
    let subtitle: String
    var detail: String? = nil
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    @Previewable @State var player = AudioPlayer()

    VStack {
        Spacer()
        NowPlayingBar(player: player, accentColor: .accentColor)
    }
    .task {
        let mockTrack = ReverieTrack(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            durationSeconds: 354,
            albumArtData: nil,
            youtubeVideoID: "preview",
            downloadState: .downloaded
        )

        try? await player.loadTrack(mockTrack)
        player.play()
    }
}
