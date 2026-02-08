//
//  PlaylistDetailView.swift
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

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let playlist: ReveriePlaylist
    
    @State private var playerViewModel = PlayerViewModel()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with cover art
                headerView
                
                // Download All button
                if playlist.downloadedTrackCount < playlist.trackCount {
                    downloadAllButton
                }
                
                // Track list
                VStack(spacing: 4) {
                    ForEach(playlist.tracks) { track in
                        TrackRowWithDownload(
                            track: track,
                            playlist: playlist,
                            playerViewModel: playerViewModel,
                            modelContext: modelContext
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(32)
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .frame(minWidth: 600)
        .toolbar {
            if playlist.isCustom {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Playlist", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Playlist", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePlaylist()
            }
        } message: {
            Text("Are you sure you want to delete \"\(playlist.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditPlaylistSheet(playlist: playlist, modelContext: modelContext)
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 32) {
            // Cover art
            AlbumArtView(
                imageData: playlist.coverArtData,
                size: 220,
                cornerRadius: 16
            )
            
            // Stats
            VStack(alignment: .leading, spacing: 16) {
                Text(playlist.name)
                    .font(.system(size: 36, weight: .bold))
                    .lineLimit(2)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                        Text("\(playlist.trackCount) songs")
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    
                    if playlist.downloadedTrackCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(playlist.downloadedTrackCount) of \(playlist.trackCount) downloaded")
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                    
                    if playlist.totalSizeBytes > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive")
                            Text(playlist.formattedTotalSize)
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private var downloadAllButton: some View {
        Button {
            Task {
                await playerViewModel.downloadPlaylist(playlist, modelContext: modelContext)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                Text("Download All Songs")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private func deletePlaylist() {
        // Remove playlist from all tracks
        for track in playlist.tracks {
            if let index = track.playlists.firstIndex(where: { $0.id == playlist.id }) {
                track.playlists.remove(at: index)
            }
        }
        
        // Delete the playlist
        modelContext.delete(playlist)
        try? modelContext.save()
        
        print("🗑️ Deleted playlist: \(playlist.name)")
        
        // Dismiss the view
        dismiss()
    }
}

// MARK: - Track Row with Download Button
struct TrackRowWithDownload: View {
    let track: ReverieTrack
    let playlist: ReveriePlaylist?
    let playerViewModel: PlayerViewModel
    let modelContext: ModelContext
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Album art thumbnail
            AlbumArtView(
                imageData: track.albumArtData,
                size: 56,
                cornerRadius: 6
            )
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(track.artist)
                    
                    if !track.album.isEmpty {
                        Text("•")
                        Text(track.album)
                    }
                    
                    if track.durationSeconds > 0 {
                        Text("•")
                        Text(track.formattedDuration)
                            .monospacedDigit()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            Spacer()
            
            // Download/Play button
            DownloadButton(
                state: buttonState,
                progress: track.downloadProgress,
                onDownload: {
                    handleDownload()
                },
                onPlay: {
                    handlePlay()
                },
                onCancel: {
                    handleCancel()
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if let playlist = playlist, playlist.isCustom {
                Button(role: .destructive) {
                    removeFromPlaylist()
                } label: {
                    Label("Remove from Playlist", systemImage: "minus.circle")
                }
            }
        }
    }
    
    private var buttonState: DownloadButton.DownloadButtonState {
        switch track.downloadState {
        case .downloaded:
            return .downloaded
        case .downloading, .queued:
            return .downloading
        case .failed:
            return .failed
        case .notDownloaded:
            return .notDownloaded
        }
    }
    
    private func handleDownload() {
        Task {
            await playerViewModel.downloadTrack(track, modelContext: modelContext)
        }
    }
    
    private func handlePlay() {
        Task {
            await playerViewModel.playTrack(track, modelContext: modelContext)
        }
    }
    
    private func handleCancel() {
        Task {
            let downloadManager = DownloadManager()
            await downloadManager.cancelDownload(trackID: track.id, modelContext: modelContext)
        }
    }
    
    private func removeFromPlaylist() {
        guard let playlist = playlist else { return }
        
        // Remove track from playlist
        if let trackIndex = playlist.tracks.firstIndex(where: { $0.id == track.id }) {
            playlist.tracks.remove(at: trackIndex)
        }
        
        // Remove playlist from track
        if let playlistIndex = track.playlists.firstIndex(where: { $0.id == playlist.id }) {
            track.playlists.remove(at: playlistIndex)
        }
        
        try? modelContext.save()
        
        print("🗑️ Removed \"\(track.title)\" from \"\(playlist.name)\"")
    }
}

#Preview {
    NavigationStack {
        PlaylistDetailView(
            playlist: ReveriePlaylist(
                name: "My Playlist",
                tracks: [
                    ReverieTrack(
                        title: "Test Song",
                        artist: "Test Artist",
                        durationSeconds: 180
                    )
                ]
            )
        )
    }
    .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
