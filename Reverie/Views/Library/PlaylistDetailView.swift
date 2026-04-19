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
    let audioPlayer: AudioPlayer
    
    @State private var downloadManager = DownloadManager()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        #if os(iOS)
        iOSAlbumLayout
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .ignoresSafeArea(edges: .top)
            .alert("Delete Playlist", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deletePlaylist() }
            } message: {
                Text("Are you sure you want to delete \"\(playlist.name)\"? This action cannot be undone.")
            }
            .sheet(isPresented: $showEditSheet) {
                EditPlaylistSheet(playlist: playlist, modelContext: modelContext)
            }
        #else
        macOSBody
        #endif
    }

    #if os(iOS)
    /// ScreenAlbum layout (Canopy.html): top 420pt gradient bleeds the cover
    /// hue, centered cover + title + action row, track list resolves on paper.
    private var iOSAlbumLayout: some View {
        let palette = AlbumPalette.derive(from: playlist.coverArtData)

        return ZStack(alignment: .top) {
            CanopyTheme.Palette.paper.ignoresSafeArea()

            LinearGradient(
                colors: [palette.top, palette.mid, CanopyTheme.Palette.paper],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 440)
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 54) // status bar
                    albumTopBar
                        .padding(.horizontal, CanopyTheme.Space.lg)
                        .padding(.top, CanopyTheme.Space.sm)

                    albumCover
                        .padding(.top, CanopyTheme.Space.lg)
                        .padding(.horizontal, CanopyTheme.Space.xxl + 4)

                    albumTitleBlock
                        .padding(.top, CanopyTheme.Space.lg)
                        .padding(.horizontal, CanopyTheme.Space.xl)

                    albumActions
                        .padding(.top, CanopyTheme.Space.lg)
                        .padding(.horizontal, CanopyTheme.Space.xl)

                    // Paper card rounds over the gradient bleed.
                    VStack(spacing: 0) {
                        ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRowWithDownload(
                                track: track,
                                playlist: playlist,
                                audioPlayer: audioPlayer,
                                downloadManager: downloadManager,
                                modelContext: modelContext
                            )
                            .padding(.horizontal, CanopyTheme.Space.md)

                            if index < playlist.tracks.count - 1 {
                                Divider()
                                    .overlay(CanopyTheme.Palette.hair)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .padding(.top, CanopyTheme.Space.sm)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                        .fill(CanopyTheme.Palette.paper)
                    )
                    .padding(.top, CanopyTheme.Space.lg)

                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private var albumTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                CanopyGlass(cornerRadius: 20, dark: true) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            if playlist.isCustom {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("Edit playlist", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete playlist", systemImage: "trash")
                    }
                } label: {
                    CanopyGlass(cornerRadius: 20, dark: true) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                }
                .accessibilityLabel("Playlist options")
            }
        }
    }

    private var albumCover: some View {
        AlbumArtView(
            imageData: playlist.coverArtData,
            size: 240,
            cornerRadius: 16
        )
        .shadow(color: Color.black.opacity(0.35), radius: 32, y: 16)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Playlist cover art")
    }

    private var albumTitleBlock: some View {
        VStack(spacing: 4) {
            Text(playlist.name)
                .font(CanopyTheme.Typography.displayTitle)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if playlist.trackCount > 0 {
                Text("Playlist · \(playlist.trackCount) songs, \(formattedDuration)")
                    .font(CanopyTheme.Typography.micro)
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var albumActions: some View {
        HStack(spacing: CanopyTheme.Space.md) {
            Button {
                playFirstTrack()
            } label: {
                HStack(spacing: CanopyTheme.Space.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Play")
                        .font(CanopyTheme.Typography.headline)
                }
                .foregroundStyle(CanopyTheme.Palette.greenInk)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play playlist")

            albumGlassButton(systemName: "shuffle") { shuffleAndPlay() }
                .accessibilityLabel("Shuffle play")

            if playlist.downloadedTrackCount < playlist.trackCount {
                albumGlassButton(systemName: "arrow.down") {
                    Task { await downloadManager.downloadPlaylist(playlist, modelContext: modelContext) }
                }
                .accessibilityLabel(downloadAllTitle)
            } else {
                albumGlassButton(systemName: "checkmark.circle.fill", tint: CanopyTheme.Palette.green) {}
                    .accessibilityLabel("All tracks downloaded")
            }
        }
    }

    private func albumGlassButton(systemName: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CanopyGlass(cornerRadius: 24, dark: true) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
            }
        }
        .buttonStyle(.plain)
    }

    private var formattedDuration: String {
        var seconds = 0
        for track in playlist.tracks { seconds += track.durationSeconds }
        let totalMinutes = seconds / 60
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        return mins == 0 ? "\(hours) hr" : "\(hours) hr \(mins) min"
    }

    private func playFirstTrack() {
        guard let track = playlist.tracks.first else { return }
        Task {
            do {
                try await audioPlayer.loadTrack(track)
                audioPlayer.play()
            } catch { print("Play failed: \(error)") }
        }
    }

    private func shuffleAndPlay() {
        guard let track = playlist.tracks.randomElement() else { return }
        Task {
            do {
                try await audioPlayer.loadTrack(track)
                audioPlayer.play()
            } catch { print("Shuffle failed: \(error)") }
        }
    }
    #endif

    #if os(macOS)
    private var macOSBody: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerView
                VStack(spacing: 4) {
                    ForEach(playlist.tracks) { track in
                        TrackRowWithDownload(
                            track: track,
                            playlist: playlist,
                            audioPlayer: audioPlayer,
                            downloadManager: downloadManager,
                            modelContext: modelContext
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(32)
        }
        .navigationTitle(playlist.name)
        .frame(minWidth: 600)
        .toolbar { macToolbar }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deletePlaylist() }
        } message: {
            Text("Are you sure you want to delete \"\(playlist.name)\"? This action cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditPlaylistSheet(playlist: playlist, modelContext: modelContext)
        }
    }

    @ToolbarContentBuilder
    private var macToolbar: some ToolbarContent {
        if playlist.downloadedTrackCount < playlist.trackCount {
            ToolbarItem(placement: .primaryAction) {
                Button(downloadAllTitle) {
                    Task {
                        await downloadManager.downloadPlaylist(playlist, modelContext: modelContext)
                    }
                }
                .help(downloadAllTitle)
            }
        }
        if playlist.isCustom {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("Edit Playlist", systemImage: "pencil")
                    }
                    .accessibilityLabel("Edit playlist")

                    Divider()

                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                    .accessibilityLabel("Delete playlist")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Playlist options")
            }
        }
    }
    #endif

    /// Simple palette derived from the cover image so the top of the album
    /// screen bleeds the cover's dominant hue, per the spec's Album mockup.
    struct AlbumPalette {
        let top: Color
        let mid: Color

        static func derive(from imageData: Data?) -> AlbumPalette {
            guard let data = imageData, let extracted = ColorExtractor.dominantColor(from: data) else {
                return AlbumPalette(
                    top: CanopyTheme.Palette.blueDeep,
                    mid: CanopyTheme.Palette.blueMid
                )
            }
            return AlbumPalette(top: extracted, mid: extracted.opacity(0.6))
        }
    }

    private var headerView: some View {
        #if os(iOS)
        VStack(alignment: .center, spacing: 20) {
            AlbumArtView(
                imageData: playlist.coverArtData,
                size: 220,
                cornerRadius: 16
            )
            .accessibilityLabel("Playlist cover art")
            .accessibilityHidden(true)
            
            VStack(alignment: .center, spacing: 12) {
                Text(playlist.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .center, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .accessibilityHidden(true)
                        Text("\(playlist.trackCount) songs")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    
                    if playlist.downloadedTrackCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text("\(playlist.downloadedTrackCount) of \(playlist.trackCount) downloaded")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                    }
                    
                    if playlist.totalSizeBytes > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive")
                                .accessibilityHidden(true)
                            Text(playlist.formattedTotalSize)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total size \(playlist.formattedTotalSize)")
                    }
                }
            }
        }
        #else
        HStack(spacing: 32) {
            // Cover art
            AlbumArtView(
                imageData: playlist.coverArtData,
                size: 220,
                cornerRadius: 16
            )
            .accessibilityLabel("Playlist cover art")
            .accessibilityHidden(true)
            
            // Stats
            VStack(alignment: .leading, spacing: 16) {
                Text(playlist.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .accessibilityHidden(true)
                        Text("\(playlist.trackCount) songs")
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    
                    if playlist.downloadedTrackCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text("\(playlist.downloadedTrackCount) of \(playlist.trackCount) downloaded")
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                    }
                    
                    if playlist.totalSizeBytes > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "internaldrive")
                                .accessibilityHidden(true)
                            Text(playlist.formattedTotalSize)
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total size \(playlist.formattedTotalSize)")
                    }
                }
            }
            
            Spacer()
        }
        #endif
    }
    
    #if os(iOS)
    private var downloadAllButton: some View {
        Button {
            Task {
                await downloadManager.downloadPlaylist(playlist, modelContext: modelContext)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .trim(from: 0, to: playlist.overallProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: playlist.overallProgress)
                    
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                
                Text(downloadAllTitle)
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
        .accessibilityLabel(downloadAllTitle)
        .accessibilityValue(isPlaylistDownloading ? "\(Int(playlist.overallProgress * 100)) percent" : "")
    }
    #endif

    private var downloadAllTitle: String {
        if isPlaylistDownloading {
            return "Downloading…"
        }
        if playlist.downloadedTrackCount > 0 {
            return "Download Remaining"
        }
        return "Download All Songs"
    }
    
    private var isPlaylistDownloading: Bool {
        playlist.tracks.contains { $0.downloadState == .downloading || $0.downloadState == .queued }
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
    let audioPlayer: AudioPlayer
    let downloadManager: DownloadManager
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
            .accessibilityHidden(true)
            
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
            
            #if os(macOS)
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
            #else
            // Status indicator (tap row to play/download)
            statusIndicator
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        .contentShape(Rectangle())
        .onTapGesture {
            handlePlay()
        }
        .accessibilityLabel("\(track.title) by \(track.artist)")
        .accessibilityHint(track.downloadState == .downloaded ? "Double tap to play" : "Double tap to download and play")
        .accessibilityValue(track.downloadState == .downloaded ? "Downloaded" : "Not downloaded")
        #endif
        .contextMenu {
            if let playlist = playlist, playlist.isCustom {
                Button(role: .destructive) {
                    removeFromPlaylist()
                } label: {
                    Label("Remove from Playlist", systemImage: "minus.circle")
                }
            }
        }
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if playlist != nil {
                Button(role: .destructive) {
                    removeFromPlaylist()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .accessibilityLabel("Remove \(track.title) from playlist")
            }
        }
        #endif
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch track.downloadState {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Downloaded")
        case .downloading, .queued:
            ProgressView(value: track.downloadProgress)
                .frame(width: 24, height: 24)
                .accessibilityLabel("Downloading")
                .accessibilityValue("\(Int(track.downloadProgress * 100)) percent")
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Download failed")
        case .notDownloaded:
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
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
            try? await downloadManager.downloadTrack(track, modelContext: modelContext)
        }
    }
    
    private func handlePlay() {
        Task {
            if track.downloadState == .downloaded {
                try? await audioPlayer.loadTrack(track)
                audioPlayer.play()
                track.playCount += 1
                track.lastPlayedDate = Date()
                try? modelContext.save()
            } else {
                try? await downloadManager.downloadTrack(track, modelContext: modelContext)
                
                while track.downloadState == .downloading || track.downloadState == .queued {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                
                if track.downloadState == .downloaded {
                    try? await audioPlayer.loadTrack(track)
                    audioPlayer.play()
                    track.playCount += 1
                    track.lastPlayedDate = Date()
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func handleCancel() {
        Task {
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
            ),
            audioPlayer: AudioPlayer()
        )
    }
    .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
