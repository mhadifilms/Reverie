//
//  ReverieError.swift
//  Reverie
//
//  Centralized error handling framework for production-grade error reporting
//

import Foundation
import OSLog

/// Centralized error type for all Reverie operations
enum ReverieError: LocalizedError {
    case download(DownloadError)
    case playback(PlaybackError)
    case `import`(ImportError)
    case search(SearchError)
    case storage(StorageError)
    
    // MARK: - Domain-Specific Errors
    
    enum DownloadError {
        case resolutionFailed(videoID: String, underlyingError: Error?)
        case networkFailed(Error)
        case storageFailed(Error)
        case alreadyDownloading(trackTitle: String)
        case invalidURL(String)
        case cancelled(trackTitle: String)
        case maxRetriesExceeded(attempts: Int)
        case unsupportedFormat(extension: String)
        
        var userMessage: String {
            switch self {
            case .resolutionFailed(let videoID, _):
                return "Could not find audio for this track"
            case .networkFailed:
                return "Network connection failed"
            case .storageFailed:
                return "Failed to save downloaded file"
            case .alreadyDownloading(let title):
                return "\(title) is already downloading"
            case .invalidURL:
                return "Invalid audio URL"
            case .cancelled(let title):
                return "Cancelled download of \(title)"
            case .maxRetriesExceeded(let attempts):
                return "Download failed after \(attempts) attempts"
            case .unsupportedFormat(let ext):
                return "Unsupported audio format: \(ext)"
            }
        }
        
        var debugMessage: String {
            switch self {
            case .resolutionFailed(let videoID, let error):
                return "Resolution failed for videoID=\(videoID), error=\(String(describing: error))"
            case .networkFailed(let error):
                return "Network error: \(error.localizedDescription)"
            case .storageFailed(let error):
                return "Storage error: \(error.localizedDescription)"
            case .alreadyDownloading(let title):
                return "Duplicate download request for: \(title)"
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .cancelled(let title):
                return "User cancelled: \(title)"
            case .maxRetriesExceeded(let attempts):
                return "Exceeded max retry attempts: \(attempts)"
            case .unsupportedFormat(let ext):
                return "Unsupported format: \(ext)"
            }
        }
    }
    
    enum PlaybackError {
        case trackNotDownloaded(trackTitle: String)
        case fileNotFound(path: String)
        case fileLoadFailed(Error)
        case audioEngineFailed(Error)
        case seekFailed(time: TimeInterval)
        case invalidQueue
        
        var userMessage: String {
            switch self {
            case .trackNotDownloaded(let title):
                return "\(title) has not been downloaded"
            case .fileNotFound:
                return "Audio file not found"
            case .fileLoadFailed:
                return "Failed to load audio file"
            case .audioEngineFailed:
                return "Playback engine error"
            case .seekFailed:
                return "Failed to seek"
            case .invalidQueue:
                return "Invalid playback queue"
            }
        }
        
        var debugMessage: String {
            switch self {
            case .trackNotDownloaded(let title):
                return "Track not downloaded: \(title)"
            case .fileNotFound(let path):
                return "File not found at: \(path)"
            case .fileLoadFailed(let error):
                return "AVAudioFile load failed: \(error.localizedDescription)"
            case .audioEngineFailed(let error):
                return "AVAudioEngine error: \(error.localizedDescription)"
            case .seekFailed(let time):
                return "Seek failed to time: \(time)"
            case .invalidQueue:
                return "Playback queue is empty or invalid"
            }
        }
    }
    
    enum ImportError {
        case invalidURL(String)
        case unsupportedURLType(String)
        case networkFailed(Error)
        case parsingFailed(reason: String?)
        case noTracksFound
        case spotifyURINotSupported(String)
        
        var userMessage: String {
            switch self {
            case .invalidURL:
                return "Invalid Spotify URL"
            case .unsupportedURLType:
                return "Only playlists and albums are supported"
            case .networkFailed:
                return "Could not connect to Spotify"
            case .parsingFailed:
                return "Failed to parse playlist data"
            case .noTracksFound:
                return "No tracks found in this playlist"
            case .spotifyURINotSupported:
                return "Spotify URIs are not yet supported. Please use a web URL instead."
            }
        }
        
        var debugMessage: String {
            switch self {
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .unsupportedURLType(let type):
                return "Unsupported URL type: \(type)"
            case .networkFailed(let error):
                return "Network error: \(error.localizedDescription)"
            case .parsingFailed(let reason):
                return "Parsing failed: \(reason ?? "unknown reason")"
            case .noTracksFound:
                return "Playlist contains zero tracks"
            case .spotifyURINotSupported(let uri):
                return "URI not supported: \(uri)"
            }
        }
    }
    
    enum SearchError {
        case emptyQuery
        case networkFailed(Error)
        case invalidResponse
        case noResults
        
        var userMessage: String {
            switch self {
            case .emptyQuery:
                return "Please enter a search query"
            case .networkFailed:
                return "Search failed. Check your connection."
            case .invalidResponse:
                return "Received invalid response from YouTube Music"
            case .noResults:
                return "No results found"
            }
        }
        
        var debugMessage: String {
            switch self {
            case .emptyQuery:
                return "Search called with empty query"
            case .networkFailed(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "InnerTube response parsing failed"
            case .noResults:
                return "Zero results returned from InnerTube"
            }
        }
    }
    
    enum StorageError {
        case directoryCreationFailed(Error)
        case fileSaveFailed(Error)
        case fileDeleteFailed(Error)
        case insufficientSpace(required: Int64, available: Int64)
        case invalidPath(String)
        
        var userMessage: String {
            switch self {
            case .directoryCreationFailed:
                return "Failed to create storage directory"
            case .fileSaveFailed:
                return "Failed to save file"
            case .fileDeleteFailed:
                return "Failed to delete file"
            case .insufficientSpace(let required, let available):
                let requiredMB = Double(required) / 1_048_576
                let availableMB = Double(available) / 1_048_576
                return String(format: "Not enough storage. Need %.1f MB, have %.1f MB", requiredMB, availableMB)
            case .invalidPath:
                return "Invalid file path"
            }
        }
        
        var debugMessage: String {
            switch self {
            case .directoryCreationFailed(let error):
                return "Directory creation failed: \(error.localizedDescription)"
            case .fileSaveFailed(let error):
                return "File save failed: \(error.localizedDescription)"
            case .fileDeleteFailed(let error):
                return "File delete failed: \(error.localizedDescription)"
            case .insufficientSpace(let required, let available):
                return "Insufficient space: required=\(required), available=\(available)"
            case .invalidPath(let path):
                return "Invalid path: \(path)"
            }
        }
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .download(let error):
            return error.userMessage
        case .playback(let error):
            return error.userMessage
        case .import(let error):
            return error.userMessage
        case .search(let error):
            return error.userMessage
        case .storage(let error):
            return error.userMessage
        }
    }
    
    // MARK: - Logging
    
    /// Logs error to OSLog with appropriate category
    func log() {
        let (subsystem, category) = logDetails
        let logger = Logger(subsystem: subsystem, category: category)
        
        switch self {
        case .download(let error):
            logger.error("Download error: \(error.debugMessage, privacy: .public)")
        case .playback(let error):
            logger.error("Playback error: \(error.debugMessage, privacy: .public)")
        case .import(let error):
            logger.error("Import error: \(error.debugMessage, privacy: .public)")
        case .search(let error):
            logger.error("Search error: \(error.debugMessage, privacy: .public)")
        case .storage(let error):
            logger.error("Storage error: \(error.debugMessage, privacy: .public)")
        }
    }
    
    private var logDetails: (subsystem: String, category: String) {
        let subsystem = "com.reverie"
        let category: String
        
        switch self {
        case .download:
            category = "download"
        case .playback:
            category = "playback"
        case .import:
            category = "import"
        case .search:
            category = "search"
        case .storage:
            category = "storage"
        }
        
        return (subsystem, category)
    }
}

// MARK: - Error Banner State

/// Global error state for UI consumption
@MainActor
@Observable
class ErrorBannerState {
    static let shared = ErrorBannerState()
    
    struct ErrorItem: Identifiable {
        let id = UUID()
        let error: ReverieError
        let timestamp: Date = Date()
    }
    
    var currentError: ErrorItem?
    private var errorQueue: [ErrorItem] = []
    
    private init() {}
    
    /// Posts an error to be displayed in the error banner
    func post(_ error: ReverieError) {
        error.log()
        
        let item = ErrorItem(error: error)
        
        if currentError == nil {
            currentError = item
            scheduleAutoDismiss()
        } else {
            errorQueue.append(item)
        }
    }
    
    /// Dismisses the current error and shows the next one in queue
    func dismiss() {
        if errorQueue.isEmpty {
            currentError = nil
        } else {
            currentError = errorQueue.removeFirst()
            scheduleAutoDismiss()
        }
    }
    
    private func scheduleAutoDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(5))
            dismiss()
        }
    }
}
