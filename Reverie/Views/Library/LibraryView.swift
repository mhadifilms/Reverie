//
//  LibraryView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReveriePlaylist.dateImported, order: .reverse) private var playlists: [ReveriePlaylist]
    @Query(sort: \ReverieTrack.downloadDate, order: .reverse) private var allTracks: [ReverieTrack]
    
    let audioPlayer: AudioPlayer
    
    @State private var libraryViewModel = LibraryViewModel()
    @State private var downloadManager = DownloadManager()
    @State private var showImportSheet = false
    @State private var showCreatePlaylistSheet = false
    @State private var songSortOption: SongSortOption = .recent
    
    var body: some View {
        NavigationStack {
            libraryContent
        }
    }
    
    private var libraryContent: some View {
        ScrollView {
            #if os(iOS)
            VStack(spacing: 24) {
                contentBody
            }
            .padding(16)
            #else
            VStack(spacing: 32) {
                contentBody
            }
            .padding(32)
            #endif
        }
        .navigationTitle("Library")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreatePlaylistSheet = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                    
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import from Spotify", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    #if os(macOS)
                    Label("Add", systemImage: "plus.circle.fill")
                    #else
                    Label("Add", systemImage: "plus")
                    #endif
                }
                #if os(macOS)
                .buttonStyle(.borderedProminent)
                #endif
            }
        }
        .focusedValue(\.newPlaylistAction) {
            showCreatePlaylistSheet = true
        }
        .focusedValue(\.importPlaylistAction) {
            showImportSheet = true
        }
        .sheet(isPresented: $showImportSheet) {
            ImportPlaylistSheet(
                viewModel: libraryViewModel,
                modelContext: modelContext
            )
            #if os(macOS)
            .frame(width: 500, height: 400)
            #endif
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            CreatePlaylistSheet(modelContext: modelContext)
            #if os(macOS)
            .frame(width: 500, height: 400)
            #endif
        }
        .sheet(isPresented: $libraryViewModel.showReviewSheet) {
            if let playlistData = libraryViewModel.parsedPlaylistData {
                SpotifyImportReviewView(
                    playlistData: playlistData,
                    spotifyURL: libraryViewModel.importURL
                )
                #if os(macOS)
                .frame(width: 900, height: 700)
                #endif
            }
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if playlists.isEmpty && downloadedTracks.isEmpty {
            emptyStateView
        } else {
            if !playlists.isEmpty {
                playlistsSection
            }
            
            if !downloadedTracks.isEmpty {
                recentDownloadsSection
                allSongsSection
            }
        }
    }
    
    private var downloadedTracks: [ReverieTrack] {
        allTracks.filter { $0.downloadState == .downloaded }
    }
    
    private var allDownloadedTracksSorted: [ReverieTrack] {
        switch songSortOption {
        case .title:
            return downloadedTracks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .artist:
            return downloadedTracks.sorted {
                let artistCompare = $0.artist.localizedCaseInsensitiveCompare($1.artist)
                if artistCompare == .orderedSame {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return artistCompare == .orderedAscending
            }
        case .recent:
            return downloadedTracks.sorted {
                ($0.downloadDate ?? .distantPast) > ($1.downloadDate ?? .distantPast)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Your Library is Empty")
                .font(.title2.bold())
            
            Text("Import a Spotify playlist or search for songs to get started")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Playlists",
                subtitle: "\(playlists.count) playlist\(playlists.count == 1 ? "" : "s")",
                systemImage: "music.note.list"
            )
            
            #if os(iOS)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16)], spacing: 16) {
                playlistGridContent
            }
            #else
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)], spacing: 20) {
                playlistGridContent
            }
            #endif
        }
    }
    
    @ViewBuilder
    private var playlistGridContent: some View {
        #if os(iOS)
        ForEach(Array(playlists.enumerated()), id: \.element.id) { index, playlist in
            NavigationLink(destination: PlaylistDetailView(playlist: playlist, audioPlayer: audioPlayer)) {
                PlaylistCardView(playlist: playlist)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    deletePlaylist(playlist)
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(
                .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.03),
                value: playlists.count
            )
        }
        #else
        ForEach(playlists) { playlist in
            NavigationLink(destination: PlaylistDetailView(playlist: playlist, audioPlayer: audioPlayer)) {
                PlaylistCardView(playlist: playlist)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    deletePlaylist(playlist)
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
            }
        }
        #endif
    }
    
    private var recentDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "Recent Downloads",
                subtitle: "\(downloadedTracks.count) song\(downloadedTracks.count == 1 ? "" : "s")",
                systemImage: "arrow.down.circle"
            )
            
            #if os(iOS)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(downloadedTracks.prefix(12)) { track in
                        RecentTrackCard(track: track)
                            .onTapGesture {
                                Task {
                                    do {
                                        try await audioPlayer.loadTrack(track)
                                        audioPlayer.play()
                                    } catch {
                                        print("Failed to play track: \(error)")
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, 2)
            }
            #else
            VStack(spacing: 8) {
                recentTracksContent
            }
            #endif
        }
    }
    
    private var allSongsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(
                title: "All Songs",
                subtitle: "\(allDownloadedTracksSorted.count) song\(allDownloadedTracksSorted.count == 1 ? "" : "s")",
                systemImage: "music.note"
            )
            
            HStack {
                Text("Sort")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Sort", selection: $songSortOption) {
                    ForEach(SongSortOption.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                #if os(iOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                #endif
                
                Spacer()
            }
            
            LazyVStack(spacing: 6) {
                ForEach(allDownloadedTracksSorted) { track in
                    TrackRowView(track: track)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Task {
                                do {
                                    try await audioPlayer.loadTrack(track)
                                    audioPlayer.play()
                                } catch {
                                    print("Failed to play track: \(error)")
                                }
                            }
                        }
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    try? await downloadManager.deleteTrack(track)
                                }
                            } label: {
                                Label("Delete Download", systemImage: "trash")
                            }
                        }
                        #endif
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentTracksContent: some View {
        #if os(iOS)
        EmptyView()
        #else
        ForEach(downloadedTracks.prefix(10)) { track in
            TrackRowView(track: track)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        do {
                            try await audioPlayer.loadTrack(track)
                            audioPlayer.play()
                        } catch {
                            print("Failed to play track: \(error)")
                        }
                    }
                }
        }
        #endif
    }
    
    // MARK: - Actions
    
    private func deletePlaylist(_ playlist: ReveriePlaylist) {
        Task {
            await libraryViewModel.deletePlaylist(playlist, modelContext: modelContext)
        }
    }
}

enum SongSortOption: String, CaseIterable {
    case recent
    case title
    case artist
    
    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .title:
            return "Title"
        case .artist:
            return "Artist"
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: ReveriePlaylist
    @State private var isHovered = false
    
    var body: some View {
        #if os(iOS)
        GlassCard(cornerRadius: 16, padding: 12) {
            cardContent
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        #else
        cardContent
        #endif
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Album art with hover effect
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let coverData = playlist.coverArtData {
                        #if canImport(UIKit)
                        if let uiImage = UIImage(data: coverData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        #elseif canImport(AppKit)
                        if let nsImage = NSImage(data: coverData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        #endif
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(isHovered ? 0.25 : 0.12), radius: isHovered ? 10 : 6, y: isHovered ? 6 : 3)
                .scaleEffect(isHovered ? 1.015 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("\(playlist.trackCount) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if playlist.downloadedTrackCount > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(playlist.downloadedTrackCount) downloaded")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: ReverieTrack
    @State private var isHovered = false
    @State private var showAddToPlaylist = false
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 16) {
            // Album art thumbnail
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay {
                    if let artData = track.albumArtData {
                        #if canImport(UIKit)
                        if let uiImage = UIImage(data: artData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        #elseif canImport(AppKit)
                        if let nsImage = NSImage(data: artData) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        #endif
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration and download status
            HStack(spacing: 12) {
                if track.downloadState == .downloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
                
                if track.durationSeconds > 0 {
                    Text(track.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        #if os(macOS)
        .listRowBackground(Color.clear)
        #else
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            HapticManager.shared.longPress()
        }
        #endif
        .contextMenu {
            Button {
                showAddToPlaylist = true
            } label: {
                Label("Add to Playlist", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(track: track, modelContext: modelContext)
        }
    }
    
    @ViewBuilder
    private var rowBackground: some View {
        #if os(iOS)
        RoundedRectangle(cornerRadius: 10)
            .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        #else
        Color.clear
        #endif
    }
}

// MARK: - Recent Track Card (iOS)
struct RecentTrackCard: View {
    let track: ReverieTrack
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AlbumArtView(
                imageData: track.albumArtData,
                size: 92,
                cornerRadius: 12
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 110)
    }
}

#Preview("macOS") {
    LibraryView(audioPlayer: AudioPlayer())
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
        .frame(width: 800, height: 600)
}
#Preview("iPhone", traits: .portrait) {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ReveriePlaylist.self, ReverieTrack.self,
            configurations: config
        )
        
        return NavigationStack {
            LibraryView(audioPlayer: AudioPlayer())
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
