//
//  ContentView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedView: SidebarItem = .library
    @Bindable var audioPlayer: AudioPlayer
    @State private var signalCollector = SignalCollector()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var accentColor: Color = .accentColor
    private let networkMonitor = NetworkMonitor.shared

    #if os(macOS)
    @Query(sort: \ReveriePlaylist.dateImported, order: .reverse) private var sidebarPlaylists: [ReveriePlaylist]
    @State private var showNowPlayingPanel = false
    @State private var selectedPlaylist: ReveriePlaylist?
    #endif

    /// When true, the app tints everything with the Canopy spec's green
    /// accent instead of the per-cover extracted color. Cover-extracted
    /// accents are still used inside the full-screen player (album header
    /// bleed) so the "bleeds cover color" behaviour from the spec's Album
    /// screen is preserved where it matters.
    @AppStorage("useCanopyAccent") private var useCanopyAccent = true

    init(audioPlayer: AudioPlayer) {
        self.audioPlayer = audioPlayer
    }

    enum SidebarItem: Hashable {
        case library
        case search
        case settings
    }

    var body: some View {
        platformContent
            .focusedValue(
                \.playPauseAction,
                audioPlayer.currentTrack == nil ? nil : { audioPlayer.togglePlayPause() }
            )
            .focusedValue(
                \.nextTrackAction,
                audioPlayer.currentTrack == nil ? nil : { audioPlayer.skipToNext() }
            )
            .focusedValue(
                \.previousTrackAction,
                audioPlayer.currentTrack == nil ? nil : { audioPlayer.skipToPrevious() }
            )
            .tint(uiAccentColor)
            .preferredColorScheme(preferredColorScheme)
            .background(CanopyTheme.Palette.paper.ignoresSafeArea())
            .onAppear {
                updateAccentColor()
                audioPlayer.signalCollector = signalCollector
                audioPlayer.signalModelContext = modelContext
            }
            .onChange(of: audioPlayer.currentTrack?.albumArtData) { _, _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    updateAccentColor()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    audioPlayer.processPendingWidgetAction()
                }
            }
    }

    @ViewBuilder
    private var platformContent: some View {
        #if os(macOS)
        macOSContent
            .focusedValue(
                \.toggleNowPlayingAction,
                audioPlayer.currentTrack == nil ? nil : { showNowPlayingPanel.toggle() }
            )
            .onChange(of: audioPlayer.currentTrack) { oldTrack, newTrack in
                if oldTrack == nil && newTrack != nil {
                    showNowPlayingPanel = true
                }
            }
        #else
        iOSContent
        #endif
    }

    #if os(macOS)
    private var macOSContent: some View {
        NavigationSplitView {
            List(selection: selectedSidebarBinding) {
                Section("Library") {
                    Label("Playlists", systemImage: "music.note.list")
                        .tag(SidebarItem.library)
                }

                if !sidebarPlaylists.isEmpty {
                    Section("Playlists") {
                        ForEach(sidebarPlaylists) { playlist in
                            Label(playlist.name, systemImage: "music.note.list")
                                .badge(playlist.trackCount)
                                .tag(SidebarItem.library)
                                .onTapGesture {
                                    selectedPlaylist = playlist
                                    selectedView = .library
                                }
                        }
                    }
                }

                Section("Discover") {
                    Label("Search", systemImage: "magnifyingglass")
                        .tag(SidebarItem.search)
                }

                Section("App") {
                    Label("Settings", systemImage: "gearshape")
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Reverie")
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        } detail: {
            detailView
                .frame(minWidth: 500, minHeight: 400)
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        .inspector(isPresented: $showNowPlayingPanel) {
            FullPlayerView(
                player: audioPlayer,
                dominantColor: accentColor,
                namespace: nowPlayingNamespace
            )
            .inspectorColumnWidth(min: 320, ideal: 360, max: 440)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if !networkMonitor.isConnected {
                    OfflineBanner()
                }
                NowPlayingBar(
                    player: audioPlayer,
                    accentColor: accentColor,
                    onExpandToggle: { showNowPlayingPanel.toggle() }
                )
            }
        }
    }
    #else
    private var iOSContent: some View {
        // Floating-chrome layout per the Canopy.html spec: the active screen
        // fills the canvas, the mini-player + tab bar float at the bottom as
        // two layered liquid-glass pills. We use `.safeAreaInset` so the
        // underlying NavigationStack reserves space for the chrome — this
        // stops its scroll content from sliding *under* the tab bar and lets
        // iOS keep the Home-indicator rounding without our pill's shadow
        // bleeding into a second phantom pill.
        Group {
            switch selectedView {
            case .library:
                LibraryView(audioPlayer: audioPlayer)
            case .search:
                SearchView(audioPlayer: audioPlayer) { selectedView = .library }
            case .settings:
                SettingsView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: CanopyTheme.Space.sm) {
                if !networkMonitor.isConnected {
                    OfflineBanner()
                }
                if audioPlayer.currentTrack != nil {
                    NowPlayingBar(player: audioPlayer, accentColor: uiAccentColor)
                }
                ReverieTabBar(active: $selectedView)
                    .padding(.horizontal, CanopyTheme.Space.md)
            }
        }
    }
    #endif

    #if os(macOS)
    @Namespace private var nowPlayingNamespace

    private var detailView: some View {
        Group {
            if let playlist = selectedPlaylist {
                PlaylistDetailView(playlist: playlist, audioPlayer: audioPlayer)
            } else {
                switch selectedView {
                case .library:
                    LibraryView(audioPlayer: audioPlayer)
                case .search:
                    SearchView(audioPlayer: audioPlayer) {
                        selectedView = .library
                    }
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private var selectedSidebarBinding: Binding<SidebarItem?> {
        Binding(
            get: { selectedView },
            set: { newValue in
                selectedPlaylist = nil
                selectedView = newValue ?? .library
            }
        )
    }
    #endif

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private func updateAccentColor() {
        guard let artData = audioPlayer.currentTrack?.albumArtData,
              let extracted = ColorExtractor.dominantColor(from: artData) else {
            accentColor = .accentColor
            return
        }

        accentColor = extracted
    }

    /// The accent applied via SwiftUI's tint — either the Canopy brand green
    /// (the spec's daily-surface rule) or the per-cover extracted color if
    /// the user has opted out of the Canopy palette.
    private var uiAccentColor: Color {
        useCanopyAccent ? CanopyTheme.Palette.greenDeep : accentColor
    }
}

// MARK: - Reverie tab bar
//
// Floating liquid-glass tab bar (iOS). Matches the Canopy.html spec's
// `CTabBar`: 64-pt tall, 32-pt radius, 72% white over ultraThinMaterial with
// a hairline border and a soft green-tinted drop shadow. The active item
// fills with `mintVeil` and switches its icon + label to `greenDeep`.

#if os(iOS)
private struct ReverieTabBar: View {
    @Binding var active: ContentView.SidebarItem

    var body: some View {
        HStack(spacing: 4) {
            item(.library, label: "Library", icon: "music.note.list")
            item(.search, label: "Search", icon: "magnifyingglass")
            item(.settings, label: "Settings", icon: "gearshape")
        }
        .padding(.horizontal, CanopyTheme.Space.xs)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        // Softer, tighter shadow so we don't ghost a second pill on paper.
        .shadow(
            color: Color(red: 20/255, green: 60/255, blue: 40/255).opacity(0.06),
            radius: 12, y: 4
        )
    }

    private func item(_ tab: ContentView.SidebarItem, label: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                active = tab
            }
            HapticManager.shared.tap()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                Text(label)
                    .font(CanopyTheme.Typography.tab)
            }
            .foregroundStyle(
                active == tab ? CanopyTheme.Palette.greenDeep : CanopyTheme.Palette.muted
            )
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(active == tab ? CanopyTheme.Palette.mintVeil : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active == tab ? .isSelected : [])
    }
}
#endif

// MARK: - Offline Banner

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
            Text("Offline -- Downloaded music still available")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.orange.gradient)
    }
}

#Preview("macOS") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReveriePlaylist.self, ReverieTrack.self,
            configurations: config
        )

        return ContentView(audioPlayer: AudioPlayer())
            .modelContainer(container)
            .frame(width: 1000, height: 700)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
            .frame(width: 1000, height: 700)
    }
}
#Preview("iPhone", traits: .portrait) {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReveriePlaylist.self, ReverieTrack.self,
            configurations: config
        )

        return ContentView(audioPlayer: AudioPlayer())
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
