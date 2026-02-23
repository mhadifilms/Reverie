//
//  LibraryViewModel.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
class LibraryViewModel {
    
    var isImporting: Bool = false
    var importError: String?
    var showImportSheet: Bool = false
    var parsedPlaylistData: SpotifyParser.PlaylistData?
    var showReviewSheet: Bool = false
    var importURL: String = ""
    
    private let spotifyParser = SpotifyParser()
    
    /// Imports a Spotify playlist or album from a URL
    /// Step 1: Parse and show review screen
    func importPlaylist(url: String, modelContext: ModelContext) async {
        isImporting = true
        importError = nil
        importURL = url
        
        do {
            print("🎵 Starting import from: \(url)")
            
            // Parse the Spotify playlist or album
            let playlistData = try await spotifyParser.parsePlaylist(from: url)
            
            print("✅ Parsed successfully: \(playlistData.name)")
            print("📊 Found \(playlistData.tracks.count) tracks")
            
            // Download cover art
            let coverArtData = await downloadImage(from: playlistData.coverArtURL)
            
            // Create playlist model
            let playlist = ReveriePlaylist(
                name: playlistData.name,
                spotifyURL: url,
                coverArtURL: playlistData.coverArtURL,
                coverArtData: coverArtData
            )
            
            // Save playlist first
            modelContext.insert(playlist)
            
            // Initialize services
            let ytSearch = YouTubeMusicSearch()
            let downloadManager = DownloadManager()
            
            // Create track models and start downloading them
            for (index, trackData) in playlistData.tracks.enumerated() {
                print("📥 [\(index + 1)/\(playlistData.tracks.count)] Processing: \(trackData.title) - \(trackData.artist)")
                
                let albumArtData = await downloadImage(from: trackData.albumArtURL)
                
                let track = ReverieTrack(
                    title: trackData.title,
                    artist: trackData.artist,
                    album: trackData.album,
                    durationSeconds: trackData.durationMs / 1000,
                    albumArtURL: trackData.albumArtURL,
                    albumArtData: albumArtData,
                    spotifyID: trackData.spotifyID
                )
                
                track.playlists.append(playlist)
                playlist.tracks.append(track)
                modelContext.insert(track)
                
                // Search YouTube Music for this track
                let searchQuery = "\(trackData.title) \(trackData.artist)"
                do {
                    let searchResults = try await ytSearch.search(query: searchQuery)
                    
                    if let firstResult = searchResults.first {
                        print("✅ Found on YouTube: \(firstResult.title)")
                        track.youtubeVideoID = firstResult.videoID
                        
                        // Start download in background
                        Task {
                            do {
                                try await downloadManager.downloadTrack(track, modelContext: modelContext)
                                print("✅ Downloaded: \(track.title)")
                            } catch {
                                print("❌ Download failed for \(track.title): \(error)")
                            }
                        }
                    } else {
                        print("⚠️ No YouTube results for: \(searchQuery)")
                    }
                } catch {
                    print("❌ YouTube search failed for \(track.title): \(error)")
                }
            }
            
            try modelContext.save()
            
            print("💾 Saved \(playlistData.name) to database with \(playlist.tracks.count) tracks")
            print("⏬ Downloads started in background")
            
            isImporting = false
            showImportSheet = false
            
        } catch {
            importError = error.localizedDescription
            isImporting = false
        }
    }
    
    /// Imports a playlist using Spotify API (fallback)
    func importPlaylistViaAPI(
        url: String,
        clientID: String,
        clientSecret: String,
        modelContext: ModelContext
    ) async {
        isImporting = true
        importError = nil
        
        do {
            // Extract playlist ID
            guard let playlistID = extractPlaylistID(from: url) else {
                throw NSError(domain: "LibraryViewModel", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid Spotify URL"
                ])
            }
            
            // Parse via API
            let playlistData = try await spotifyParser.parsePlaylistViaAPI(
                playlistID: playlistID,
                clientID: clientID,
                clientSecret: clientSecret
            )
            
            // Download cover art
            let coverArtData = await downloadImage(from: playlistData.coverArtURL)
            
            // Create playlist model
            let playlist = ReveriePlaylist(
                name: playlistData.name,
                spotifyURL: url,
                coverArtURL: playlistData.coverArtURL,
                coverArtData: coverArtData
            )
            
            // Create track models
            for trackData in playlistData.tracks {
                let albumArtData = await downloadImage(from: trackData.albumArtURL)
                
                let track = ReverieTrack(
                    title: trackData.title,
                    artist: trackData.artist,
                    album: trackData.album,
                    durationSeconds: trackData.durationMs / 1000,
                    albumArtURL: trackData.albumArtURL,
                    albumArtData: albumArtData,
                    spotifyID: trackData.spotifyID
                )
                
                track.playlists.append(playlist)
                playlist.tracks.append(track)
            }
            
            // Save to database
            modelContext.insert(playlist)
            try modelContext.save()
            
            isImporting = false
            showImportSheet = false
            
        } catch {
            importError = error.localizedDescription
            isImporting = false
        }
    }
    
    /// Downloads an image from a URL
    private func downloadImage(from urlString: String?) async -> Data? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
    
    /// Extracts playlist ID from Spotify URL
    private func extractPlaylistID(from urlString: String) -> String? {
        if urlString.contains("spotify.com/playlist/") {
            let components = urlString.components(separatedBy: "playlist/")
            guard components.count >= 2 else { return nil }
            let idPart = components[1].components(separatedBy: "?")[0]
            return idPart
        } else if urlString.hasPrefix("spotify:playlist:") {
            return urlString.replacingOccurrences(of: "spotify:playlist:", with: "")
        }
        return nil
    }
    
    /// Deletes a playlist and cleans up tracks that aren't in other playlists
    func deletePlaylist(_ playlist: ReveriePlaylist, modelContext: ModelContext) async {
        let downloadManager = DownloadManager()
        let tracksToProcess = playlist.tracks
        
        // Remove playlist from each track's relationship
        for track in tracksToProcess {
            // Remove this playlist from the track's playlists array
            if let index = track.playlists.firstIndex(where: { $0.id == playlist.id }) {
                track.playlists.remove(at: index)
            }
            
            // Check refcount: if track is in no other playlists, delete it and its file
            if track.playlists.isEmpty {
                // Delete the audio file only if track is not shared
                if track.downloadState == .downloaded {
                    do {
                        try await downloadManager.deleteTrack(track, modelContext: modelContext)
                    } catch {
                        // Log error but continue
                        let reverieError = error as? ReverieError ?? ReverieError.storage(.fileDeleteFailed(error))
                        reverieError.log()
                    }
                }
                
                // Delete the track record itself
                modelContext.delete(track)
            }
        }
        
        // Delete the playlist
        modelContext.delete(playlist)
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            let reverieError = ReverieError.storage(.fileSaveFailed(error))
            ErrorBannerState.shared.post(reverieError)
        }
    }
    
    /// Parse Spotify URL and prepare for review
    func parsePlaylistForReview(url: String) async {
        isImporting = true
        importError = nil
        importURL = url
        
        do {
            let playlistData = try await spotifyParser.parsePlaylist(from: url)
            parsedPlaylistData = playlistData
            showReviewSheet = true
            isImporting = false
        } catch {
            importError = error.localizedDescription
            isImporting = false
        }
    }
    
    /// Import confirmed tracks after review
    func importConfirmedTracks(
        playlistData: SpotifyParser.PlaylistData,
        matches: [SpotifyImportReviewView.TrackMatch],
        spotifyURL: String,
        modelContext: ModelContext
    ) async {
        print("🎬 importConfirmedTracks CALLED")
        print("📀 Playlist: \(playlistData.name)")
        print("🔢 Matches count: \(matches.count)")
        print("✅ Matches with YouTube: \(matches.filter({ $0.youtubeMatch != nil }).count)")

        let coverArtData = await downloadImage(from: playlistData.coverArtURL)
        
        let playlist = ReveriePlaylist(
            name: playlistData.name,
            spotifyURL: spotifyURL,
            coverArtURL: playlistData.coverArtURL,
            coverArtData: coverArtData
        )
        
        modelContext.insert(playlist)
        
        let downloadManager = DownloadManager()
        
        for match in matches where match.youtubeMatch != nil {
            let trackData = match.spotifyTrack
            let youtubeMatch = match.youtubeMatch!
            
            let albumArtData = await downloadImage(from: trackData.albumArtURL)
            
            let track = ReverieTrack(
                title: trackData.title,
                artist: trackData.artist,
                album: trackData.album,
                durationSeconds: trackData.durationMs / 1000,
                albumArtURL: trackData.albumArtURL,
                albumArtData: albumArtData,
                spotifyID: trackData.spotifyID,
                youtubeVideoID: youtubeMatch.videoID
            )
            
            track.playlists.append(playlist)
            playlist.tracks.append(track)
            modelContext.insert(track)
            
            print("📥 Queueing download for: \(track.title)")
            Task {
                do {
                    print("🚀 Starting download for: \(track.title)")
                    try await downloadManager.downloadTrack(track, modelContext: modelContext)
                    print("✅ Download completed for: \(track.title)")
                } catch {
                    print("❌ Download failed for \(track.title): \(error.localizedDescription)")
                }
            }
        }
        
        try? modelContext.save()
    }
}
