//
//  ContentView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedView: SidebarItem = .library
    @State private var audioPlayer = AudioPlayer()
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @State private var accentColor: Color = .accentColor
    
    enum SidebarItem: Hashable {
        case library
        case search
        case settings
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                List(selection: selectedSidebarBinding) {
                    Section("Library") {
                        Label("Playlists", systemImage: "music.note.list")
                            .tag(SidebarItem.library)
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
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
            } detail: {
                // Detail view based on selection
                Group {
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
                .frame(minWidth: 600, minHeight: 400)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
            .safeAreaInset(edge: .bottom) {
                NowPlayingBar(player: audioPlayer, accentColor: accentColor)
            }
            #else
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
                NowPlayingBar(player: audioPlayer, accentColor: accentColor)
            }
            #endif
        }
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
        }
        .onChange(of: audioPlayer.currentTrack?.albumArtData) { _, _ in
            updateAccentColor()
        }
    }
    
    #if os(macOS)
    private var selectedSidebarBinding: Binding<SidebarItem?> {
        Binding(
            get: { selectedView },
            set: { selectedView = $0 ?? .library }
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

#Preview("macOS") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReveriePlaylist.self, ReverieTrack.self,
            configurations: config
        )
        
        return ContentView()
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
        
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
