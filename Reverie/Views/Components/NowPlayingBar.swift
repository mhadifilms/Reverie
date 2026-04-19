//
//  NowPlayingBar.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
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
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
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

    @AppStorage("vinylMode") private var vinylMode = false
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var isScrubbing = false
    @State private var scrubTime: TimeInterval = 0
    @State private var vinylRotation: Double = 0
    @State private var dragOffset: CGFloat = 0

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
        .onAppear {
            if vinylMode && player.isPlaying {
                startVinylRotation()
            }
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if vinylMode {
                if isPlaying {
                    startVinylRotation()
                }
            }
        }
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

            // AirPlay + Quality
            HStack {
                #if os(iOS)
                AirPlayRoutePickerView()
                    .frame(width: 24, height: 24)
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

    private var qualityLabel: some View {
        Group {
            if player.isStreaming {
                Text("Streaming")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
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

                // Progress bar
                progressSection
                    .padding(.horizontal, 28)

                // Waveform
                waveformSection
                    .padding(.horizontal, 28)

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

        return ZStack {
            if vinylMode && player.isPlaying {
                // Vinyl rotation mode
                NowPlayingArtwork(
                    imageData: player.currentTrack?.albumArtData,
                    size: artSize,
                    cornerRadius: artSize / 2,
                    shadowRadius: 24,
                    namespace: namespace,
                    isSource: false
                )
                .rotationEffect(.degrees(vinylRotation))
                .overlay {
                    // Vinyl center hole
                    Circle()
                        .fill(Color.black)
                        .frame(width: artSize * 0.12, height: artSize * 0.12)
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: artSize * 0.12, height: artSize * 0.12)
                }
            } else {
                NowPlayingArtwork(
                    imageData: player.currentTrack?.albumArtData,
                    size: artSize,
                    cornerRadius: 12,
                    shadowRadius: 24,
                    namespace: namespace,
                    isSource: false
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                }
                .scaleEffect(player.isPlaying ? 1.0 : 0.95)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7),
                    value: player.isPlaying
                )
            }
        }
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

            Text(player.currentTrack?.artist ?? "")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

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

    // MARK: - Transport Controls (ScreenPlayer layout)
    //
    // Five-slot row: shuffle · previous · large white play/pause disc ·
    // next · repeat. The centre button is a 72-pt white circle with the
    // player's blueDeep glyph; satellite icons are 28-pt white glyphs at
    // 0.9 opacity. Mirrors Canopy.html exactly.

    private var transportControls: some View {
        HStack(spacing: 0) {
            satelliteControl(systemName: "shuffle", isActive: player.playbackQueue.shuffleEnabled) {
                player.playbackQueue.shuffleEnabled.toggle()
                HapticManager.shared.tap()
            }
            .accessibilityLabel("Shuffle")

            Spacer(minLength: 0)

            satelliteControl(systemName: "backward.fill", size: 28) {
                player.skipToPrevious()
                HapticManager.shared.playPause()
            }
            .accessibilityLabel("Previous Track")

            Spacer(minLength: 0)

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
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(CanopyTheme.Palette.blueDeep)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Spacer(minLength: 0)

            satelliteControl(systemName: "forward.fill", size: 28) {
                player.skipToNext()
                HapticManager.shared.playPause()
            }
            .accessibilityLabel("Next Track")

            Spacer(minLength: 0)

            satelliteControl(
                systemName: player.playbackQueue.repeatMode == .one ? "repeat.1" : "repeat",
                isActive: player.playbackQueue.repeatMode != .off
            ) {
                cycleRepeatMode()
                HapticManager.shared.tap()
            }
            .accessibilityLabel("Repeat")
        }
    }

    @ViewBuilder
    private func satelliteControl(
        systemName: String,
        size: CGFloat = 18,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isActive ? 1.0 : 0.9))
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(Color.white.opacity(isActive ? 0.12 : 0))
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
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

    // MARK: - Vinyl Rotation

    private func startVinylRotation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            vinylRotation += 360
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
