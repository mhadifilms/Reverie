//
//  DownloadManager.swift
//  Reverie
//
//  Rewritten for Phase 0: Proper concurrent downloads with TaskGroup,
//  deduplication, exponential backoff retry, and granular error handling.
//

import Foundation
import SwiftData
import OSLog

/// Manages downloading audio files with proper concurrency and error handling
@MainActor
@Observable
class DownloadManager {
    
    // MARK: - State
    
    /// Currently active downloads (videoID -> progress)
    var activeDownloads: [String: DownloadProgress] = [:]
    
    /// Queue of pending downloads (videoID)
    private var pendingQueue: Set<String> = []
    
    /// Background task group for concurrent downloads
    private var downloadTask: Task<Void, Never>?
    
    private let youtubeResolver = YouTubeResolver()
    private let storageManager = StorageManager()
    private let maxConcurrentDownloads = Constants.maxConcurrentDownloads
    private let maxRetries = 3
    private let logger = Logger(subsystem: "com.reverie", category: "download")
    
    struct DownloadProgress {
        let trackID: UUID
        let videoID: String
        var progress: Double = 0.0
        var attempt: Int = 1
    }
    
    // MARK: - Public API
    
    /// Downloads a single track (will resolve YouTube URL if needed)
    func downloadTrack(_ track: ReverieTrack, modelContext: ModelContext) async throws {
        // Check if already downloaded
        guard track.downloadState != .downloaded else {
            logger.info("Track already downloaded: \(track.title, privacy: .public)")
            return
        }
        
        // Check if we have a videoID (from search or previous resolution)
        guard let videoID = track.youtubeVideoID else {
            let error = ReverieError.download(.resolutionFailed(
                videoID: "unknown",
                underlyingError: nil
            ))
            ErrorBannerState.shared.post(error)
            throw error
        }
        
        // Check for deduplication
        if activeDownloads[videoID] != nil || pendingQueue.contains(videoID) {
            logger.info("Track already queued or downloading: \(track.title, privacy: .public)")
            return
        }
        
        // Add to pending queue
        pendingQueue.insert(videoID)
        track.downloadState = .queued
        track.downloadProgress = 0.0
        
        // Start processing if not already running
        ensureProcessorRunning(modelContext: modelContext)
    }
    
    /// Downloads a single track with pre-resolved audio URL
    func downloadTrack(_ track: ReverieTrack, audioURL: URL, videoID: String, modelContext: ModelContext) async throws {
        // Check if already downloaded
        guard track.downloadState != .downloaded else {
            return
        }
        
        // Check for deduplication
        if activeDownloads[videoID] != nil || pendingQueue.contains(videoID) {
            return
        }
        
        // Store the videoID if we don't have it
        if track.youtubeVideoID == nil {
            track.youtubeVideoID = videoID
        }
        
        // Add to pending queue
        pendingQueue.insert(videoID)
        track.downloadState = .queued
        track.downloadProgress = 0.0
        
        // Start processing
        ensureProcessorRunning(modelContext: modelContext)
    }
    
    /// Downloads all tracks in a playlist
    func downloadPlaylist(_ playlist: ReveriePlaylist, modelContext: ModelContext) async {
        let tracksToDownload = playlist.tracks.filter { 
            $0.downloadState != .downloaded && $0.youtubeVideoID != nil
        }
        
        logger.info("Queueing \(tracksToDownload.count, privacy: .public) tracks from playlist: \(playlist.name, privacy: .public)")
        
        for track in tracksToDownload {
            guard let videoID = track.youtubeVideoID else { continue }
            
            // Skip if already queued or downloading
            if activeDownloads[videoID] != nil || pendingQueue.contains(videoID) {
                continue
            }
            
            pendingQueue.insert(videoID)
            track.downloadState = .queued
            track.downloadProgress = 0.0
        }
        
        ensureProcessorRunning(modelContext: modelContext)
    }
    
    // MARK: - Queue Processor
    
    /// Ensures the concurrent download processor is running
    private func ensureProcessorRunning(modelContext: ModelContext) {
        guard downloadTask == nil || downloadTask?.isCancelled == true else {
            return
        }
        
        downloadTask = Task {
            await processDownloadQueue(modelContext: modelContext)
        }
    }
    
    /// Processes the download queue with TaskGroup concurrency
    private func processDownloadQueue(modelContext: ModelContext) async {
        await withTaskGroup(of: Void.self) { group in
            while !pendingQueue.isEmpty || !group.isEmpty {
                // Maintain concurrency limit
                while !pendingQueue.isEmpty && activeDownloads.count < maxConcurrentDownloads {
                    guard let videoID = pendingQueue.first else { break }
                    pendingQueue.remove(videoID)
                    
                    // Fetch the track from database
                    let descriptor = FetchDescriptor<ReverieTrack>(
                        predicate: #Predicate { $0.youtubeVideoID == videoID }
                    )
                    
                    guard let tracks = try? modelContext.fetch(descriptor),
                          let track = tracks.first else {
                        logger.error("Failed to fetch track with videoID: \(videoID, privacy: .public)")
                        continue
                    }
                    
                    // Add download task to group
                    group.addTask { [weak self] in
                        await self?.performDownload(
                            track: track,
                            videoID: videoID,
                            modelContext: modelContext
                        )
                    }
                }
                
                // Wait for at least one task to complete
                if !group.isEmpty {
                    await group.next()
                }
            }
        }
        
        downloadTask = nil
    }
    
    // MARK: - Download Execution with Retry
    
    /// Performs download for a single track with exponential backoff retry
    private func performDownload(track: ReverieTrack, videoID: String, modelContext: ModelContext) async {
        var attempt = 1
        var lastError: ReverieError?
        
        // Register as active
        await MainActor.run {
            activeDownloads[videoID] = DownloadProgress(
                trackID: track.id,
                videoID: videoID,
                attempt: attempt
            )
            track.downloadState = .downloading
        }
        
        // Retry loop with exponential backoff
        while attempt <= maxRetries {
            do {
                // Step 1: Resolve stream URL
                logger.info("Attempt \(attempt, privacy: .public)/\(self.maxRetries, privacy: .public): Resolving stream for videoID=\(videoID, privacy: .public)")
                
                let resolvedAudio = try await youtubeResolver.resolveAudioURL(videoID: videoID)
                
                // Step 2: Download file with progress tracking
                let fileData = try await downloadFileWithProgress(
                    from: resolvedAudio.audioURL,
                    videoID: videoID,
                    track: track
                )
                
                // Step 3: Save to storage
                let filename = "\(track.id.uuidString).m4a"
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
                    
                    activeDownloads.removeValue(forKey: videoID)
                    try? modelContext.save()
                    
                    HapticManager.shared.downloadComplete()
                }
                
                logger.info("✅ Download complete: \(track.title, privacy: .public)")
                return // Success!
                
            } catch let error as ReverieError {
                lastError = error
                logger.error("Download attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                
            } catch {
                lastError = ReverieError.download(.networkFailed(error))
                logger.error("Download attempt \(attempt, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
            
            // Exponential backoff before retry
            if attempt < maxRetries {
                let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                try? await Task.sleep(for: .seconds(delay))
                attempt += 1
                
                await MainActor.run {
                    activeDownloads[videoID]?.attempt = attempt
                }
            } else {
                break
            }
        }
        
        // All retries exhausted
        let finalError = lastError ?? ReverieError.download(.maxRetriesExceeded(attempts: maxRetries))
        
        await MainActor.run {
            track.downloadState = .failed
            track.downloadProgress = 0.0
            activeDownloads.removeValue(forKey: videoID)
            
            ErrorBannerState.shared.post(finalError)
            HapticManager.shared.error()
        }
    }
    
    // MARK: - Network Operations
    
    /// Downloads file with progress tracking
    private func downloadFileWithProgress(
        from url: URL,
        videoID: String,
        track: ReverieTrack
    ) async throws -> Data {
        let session = URLSession.shared
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { [weak self] localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: ReverieError.download(.networkFailed(error)))
                    return
                }
                
                guard let localURL = localURL else {
                    continuation.resume(throwing: ReverieError.download(.invalidURL(url.absoluteString)))
                    return
                }
                
                do {
                    let data = try Data(contentsOf: localURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: ReverieError.download(.storageFailed(error)))
                }
            }
            
            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    track.downloadProgress = progress.fractionCompleted
                    
                    if var downloadProgress = self.activeDownloads[videoID] {
                        downloadProgress.progress = progress.fractionCompleted
                        self.activeDownloads[videoID] = downloadProgress
                    }
                }
            }
            
            // Store observation and task for cleanup
            Task { @MainActor [weak self] in
                if var downloadProgress = self?.activeDownloads[videoID] {
                    // Note: We're not storing the task reference in this rewrite
                    // for simplicity, but could be added for cancellation support
                }
            }
            
            task.resume()
        }
    }
    
    // MARK: - Cancellation & Deletion
    
    /// Cancels a download by trackID
    func cancelDownload(trackID: UUID, modelContext: ModelContext) async {
        // Find the videoID for this track
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { $0.id == trackID }
        )
        
        guard let tracks = try? modelContext.fetch(descriptor),
              let track = tracks.first,
              let videoID = track.youtubeVideoID else {
            return
        }
        
        // Remove from active downloads and pending queue
        activeDownloads.removeValue(forKey: videoID)
        pendingQueue.remove(videoID)
        
        // Update track state
        track.downloadState = .notDownloaded
        track.downloadProgress = 0.0
        try? modelContext.save()
        
        logger.info("Cancelled download: \(track.title, privacy: .public)")
    }
    
    /// Deletes a downloaded track's file
    func deleteTrack(_ track: ReverieTrack, modelContext: ModelContext) async throws {
        guard let relativePath = track.localFilePath else {
            return
        }
        
        do {
            try await storageManager.deleteAudio(relativePath: relativePath)
            
            await MainActor.run {
                track.downloadState = .notDownloaded
                track.localFilePath = nil
                track.fileSizeBytes = nil
                track.downloadDate = nil
                track.downloadProgress = 0.0
                
                try? modelContext.save()
            }
            
            logger.info("Deleted track file: \(track.title, privacy: .public)")
            
        } catch {
            throw ReverieError.storage(.fileDeleteFailed(error))
        }
    }
}
