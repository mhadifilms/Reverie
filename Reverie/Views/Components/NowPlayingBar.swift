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
        HStack(spacing: 0) {
            // Album art with glow effect
            ZStack {
                if !reduceTransparency {
                    NowPlayingArtwork(
                        imageData: player.currentTrack?.albumArtData,
                        size: 44,
                        cornerRadius: 8,
                        shadowRadius: 0,
                        namespace: nowPlayingNamespace,
                        isSource: true
                    )
                    .blur(radius: 12)
                    .opacity(0.4)
                    .scaleEffect(1.8)
                }
                
                NowPlayingArtwork(
                    imageData: player.currentTrack?.albumArtData,
                    size: 44,
                    cornerRadius: 8,
                    shadowRadius: 4,
                    namespace: nowPlayingNamespace,
                    isSource: true
                )
            }
            .padding(.trailing, 12)
            .accessibilityHidden(true)

            // Track info
            NowPlayingTrackInfo(
                title: player.currentTrack?.title ?? "",
                subtitle: player.currentTrack?.artist ?? "",
                alignment: .leading
            )
            .lineLimit(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 12)
            
            // Progress indicator
            if player.duration > 0 {
                GeometryReader { geometry in
                    Capsule()
                        .fill(.quaternary)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(accentColor.gradient)
                                .frame(width: geometry.size.width * (player.currentTime / player.duration))
                        }
                }
                .frame(width: 60, height: 3)
                .padding(.horizontal, 12)
            }

            // Playback controls
            HStack(spacing: 8) {
                Button {
                    player.skipToPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityLabel("Previous Track")
                
                Button {
                    if reduceMotion {
                        player.togglePlayPause()
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            player.togglePlayPause()
                        }
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accentColor)
                        .symbolEffect(.bounce, value: player.isPlaying)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityLabel("Next Track")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(barBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: accentColor.opacity(reduceTransparency ? 0 : 0.15), radius: 12, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .tint(accentColor)
    }
    
    @ViewBuilder
    private var barBackgroundView: some View {
        ZStack {
            if reduceTransparency {
                #if os(macOS)
                Color(nsColor: .windowBackgroundColor)
                #else
                Color(.systemBackground)
                #endif
            } else {
                #if os(macOS)
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay {
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.12),
                                accentColor.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blendMode(.plusLighter)
                    }
                #else
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.15),
                                accentColor.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blendMode(.plusLighter)
                    }
                #endif
            }
        }
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
        VStack(spacing: 0) {
            header
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 28) {
                    // Album art with enhanced visuals
                    ZStack {
                        if !reduceTransparency {
                            // Glow effect
                            NowPlayingArtwork(
                                imageData: player.currentTrack?.albumArtData,
                                size: artworkSize,
                                cornerRadius: 24,
                                shadowRadius: 0,
                                namespace: namespace,
                                isSource: false
                            )
                            .blur(radius: 40)
                            .opacity(0.5)
                            .scaleEffect(1.1)
                        }
                        
                        NowPlayingArtwork(
                            imageData: player.currentTrack?.albumArtData,
                            size: artworkSize,
                            cornerRadius: 24,
                            shadowRadius: 20,
                            namespace: namespace,
                            isSource: false
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        }
                    }
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                    // Track info with proper spacing
                    VStack(spacing: 8) {
                        Text(player.currentTrack?.title ?? "")
                            .font(.title2.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(player.currentTrack?.artist ?? "")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        if let album = player.currentTrack?.album, !album.isEmpty {
                            Text(album)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Progress
                    progressSection
                        .padding(.horizontal, 4)

                    // Waveform
                    waveformSection
                        .transition(.scale.combined(with: .opacity))

                    // Controls
                    playbackControls
                        .padding(.top, 8)

                    // Volume
                    volumeSection
                        .padding(.bottom, 20)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
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
        VStack(spacing: 12) {
            // Custom progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(.quaternary.opacity(0.5))
                        .frame(height: 6)
                    
                    // Progress fill with gradient
                    Capsule()
                        .fill(dominantColor.gradient)
                        .frame(
                            width: geometry.size.width * (player.currentTime / max(player.duration, 1)),
                            height: 6
                        )
                        .shadow(color: dominantColor.opacity(0.4), radius: 4, y: 2)
                    
                    // Interactive overlay slider (invisible)
                    Slider(
                        value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ),
                        in: 0...max(player.duration, 1)
                    )
                    .opacity(0.01) // Nearly invisible but still interactive
                    .accessibilityLabel("Playback Position")
                    .accessibilityValue("\(formatTime(player.currentTime)) of \(formatTime(player.duration))")
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 4)

            // Time labels with better spacing
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(formatTime(player.duration))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
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
        HStack(spacing: 40) {
            // Previous button
            Button {
                if reduceMotion {
                    player.skipToPrevious()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        player.skipToPrevious()
                    }
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(.quaternary.opacity(0.5))
                    }
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous Track")

            // Play/Pause button
            Button {
                if reduceMotion {
                    player.togglePlayPause()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        player.togglePlayPause()
                    }
                }
            } label: {
                ZStack {
                    // Pulsing ring when playing
                    if player.isPlaying && !reduceMotion {
                        Circle()
                            .stroke(dominantColor.opacity(0.3), lineWidth: 2)
                            .scaleEffect(1.15)
                            .opacity(0.6)
                    }
                    
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(dominantColor.gradient)
                        .symbolEffect(.bounce, value: player.isPlaying)
                        .contentTransition(.symbolEffect(.replace))
                        .shadow(color: dominantColor.opacity(0.3), radius: 12, y: 6)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            // Next button
            Button {
                if reduceMotion {
                    player.skipToNext()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        player.skipToNext()
                    }
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(.quaternary.opacity(0.5))
                    }
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next Track")
        }
    }

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption.weight(.medium))
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
                .font(.caption.weight(.medium))
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
                    .font(.title.weight(.light))
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
