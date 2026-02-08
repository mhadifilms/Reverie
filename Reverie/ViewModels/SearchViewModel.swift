//
//  SearchViewModel.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import Foundation
import SwiftData

@Observable
class SearchViewModel {
    var searchResults: [SearchResultItem] = []
    var isSearching = false
    var errorMessage: String?
    
    // Track which videoIDs map to which track UUIDs for download progress
    var videoIDToTrackID: [String: UUID] = [:]
    
    private let youtubeMusicSearch = YouTubeMusicSearch()
    private let youtubeResolver = YouTubeResolver()
    private var downloadManager: DownloadManager?
    
    struct SearchResultItem: Identifiable {
        let id: String
        let videoID: String
        let title: String
        let artist: String
        let album: String?
        let thumbnailURL: URL?
        let durationSeconds: Int
        var isDownloading = false
        var isDownloaded = false
        var downloadProgress: Double = 0.0
        var trackID: UUID?  // The actual track UUID in SwiftData
        
        var formattedDuration: String {
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func setDownloadManager(_ manager: DownloadManager) {
        self.downloadManager = manager
    }
    
    /// Gets the download progress for a given videoID
    func getDownloadProgress(for videoID: String) -> Double {
        guard let trackID = videoIDToTrackID[videoID],
              let downloadTask = downloadManager?.activeDownloads[trackID] else {
            return 0.0
        }
        return downloadTask.progress
    }
    
    /// Checks if a track has been downloaded by checking SwiftData
    func checkIfDownloaded(videoID: String, modelContext: ModelContext) -> Bool {
        // Check if we have a trackID for this videoID
        guard let trackID = videoIDToTrackID[videoID] else {
            // Search database for track with this YouTube video ID
            let descriptor = FetchDescriptor<ReverieTrack>(
                predicate: #Predicate { $0.youtubeVideoID == videoID }
            )
            if let tracks = try? modelContext.fetch(descriptor),
               let track = tracks.first {
                // Cache the mapping
                videoIDToTrackID[videoID] = track.id
                return track.downloadState == .downloaded
            }
            return false
        }
        
        // Fetch the track to check its state
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { $0.id == trackID }
        )
        if let tracks = try? modelContext.fetch(descriptor),
           let track = tracks.first {
            return track.downloadState == .downloaded
        }
        return false
    }
    
    /// Searches YouTube Music for a query and returns results
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let results = try await youtubeMusicSearch.search(query: query, limit: 20)
            searchResults = results.map { result in
                SearchResultItem(
                    id: result.id,
                    videoID: result.videoID,
                    title: result.title,
                    artist: result.artist,
                    album: result.album,
                    thumbnailURL: result.thumbnailURL,
                    durationSeconds: result.durationSeconds
                )
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
    }
    
    /// Downloads a track from search results and adds it to the library
    func downloadTrack(videoID: String, modelContext: ModelContext) async {
        guard let manager = downloadManager else {
            errorMessage = "Download manager not initialized"
            return
        }
        
        // Find the search result
        guard let index = searchResults.firstIndex(where: { $0.videoID == videoID }) else {
            return
        }
        
        searchResults[index].isDownloading = true
        
        do {
            print("🎬 Starting download process for videoID: \(videoID)")
            
            // Resolve audio URL
            let resolvedAudio = try await youtubeResolver.resolveAudioURL(videoID: videoID)
            print("✅ Resolved audio URL")
            
            // Get the search result for metadata
            guard let searchResult = searchResults.first(where: { $0.videoID == videoID }) else {
                print("❌ Search result not found")
                return
            }
            
            // Download thumbnail if available
            var thumbnailData: Data?
            if let thumbnailURL = searchResult.thumbnailURL {
                thumbnailData = try? await URLSession.shared.data(from: thumbnailURL).0
                print("✅ Downloaded thumbnail")
            }
            
            // Create a new track with full metadata
            let track = ReverieTrack(
                title: searchResult.title,
                artist: searchResult.artist,
                album: searchResult.album ?? "",
                durationSeconds: searchResult.durationSeconds,
                albumArtData: thumbnailData,
                youtubeVideoID: resolvedAudio.videoID,
                downloadState: .queued
            )
            
            print("📝 Created track: \(track.title)")
            
            // Insert into SwiftData
            modelContext.insert(track)
            try modelContext.save()
            print("💾 Saved track to database")
            
            // Store mapping from videoID to track UUID
            videoIDToTrackID[videoID] = track.id
            searchResults[index].trackID = track.id
            
            // Start download with pre-resolved audio URL
            try await manager.downloadTrack(track, audioURL: resolvedAudio.audioURL, modelContext: modelContext)
            
            // Update UI to show download complete
            searchResults[index].isDownloading = false
            searchResults[index].isDownloaded = true
            print("🎉 Download complete!")
            
        } catch {
            print("❌ Download failed: \(error)")
            errorMessage = "Download failed: \(error.localizedDescription)"
            searchResults[index].isDownloading = false
        }
    }
}
