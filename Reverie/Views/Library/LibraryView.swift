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
    @State private var discoverRefreshID = UUID()

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
        .refreshable {
            discoverRefreshID = UUID()
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
                    .accessibilityLabel("Create new playlist")
                    
                    Button {
                        showImportSheet = true
                    } label: {
                        Label("Import from Spotify", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import playlist from Spotify")
                } label: {
                    #if os(macOS)
                    Label("Add", systemImage: "plus.circle.fill")
                    #else
                    Label("Add", systemImage: "plus")
                    #endif
                }
                .accessibilityLabel("Add playlist")
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
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            CreatePlaylistSheet(modelContext: modelContext)
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
        .sheet(isPresented: $libraryViewModel.showReviewSheet) {
            if let playlistData = libraryViewModel.parsedPlaylistData {
                SpotifyImportReviewView(
                    playlistData: playlistData,
                    spotifyURL: libraryViewModel.importURL,
                    libraryViewModel: libraryViewModel,
                    modelContext: modelContext
                )
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
            }
        }
    }
    
    @ViewBuilder
    private var contentBody: some View {
        DiscoverSection(audioPlayer: audioPlayer)
            .id(discoverRefreshID)

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
        case .playCount:
            return downloadedTracks.sorted { $0.playCount > $1.playCount }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.house")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.title2.bold())

                Text("Import a Spotify playlist or search for music to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 16) {
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import Playlist", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showCreatePlaylistSheet = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(minHeight: 300)
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
            .accessibilityLabel("\(playlist.name), \(playlist.trackCount) songs")
            .accessibilityHint("Double tap to open playlist")
            .contextMenu {
                Button(role: .destructive) {
                    deletePlaylist(playlist)
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
                .accessibilityLabel("Delete \(playlist.name)")
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
            .accessibilityLabel("\(playlist.name), \(playlist.trackCount) songs")
            .accessibilityHint("Double tap to open playlist")
            .contextMenu {
                Button(role: .destructive) {
                    deletePlaylist(playlist)
                } label: {
                    Label("Delete Playlist", systemImage: "trash")
                }
                .accessibilityLabel("Delete \(playlist.name)")
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
                            .accessibilityLabel("\(track.title) by \(track.artist)")
                            .accessibilityHint("Double tap to play")
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
                .accessibilityLabel("Sort songs by")
                .accessibilityValue(songSortOption.title)
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
                        .accessibilityLabel("\(track.title) by \(track.artist)")
                        .accessibilityHint("Double tap to play")
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    try? await downloadManager.deleteTrack(track, modelContext: modelContext)
                                }
                            } label: {
                                Label("Delete Download", systemImage: "trash")
                            }
                            .accessibilityLabel("Delete \(track.title)")
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
                .accessibilityLabel("\(track.title) by \(track.artist)")
                .accessibilityHint("Double tap to play")
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
    case playCount

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .title:
            return "Title"
        case .artist:
            return "Artist"
        case .playCount:
            return "Most Played"
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
    
    @ViewBuilder
    private func compositeArt(tracks: [ReverieTrack]) -> some View {
        let gridItems = [GridItem(.flexible(), spacing: 1), GridItem(.flexible(), spacing: 1)]
        LazyVGrid(columns: gridItems, spacing: 1) {
            ForEach(tracks.prefix(4), id: \.id) { track in
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
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Album art with enhanced styling
            ZStack {
                // Background gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.15),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Album art or placeholder
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
                    // Composite cover: 2x2 grid of first 4 tracks' art
                    let artTracks = playlist.tracks.prefix(4).filter { $0.albumArtData != nil }
                    if artTracks.count >= 4 {
                        compositeArt(tracks: Array(artTracks))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.6))

                            Text("\(playlist.trackCount)")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    // end composite
                }
                
                // Subtle gradient overlay
                if playlist.coverArtData != nil {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(isHovered ? 0.15 : 0.08), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(isHovered ? 0.3 : 0.15),
                radius: isHovered ? 16 : 8,
                y: isHovered ? 8 : 4
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovered)
            
            // Playlist info with better typography
            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    // Track count badge
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.caption2)
                        Text("\(playlist.trackCount)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    
                    if playlist.downloadedTrackCount > 0 {
                        Divider()
                            .frame(height: 12)
                        
                        // Downloaded badge with icon
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                            Text("\(playlist.downloadedTrackCount)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.green.gradient)
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
                            .accessibilityHidden(true)
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
            .accessibilityLabel("Add \(track.title) to playlist")
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
