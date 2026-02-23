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
    
    /// Plays a track (downloads if needed)
    func playTrack(_ track: ReverieTrack, modelContext: ModelContext) async {
        // If track is downloaded, play it immediately
        if track.downloadState == .downloaded {
            try? await audioPlayer.loadTrack(track)
            audioPlayer.play()
            showNowPlaying = true
            
            // Update play count and last played date
            track.playCount += 1
            track.lastPlayedDate = Date()
            try? modelContext.save()
            
        } else {
            // Download first, then play
            try? await downloadManager.downloadTrack(track, modelContext: modelContext)
            
            // Wait for download to complete
            while track.downloadState == .downloading || track.downloadState == .queued {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
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
        let downloadedTracks = playlist.tracks.filter { $0.downloadState == .downloaded }
        
        guard let startIndex = downloadedTracks.firstIndex(where: { $0.id == track.id }) else {
            // Track not downloaded, download and play it
            await playTrack(track, modelContext: modelContext)
            return
        }
        
        // Set up queue with all downloaded tracks
        audioPlayer.setQueue(downloadedTracks, startingAt: startIndex)
        audioPlayer.play()
        showNowPlaying = true
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
