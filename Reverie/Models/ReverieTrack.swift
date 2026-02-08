//
//  ReverieTrack.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData

@Model
final class ReverieTrack {
    var id: UUID
    var title: String
    var artist: String
    var album: String
    var durationSeconds: Int
    var albumArtURL: String?
    var albumArtData: Data?  // Cached locally
    
    // Source info
    var spotifyID: String?
    var youtubeVideoID: String?
    var musicBrainzID: String?
    
    // Download state
    var downloadState: DownloadState
    var localFilePath: String?  // Relative path to audio file
    var fileSizeBytes: Int64?
    var downloadDate: Date?
    var downloadProgress: Double  // 0.0 to 1.0
    
    // Playback
    var lastPlayedDate: Date?
    var playCount: Int
    
    // Relationships - many-to-many with playlists
    var playlists: [ReveriePlaylist]
    
    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String = "",
        durationSeconds: Int = 0,
        albumArtURL: String? = nil,
        albumArtData: Data? = nil,
        spotifyID: String? = nil,
        youtubeVideoID: String? = nil,
        musicBrainzID: String? = nil,
        downloadState: DownloadState = .notDownloaded,
        localFilePath: String? = nil,
        fileSizeBytes: Int64? = nil,
        downloadDate: Date? = nil,
        downloadProgress: Double = 0.0,
        lastPlayedDate: Date? = nil,
        playCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.albumArtURL = albumArtURL
        self.albumArtData = albumArtData
        self.spotifyID = spotifyID
        self.youtubeVideoID = youtubeVideoID
        self.musicBrainzID = musicBrainzID
        self.downloadState = downloadState
        self.localFilePath = localFilePath
        self.fileSizeBytes = fileSizeBytes
        self.downloadDate = downloadDate
        self.downloadProgress = downloadProgress
        self.lastPlayedDate = lastPlayedDate
        self.playCount = playCount
        self.playlists = []
    }
    
    /// Formatted duration string (e.g., "3:45")
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted file size (e.g., "3.2 MB")
    var formattedFileSize: String? {
        guard let bytes = fileSizeBytes else { return nil }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
}
