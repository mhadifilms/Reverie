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
            .tint(accentColor)
            .preferredColorScheme(preferredColorScheme)
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
        TabView(selection: $selectedView) {
            LibraryView(audioPlayer: audioPlayer)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(SidebarItem.library)

            SearchView(audioPlayer: audioPlayer) {
                selectedView = .library
            }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(SidebarItem.search)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(SidebarItem.settings)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if !networkMonitor.isConnected {
                    OfflineBanner()
                }
                NowPlayingBar(player: audioPlayer, accentColor: accentColor)
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
}

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
