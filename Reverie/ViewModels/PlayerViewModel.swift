//
//  PlayerViewModel.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData

@MainActor
@Observable
class PlayerViewModel {

    let audioPlayer = AudioPlayer()
    let downloadManager = DownloadManager()

    var showNowPlaying: Bool = false

    private let youtubeResolver = YouTubeResolver()
    private let network = NetworkMonitor.shared

    /// Plays a track: stream-first if not downloaded, local if downloaded.
    /// Network-aware: Wi-Fi streams + downloads, Cellular streams only (unless opted in),
    /// Offline plays downloaded tracks only.
    func playTrack(_ track: ReverieTrack, modelContext: ModelContext) async {
        // If track is already downloaded, play from local file (works offline)
        if track.downloadState == .downloaded {
            try? await audioPlayer.loadTrack(track)
            audioPlayer.play()
            showNowPlaying = true

            track.playCount += 1
            track.lastPlayedDate = Date()
            try? modelContext.save()
            return
        }

        // Not downloaded -- need network to stream
        guard network.canStream else {
            // Offline or cellular with streaming disabled
            let error = ReverieError.playback(.trackNotDownloaded(trackTitle: track.title))
            ErrorBannerState.shared.post(error)
            return
        }

        // Stream-first: resolve URL, start streaming immediately, download in background
        guard let videoID = track.youtubeVideoID else {
            // No video ID -- fall back to download-then-play
            try? await downloadManager.downloadTrack(track, modelContext: modelContext)
            while track.downloadState == .downloading || track.downloadState == .queued {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            if track.downloadState == .downloaded {
                try? await audioPlayer.loadTrack(track)
                audioPlayer.play()
                showNowPlaying = true
                track.playCount += 1
                track.lastPlayedDate = Date()
                try? modelContext.save()
            }
            return
        }

        do {
            // Resolve stream URL
            let resolved = try await youtubeResolver.resolveAudioURL(videoID: videoID)

            // Start streaming immediately via AVPlayer
            audioPlayer.loadStream(url: resolved.audioURL, track: track)
            audioPlayer.play()
            showNowPlaying = true

            track.playCount += 1
            track.lastPlayedDate = Date()
            try? modelContext.save()

            // Background download: only on Wi-Fi, or on cellular if user opted in
            if network.canDownload {
                Task {
                    try? await downloadManager.downloadTrack(
                        track, audioURL: resolved.audioURL, videoID: videoID, modelContext: modelContext
                    )

                    if track.downloadState == .downloaded {
                        await audioPlayer.transitionToLocalPlayback(track: track)
                    }
                }
            }

        } catch {
            // Stream resolution failed; fall back to download-then-play
            try? await downloadManager.downloadTrack(track, modelContext: modelContext)
            while track.downloadState == .downloading || track.downloadState == .queued {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            if track.downloadState == .downloaded {
                try? await audioPlayer.loadTrack(track)
                audioPlayer.play()
                showNowPlaying = true
                track.playCount += 1
                track.lastPlayedDate = Date()
                try? modelContext.save()
            }
        }
    }

    /// Plays a playlist starting from a specific track
    func playPlaylist(_ playlist: ReveriePlaylist, startingAt track: ReverieTrack, modelContext: ModelContext) async {
        let allTracks = playlist.tracks
        guard let startIndex = allTracks.firstIndex(where: { $0.id == track.id }) else {
            await playTrack(track, modelContext: modelContext)
            return
        }

        // If starting track is downloaded, set queue and play normally
        if track.downloadState == .downloaded {
            let downloadedTracks = allTracks.filter { $0.downloadState == .downloaded }
            if let dlIndex = downloadedTracks.firstIndex(where: { $0.id == track.id }) {
                audioPlayer.setQueue(downloadedTracks, startingAt: dlIndex)
                audioPlayer.play()
                showNowPlaying = true
                return
            }
        }

        // Starting track not downloaded -- stream it
        await playTrack(track, modelContext: modelContext)
    }

    /// Downloads a single track
    func downloadTrack(_ track: ReverieTrack, modelContext: ModelContext) async {
        try? await downloadManager.downloadTrack(track, modelContext: modelContext)
    }

    /// Downloads all tracks in a playlist
    func downloadPlaylist(_ playlist: ReveriePlaylist, modelContext: ModelContext) async {
        await downloadManager.downloadPlaylist(playlist, modelContext: modelContext)
    }

    /// Deletes a downloaded track
    func deleteTrack(_ track: ReverieTrack, modelContext: ModelContext) async {
        try? await downloadManager.deleteTrack(track, modelContext: modelContext)
    }
}
