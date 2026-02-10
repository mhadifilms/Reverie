//
//  DownloadManager.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData

/// Manages downloading audio files with queue management
@MainActor
@Observable
class DownloadManager {
    
    // Observable properties for UI updates
    var activeDownloads: [UUID: DownloadTask] = [:]
    var downloadQueue: [UUID] = []
    
    private let youtubeResolver = YouTubeResolver()
    private let storageManager = StorageManager()
    private let maxConcurrentDownloads = Constants.maxConcurrentDownloads
    
    struct DownloadTask {
        let trackID: UUID
        var progress: Double = 0.0
        var task: URLSessionDownloadTask?
    }
    
    enum DownloadError: LocalizedError {
        case resolutionFailed
        case downloadFailed
        case storageFailed
        case alreadyDownloading
        
        var errorDescription: String? {
            switch self {
            case .resolutionFailed:
                return "Failed to resolve audio source"
            case .downloadFailed:
                return "Download failed"
            case .storageFailed:
                return "Failed to save file"
            case .alreadyDownloading:
                return "Track is already downloading"
            }
        }
    }
    
    /// Downloads a single track with pre-resolved audio URL
    func downloadTrack(_ track: ReverieTrack, audioURL: URL, modelContext: ModelContext) async throws {
        // Check if already downloading
        guard activeDownloads[track.id] == nil else {
            throw DownloadError.alreadyDownloading
        }
        
        // Update state to downloading immediately
        track.downloadState = .downloading
        track.downloadProgress = 0.0
        activeDownloads[track.id] = DownloadTask(trackID: track.id)
        
        print("🎵 Starting download for: \(track.title)")
        print("📡 Audio URL: \(audioURL.absoluteString.prefix(100))...")
        
        // Download directly without re-resolving
        await performDirectDownload(track: track, audioURL: audioURL, modelContext: modelContext)
    }
    
    /// Downloads a single track (resolves audio URL automatically)
    func downloadTrack(_ track: ReverieTrack, modelContext: ModelContext) async throws {
        // Check if already downloading
        guard activeDownloads[track.id] == nil else {
            throw DownloadError.alreadyDownloading
        }
        
        // Update state to queued
        track.downloadState = .queued
        track.downloadProgress = 0.0
        
        // Add to queue
        downloadQueue.append(track.id)
        
        // Process queue
        await processDownloadQueue(modelContext: modelContext)
    }
    
    /// Downloads all tracks in a playlist
    func downloadPlaylist(_ playlist: ReveriePlaylist, modelContext: ModelContext) async {
        for track in playlist.tracks where track.downloadState != .downloaded {
            try? await downloadTrack(track, modelContext: modelContext)
        }
    }
    
    /// Processes the download queue respecting concurrency limits
    private func processDownloadQueue(modelContext: ModelContext) async {
        while !downloadQueue.isEmpty && activeDownloads.count < maxConcurrentDownloads {
            guard let trackID = downloadQueue.first else { break }
            downloadQueue.removeFirst()
            
            // Fetch track from database
            let descriptor = FetchDescriptor<ReverieTrack>(
                predicate: #Predicate { $0.id == trackID }
            )
            
            guard let tracks = try? modelContext.fetch(descriptor),
                  let track = tracks.first else {
                continue
            }
            
            // Start download in background
            Task {
                await performDownload(track: track, modelContext: modelContext)
            }
        }
    }
    
    /// Performs direct download with pre-resolved audio URL
    private func performDirectDownload(track: ReverieTrack, audioURL: URL, modelContext: ModelContext) async {
        do {
            print("⬇️ Downloading audio file...")
            
            // Download the audio file
            let fileData = try await downloadFile(from: audioURL, trackID: track.id) { progress in
                Task { @MainActor in
                    track.downloadProgress = progress
                    if var downloadTask = self.activeDownloads[track.id] {
                        downloadTask.progress = progress
                        self.activeDownloads[track.id] = downloadTask
                    }
                    print("📊 Download progress: \(Int(progress * 100))%")
                }
            }
            
            print("✅ Download complete! Size: \(fileData.count) bytes")
            
            // Save to storage
            let filename = "\(track.id.uuidString).m4a"
            let relativePath = try await storageManager.saveAudio(data: fileData, filename: filename)
            
            print("💾 Saved to: \(relativePath)")
            
            // Update track metadata
            await MainActor.run {
                track.localFilePath = relativePath
                track.fileSizeBytes = Int64(fileData.count)
                track.downloadDate = Date()
                track.downloadState = .downloaded
                track.downloadProgress = 1.0
                
                // Remove from active downloads
                activeDownloads.removeValue(forKey: track.id)
                
                // Save to database
                try? modelContext.save()
                
                print("🎉 Track saved to library!")
                
                // Trigger haptic feedback
                HapticManager.shared.downloadComplete()
            }
            
        } catch {
            print("❌ Download failed: \(error)")
            
            // Handle download failure
            await MainActor.run {
                track.downloadState = .failed
                track.downloadProgress = 0.0
                activeDownloads.removeValue(forKey: track.id)
                
                HapticManager.shared.error()
            }
        }
    }
    
    /// Performs the actual download for a track
    private func performDownload(track: ReverieTrack, modelContext: ModelContext) async {
        // Update state
        track.downloadState = .downloading
        activeDownloads[track.id] = DownloadTask(trackID: track.id)
        
        do {
            // Step 1: Resolve audio URL from YouTube
            let resolvedAudio = try await youtubeResolver.resolveAudioURL(
                title: track.title,
                artist: track.artist
            )
            
            // Store YouTube video ID
            track.youtubeVideoID = resolvedAudio.videoID
            
            // Step 2: Download the audio file
            let fileData = try await downloadFile(from: resolvedAudio.audioURL, trackID: track.id) { progress in
                Task { @MainActor in
                    track.downloadProgress = progress
                    if var downloadTask = self.activeDownloads[track.id] {
                        downloadTask.progress = progress
                        self.activeDownloads[track.id] = downloadTask
                    }
                }
            }
            
            // Step 3: Save to storage
            let filename = "\(track.id.uuidString).\(resolvedAudio.fileExtension)"
            let relativePath = try await storageManager.saveAudio(data: fileData, filename: filename)
            
            // Step 4: Update track metadata
            await MainActor.run {
                track.localFilePath = relativePath
                track.fileSizeBytes = Int64(fileData.count)
                track.downloadDate = Date()
                track.downloadState = .downloaded
                track.downloadProgress = 1.0
                
                if track.durationSeconds == 0 {
                    track.durationSeconds = resolvedAudio.durationSeconds
                }
                
                // Remove from active downloads
                activeDownloads.removeValue(forKey: track.id)
                
                // Trigger haptic feedback
                HapticManager.shared.downloadComplete()
            }
            
            // Process next item in queue
            await processDownloadQueue(modelContext: modelContext)
            
        } catch {
            // Handle download failure
            await MainActor.run {
                track.downloadState = .failed
                track.downloadProgress = 0.0
                activeDownloads.removeValue(forKey: track.id)
                
                HapticManager.shared.error()
            }
            
            // Continue with queue
            await processDownloadQueue(modelContext: modelContext)
        }
    }
    
    /// Downloads a file from a URL with progress reporting
    private func downloadFile(from url: URL, trackID: UUID, progressHandler: @escaping (Double) -> Void) async throws -> Data {
        let session = URLSession.shared
        
        // Create a download task
        var observation: NSKeyValueObservation?
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { localURL, response, error in
                observation?.invalidate()
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localURL = localURL else {
                    continuation.resume(throwing: DownloadError.downloadFailed)
                    return
                }
                
                do {
                    let data = try Data(contentsOf: localURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            if var downloadTask = self.activeDownloads[trackID] {
                downloadTask.task = task
                self.activeDownloads[trackID] = downloadTask
            }
            
            // Observe progress
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress.fractionCompleted)
            }
            
            task.resume()
        }
    }
    
    /// Cancels a download
    func cancelDownload(trackID: UUID, modelContext: ModelContext) async {
        // Cancel the active download task
        if let downloadTask = activeDownloads[trackID] {
            downloadTask.task?.cancel()
            activeDownloads.removeValue(forKey: trackID)
        }
        
        // Remove from queue
        downloadQueue.removeAll { $0 == trackID }
        
        // Update track state
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { $0.id == trackID }
        )
        
        if let tracks = try? modelContext.fetch(descriptor),
           let track = tracks.first {
            track.downloadState = .notDownloaded
            track.downloadProgress = 0.0
            try? modelContext.save()
        }
    }
    
    /// Deletes a downloaded track
    func deleteTrack(_ track: ReverieTrack) async throws {
        guard let relativePath = track.localFilePath else {
            return
        }
        
        // Delete file from storage
        try await storageManager.deleteAudio(relativePath: relativePath)
        
        // Update track state
        await MainActor.run {
            track.downloadState = .notDownloaded
            track.localFilePath = nil
            track.fileSizeBytes = nil
            track.downloadDate = nil
            track.downloadProgress = 0.0
        }
    }
}
