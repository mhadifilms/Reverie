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
    @State private var playerViewModel = PlayerViewModel()
    @State private var showImportSheet = false
    @State private var showCreatePlaylistSheet = false
    
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
            }
        }
    }
    
    private var downloadedTracks: [ReverieTrack] {
        allTracks.filter { $0.downloadState == .downloaded }
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
            HStack {
                Text("Playlists")
                    #if os(iOS)
                    .font(.title2.bold())
                    #else
                    .font(.title.bold())
                    #endif
                Spacer()
                Text("\(playlists.count) playlist\(playlists.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
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
        ForEach(playlists) { playlist in
            NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
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
    }
    
    private var recentDownloadsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Downloads")
                    #if os(iOS)
                    .font(.title2.bold())
                    #else
                    .font(.title.bold())
                    #endif
                Spacer()
                Text("\(downloadedTracks.count) song\(downloadedTracks.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            #if os(iOS)
            VStack(spacing: 4) {
                recentTracksContent
            }
            #else
            VStack(spacing: 8) {
                recentTracksContent
            }
            #endif
        }
    }
    
    @ViewBuilder
    private var recentTracksContent: some View {
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
    }
    
    // MARK: - Actions
    
    private func deletePlaylist(_ playlist: ReveriePlaylist) {
        Task {
            await libraryViewModel.deletePlaylist(playlist, modelContext: modelContext)
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: ReveriePlaylist
    @State private var isHovered = false
    
    var body: some View {
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
                .shadow(color: .black.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
                .scaleEffect(isHovered ? 1.02 : 1.0)
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
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

