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
    
    enum SidebarItem: Hashable {
        case library
        case search
        case settings
    }
    
    var body: some View {
        #if os(macOS)
        ZStack(alignment: .bottom) {
            NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Library Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                    
                    Button {
                        selectedView = .library
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 16))
                                .foregroundStyle(selectedView == .library ? .white : .primary)
                            Text("Playlists")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedView == .library ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedView == .library ? Color.accentColor : Color.clear)
                        )
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Discover Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 6)
                    
                    Button {
                        selectedView = .search
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundStyle(selectedView == .search ? .white : .primary)
                            Text("Search")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedView == .search ? .white : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedView == .search ? Color.accentColor : Color.clear)
                        )
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Settings at bottom
                Button {
                    selectedView = .settings
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .foregroundStyle(selectedView == .settings ? .white : .secondary)
                        Text("Settings")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selectedView == .settings ? .white : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedView == .settings ? Color.accentColor : Color.clear)
                    )
                    .padding(.horizontal, 8)
                    .padding(.bottom, 16)
                }
                .buttonStyle(.plain)
            }
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
            
            NowPlayingBar(player: audioPlayer)
        }
        #else
        ZStack(alignment: .bottom) {
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
            
            NowPlayingBar(player: audioPlayer)
        }
        #endif
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

