//
//  NowPlayingBar.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
import MediaPlayer
import AVKit
#elseif canImport(AppKit)
import AppKit
#endif

struct NowPlayingBar: View {
    @Bindable var player: AudioPlayer
    let accentColor: Color
    var onExpandToggle: (() -> Void)? = nil
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
                    #if os(macOS)
                    // On macOS, toggle the inspector panel via callback
                    onExpandToggle?()
                    #else
                    if reduceMotion {
                        isExpanded.toggle()
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
                    #endif
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: player.currentTrack?.id)
                #if !os(macOS)
                .fullScreenCover(isPresented: $isExpanded) {
                    FullPlayerView(
                        player: player,
                        dominantColor: accentColor,
                        namespace: nowPlayingNamespace
                    )
                }
                #endif
        }
    }

    private var miniBar: some View {
        VStack(spacing: 0) {
            // Thin progress line along top edge. Uses the Canopy green so it
            // reads consistently against the paper background regardless of
            // the current cover's extracted color.
            if player.duration > 0 {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(CanopyTheme.Palette.green.gradient)
                        .frame(width: geometry.size.width * (player.currentTime / player.duration))
                }
                .frame(height: 2)
            }

            HStack(spacing: 0) {
                // Album art (40pt) with glow effect
                ZStack {
                    if !reduceTransparency {
                        NowPlayingArtwork(
                            imageData: player.currentTrack?.albumArtData,
                            size: 40,
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
                        size: 40,
                        cornerRadius: 8,
                        shadowRadius: 4,
                        namespace: nowPlayingNamespace,
                        isSource: true
                    )
                }
                .padding(.trailing, 12)
                .accessibilityHidden(true)

                // Track info: title + artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTrack?.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(player.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 12)

                // Play/Pause + Skip
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
                        Group {
                            if player.isLoadingTrack {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityLabel(player.isLoadingTrack ? "Loading" : (player.isPlaying ? "Pause" : "Play"))
                    .disabled(player.isLoadingTrack)

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
        }
        .background(barBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // Shadow tinted with the Canopy forest-green so the mini player
        // "sits on paper" the same way the spec's CMiniPlayer does.
        .shadow(
            color: Color(red: 20/255, green: 60/255, blue: 40/255)
                .opacity(reduceTransparency ? 0 : 0.08),
            radius: 28, y: 8
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(CanopyTheme.Palette.hair, lineWidth: 0.5)
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.width < -60 {
                        player.skipToNext()
                        HapticManager.shared.skip()
                    }
                }
        )
        .contextMenu {
            if let track = player.currentTrack {
                Text(track.title)

                Button {
                    player.skipToNext()
                } label: {
                    Label("Skip to Next", systemImage: "forward.fill")
                }

                Button {
                    player.skipToPrevious()
                } label: {
                    Label("Previous Track", systemImage: "backward.fill")
                }

                Divider()

                Button {
                    player.stop()
                } label: {
                    Label("Stop Playback", systemImage: "stop.fill")
                }
            }
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

    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showArtistDetail = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Full-bleed album art background with blur + dark gradient
                backgroundView
                    .ignoresSafeArea()

                // Layer 2: Content
                VStack(spacing: 0) {
                    // Top bar: drag indicator + AirPlay/quality
                    topBar
                        .padding(.top, 12)
                        .padding(.horizontal, 28)

                    if showLyrics {
                        lyricsOverlay
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        mainContent(screenWidth: geo.size.width)
                            .transition(.opacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLyrics)
        .animation(.easeInOut(duration: 0.5), value: dominantColor)
        #if !os(macOS)
        .offset(y: dragOffset)
        .gesture(dismissDragGesture)
        #endif
        .focusedValue(\.toggleLyricsAction) {
            withAnimation { showLyrics.toggle() }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet(player: player, accentColor: dominantColor)
                #if !os(macOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #endif
        }
        .sheet(isPresented: $showArtistDetail) {
            if let artist = player.currentTrack?.artist, !artist.isEmpty {
                ArtistDetailView(artistName: artist, audioPlayer: player)
                    #if !os(macOS)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    #endif
            }
        }
    }

    // MARK: - Dismiss Gesture

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .global)
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 150 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Background — silky-blue gradient per the Canopy spec
    //
    // The spec is explicit that the full-screen player carries the brand's
    // silky blue moment (deep teal #083D48 → sky mist #D2ECF2). Atmospheric
    // radial blobs add the "shine" that the spec's SVG filter produces.
    // The current track's dominant color still bleeds in as a soft tint so
    // the player subtly responds to the cover on screen.

    private var backgroundView: some View {
        ZStack {
            CanopyTheme.silkyBlue

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                ZStack {
                    Circle()
                        .fill(CanopyTheme.Palette.blueMist.opacity(0.45))
                        .frame(width: w * 1.2, height: w * 1.2)
                        .blur(radius: 80)
                        .offset(x: -w * 0.35, y: -h * 0.28)
                    Circle()
                        .fill(CanopyTheme.Palette.mint.opacity(0.32))
                        .frame(width: w * 0.9, height: w * 0.9)
                        .blur(radius: 70)
                        .offset(x: w * 0.35, y: h * 0.18)
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: w * 0.7, height: w * 0.7)
                        .blur(radius: 60)
                        .offset(x: -w * 0.1, y: h * 0.42)
                }
            }

            if !reduceTransparency {
                LinearGradient(
                    colors: [dominantColor.opacity(0.18), .clear],
                    startPoint: .top, endPoint: .center
                )
                .blendMode(.plusLighter)
            }

            // Subtle bottom vignette so the transport controls read clearly.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18)],
                startPoint: .center, endPoint: .bottom
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 12) {
            // Drag indicator
            #if !os(macOS)
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 5)
            #endif

            // Close / AirPlay / Quality / Lyrics / Queue
            HStack(spacing: 10) {
                #if os(iOS)
                // Explicit close — discoverable fallback for the drag-to-dismiss.
                Button {
                    dismiss()
                    HapticManager.shared.tap()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.14)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close player")

                AirPlayRoutePickerView()
                    .frame(width: 28, height: 28)
                #endif

                qualityLabel

                Spacer()

                // Lyrics button
                Button {
                    withAnimation {
                        showLyrics.toggle()
                    }
                    HapticManager.shared.tap()
                } label: {
                    Image(systemName: "quote.bubble")
                        .font(.body.weight(.medium))
                        .foregroundStyle(showLyrics ? dominantColor : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showLyrics ? "Hide Lyrics" : "Show Lyrics")

                // Queue button
                Button {
                    showQueue = true
                    HapticManager.shared.tap()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Queue")
            }
        }
    }

    // MARK: - Save-to-library (streaming → download)
    //
    // When the user is previewing a track that isn't in their library yet
    // (Discover/Search → streamRemote), we surface a clearly-labelled Save
    // button right under the track title. Tapping it kicks off the full-
    // quality download and, once complete, AudioPlayer auto-transitions
    // from streaming to local playback via `transitionToLocalPlayback`.

    @Environment(\.modelContext) private var modelContext
    @State private var isSavingCurrent = false

    private var shouldShowSaveAction: Bool {
        guard let track = player.currentTrack else { return false }
        return track.downloadState != .downloaded && player.isStreaming
    }

    private var saveToLibraryAction: some View {
        HStack(spacing: 10) {
            Image(systemName: isSavingCurrent ? "arrow.down.circle" : "arrow.down.to.line")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 1) {
                Text(isSavingCurrent ? "Saving to your library…" : "Save to library")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(isSavingCurrent
                     ? "Playback will switch to offline when it finishes."
                     : "Download the full track for offline playback.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isSavingCurrent {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Button {
                    Task { await saveCurrentTrack() }
                } label: {
                    Text("Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CanopyTheme.Palette.blueDeep)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save to library")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }

    /// Persists the current streaming placeholder into the user's SwiftData
    /// library and kicks off a full-quality download. AudioPlayer's
    /// transitionToLocalPlayback swaps the stream for the local file once
    /// the download finishes — the user doesn't need to re-tap play.
    private func saveCurrentTrack() async {
        guard let ephemeral = player.currentTrack,
              let videoID = ephemeral.youtubeVideoID else { return }

        isSavingCurrent = true
        defer { isSavingCurrent = false }

        // Re-materialise the track in the real (persistent) ModelContainer
        // so it shows up in the library and survives relaunches.
        let real = ReverieTrack(
            title: ephemeral.title,
            artist: ephemeral.artist,
            album: ephemeral.album,
            durationSeconds: ephemeral.durationSeconds,
            albumArtData: ephemeral.albumArtData,
            youtubeVideoID: videoID,
            downloadState: .queued
        )
        modelContext.insert(real)
        try? modelContext.save()

        // Kick off the download and let AudioPlayer switch to the local
        // file transparently when it completes.
        try? await player.downloadManager.downloadTrack(real, modelContext: modelContext)
        await player.transitionToLocalPlayback(track: real)
    }

    private var qualityLabel: some View {
        Group {
            if player.isLoadingTrack {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                    Text("Loading preview…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if player.isStreaming {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.white.opacity(0.18))
                    )
            } else if let bitrate = player.currentTrack?.bitrate {
                Text("\(bitrate)k")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("256k")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Main Content

    private func mainContent(screenWidth: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // Album art
                albumArtSection(screenWidth: screenWidth)

                // Track info
                trackInfoSection

                // Save-to-library banner for non-downloaded (preview) tracks.
                // Makes the preview → full-download flow obvious without
                // forcing the user into the Settings or another screen.
                if shouldShowSaveAction {
                    saveToLibraryAction
                        .padding(.horizontal, 28)
                }

                // Progress bar
                progressSection
                    .padding(.horizontal, 28)

                // Waveform only makes sense with a local file (AVAudioEngine
                // metering). For streaming previews we hide it.
                if !player.isStreaming {
                    waveformSection
                        .padding(.horizontal, 28)
                }

                // Transport controls
                transportControls
                    .padding(.horizontal, 28)

                // Volume
                volumeSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Album Art

    private func albumArtSection(screenWidth: CGFloat) -> some View {
        let artSize: CGFloat = {
            #if os(macOS)
            return min(screenWidth - 60, 280)
            #else
            return min(screenWidth - 80, 320)
            #endif
        }()

        return NowPlayingArtwork(
            imageData: player.currentTrack?.albumArtData,
            size: artSize,
            cornerRadius: 12,
            shadowRadius: 24,
            namespace: namespace,
            isSource: false
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .scaleEffect(player.isPlaying ? 1.0 : 0.96)
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7),
            value: player.isPlaying
        )
        .accessibilityHidden(true)
    }

    // MARK: - Track Info

    private var trackInfoSection: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? "")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                guard let artist = player.currentTrack?.artist, !artist.isEmpty else { return }
                HapticManager.shared.tap()
                showArtistDetail = true
                _ = artist
            } label: {
                HStack(spacing: 4) {
                    Text(player.currentTrack?.artist ?? "")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    if player.currentTrack?.artist.isEmpty == false {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Artist: \(player.currentTrack?.artist ?? "")")
            .accessibilityHint("See all songs by this artist")

            if let album = player.currentTrack?.album, !album.isEmpty {
                Text(album)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Progress Bar with Custom Scrubbing

    private var progressSection: some View {
        VStack(spacing: 8) {
            // Custom progress slider with enlarged hit area
            GeometryReader { geometry in
                let progress = isScrubbing
                    ? scrubTime / max(player.duration, 1)
                    : player.currentTime / max(player.duration, 1)
                let thumbX = geometry.size.width * progress

                ZStack(alignment: .leading) {
                    // Scrubber track — spec uses a thin white rail over the
                    // silky blue gradient (rgba 0.2) with a pure-white fill.
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: isScrubbing ? 6 : 4)

                    // Progress fill — solid white per spec.
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(thumbX, 0), height: isScrubbing ? 6 : 4)

                    // Dot handle — always visible at the head of the fill,
                    // 12pt white disc with a soft drop shadow (ScreenPlayer).
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        .position(x: max(min(thumbX, geometry.size.width), 0), y: geometry.size.height / 2)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            let fraction = max(0, min(value.location.x / geometry.size.width, 1))
                            scrubTime = fraction * player.duration
                        }
                        .onEnded { _ in
                            player.seek(to: scrubTime)
                            isScrubbing = false
                            HapticManager.shared.tap()
                        }
                )
                .animation(.easeOut(duration: 0.15), value: isScrubbing)

                // Time tooltip above thumb when scrubbing
                if isScrubbing {
                    Text(formatTime(scrubTime))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                        .position(
                            x: max(min(thumbX, geometry.size.width - 20), 20),
                            y: -12
                        )
                }
            }
            .frame(height: 44)

            // Time labels
            HStack {
                Text(formatTime(isScrubbing ? scrubTime : player.currentTime))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Text("-" + formatTime(max(player.duration - (isScrubbing ? scrubTime : player.currentTime), 0)))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Waveform

    private var waveformSection: some View {
        WaveformView(
            levels: player.waveformLevels,
            color: dominantColor,
            isPlaying: player.isPlaying
        )
        .frame(height: 48)
        .accessibilityHidden(true)
    }

    // MARK: - Transport Controls
    //
    // Straight Apple-style row: shuffle · previous · play/pause · next · repeat.
    // All SF Symbols, consistent weights, no oversized glass disc — the kind of
    // layout you'd see in Music.app. Sizing follows HIG: 44-pt tap targets, the
    // play/pause glyph is heavier to draw focus but not boxed or shadowed.

    private var transportControls: some View {
        HStack(spacing: 0) {
            transportIconButton(
                systemName: "shuffle",
                size: 20,
                isActive: player.playbackQueue.shuffleEnabled,
                label: "Shuffle"
            ) {
                player.playbackQueue.shuffleEnabled.toggle()
                HapticManager.shared.tap()
            }

            Spacer(minLength: 0)

            transportIconButton(
                systemName: "backward.fill",
                size: 28,
                label: "Previous Track"
            ) {
                player.skipToPrevious()
                HapticManager.shared.tap()
            }

            Spacer(minLength: 0)

            // Play / pause — largest glyph, no bespoke disc. `.symbolEffect`
            // gives the subtle Apple crossfade between play.fill ↔ pause.fill.
            Button {
                if reduceMotion {
                    player.togglePlayPause()
                } else {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        player.togglePlayPause()
                    }
                }
                HapticManager.shared.playPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .contentTransition(.symbolEffect(.replace))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Spacer(minLength: 0)

            transportIconButton(
                systemName: "forward.fill",
                size: 28,
                label: "Next Track"
            ) {
                player.skipToNext()
                HapticManager.shared.tap()
            }

            Spacer(minLength: 0)

            transportIconButton(
                systemName: player.playbackQueue.repeatMode == .one ? "repeat.1" : "repeat",
                size: 20,
                isActive: player.playbackQueue.repeatMode != .off,
                label: "Repeat"
            ) {
                cycleRepeatMode()
                HapticManager.shared.tap()
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func transportIconButton(
        systemName: String,
        size: CGFloat,
        isActive: Bool = false,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(isActive ? dominantColor : .white.opacity(0.9))
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Cycle repeat through off → all → one. Matches the behaviour expected
    /// by the small repeat glyph in the transport row.
    private func cycleRepeatMode() {
        switch player.playbackQueue.repeatMode {
        case .off: player.playbackQueue.repeatMode = .all
        case .all: player.playbackQueue.repeatMode = .one
        case .one: player.playbackQueue.repeatMode = .off
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))

            Slider(
                value: Binding(
                    get: { Double(player.volume) },
                    set: { player.volume = Float($0) }
                ),
                in: 0...1
            )
            .tint(dominantColor)
            .accessibilityLabel("Volume")

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Lyrics Overlay

    private var lyricsOverlay: some View {
        VStack(spacing: 0) {
            if let syncedData = player.currentTrack?.syncedLyrics,
               let lrcString = String(data: syncedData, encoding: .utf8) {
                let lines = LRCParser.parse(lrcString)
                if !lines.isEmpty {
                    LyricsView(
                        lines: lines,
                        currentTime: player.currentTime,
                        onSeek: { time in player.seek(to: time) }
                    )
                } else {
                    noLyricsView
                }
            } else if let plainLyrics = player.currentTrack?.lyrics, !plainLyrics.isEmpty {
                PlainLyricsView(lyrics: plainLyrics)
            } else {
                noLyricsView
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 80 {
                        withAnimation { showLyrics = false }
                    }
                }
        )
    }

    private var noLyricsView: some View {
        ContentUnavailableView {
            Label("No Lyrics", systemImage: "quote.bubble")
                .foregroundStyle(.white.opacity(0.6))
        } description: {
            Text("Lyrics are not available for this track.")
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AirPlay Route Picker (iOS)

#if os(iOS)
struct AirPlayRoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .white
        picker.activeTintColor = UIColor(.accentColor)
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif

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
        .shadow(color: .black.opacity(shadowRadius > 0 ? 0.3 : 0), radius: shadowRadius, y: shadowRadius > 0 ? 8 : 0)
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
