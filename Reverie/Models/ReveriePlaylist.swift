//
//  ReveriePlaylist.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData

@Model
final class ReveriePlaylist {
    var id: UUID
    var name: String
    var spotifyURL: String?
    var coverArtURL: String?
    var coverArtData: Data?  // Cached locally
    var dateImported: Date
    var dateCreated: Date
    var isCustom: Bool  // true for user-created playlists, false for imported
    var tracks: [ReverieTrack]
    
    init(
        id: UUID = UUID(),
        name: String,
        spotifyURL: String? = nil,
        coverArtURL: String? = nil,
        coverArtData: Data? = nil,
        dateImported: Date = Date(),
        dateCreated: Date = Date(),
        isCustom: Bool = false,
        tracks: [ReverieTrack] = []
    ) {
        self.id = id
        self.name = name
        self.spotifyURL = spotifyURL
        self.coverArtURL = coverArtURL
        self.coverArtData = coverArtData
        self.dateImported = dateImported
        self.dateCreated = dateCreated
        self.isCustom = isCustom
        self.tracks = tracks
    }
    
    /// Number of tracks in the playlist
    var trackCount: Int {
        return tracks.count
    }
    
    /// Number of downloaded tracks
    var downloadedTrackCount: Int {
        return tracks.filter { $0.downloadState == .downloaded }.count
    }
    
    /// Total size of all downloaded tracks in bytes
    var totalSizeBytes: Int64 {
        return tracks.compactMap { $0.fileSizeBytes }.reduce(0, +)
    }
    
    /// Formatted total size (e.g., "145.3 MB")
    var formattedTotalSize: String {
        let mb = Double(totalSizeBytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }
    
    /// Download progress for the entire playlist (0.0 to 1.0)
    var overallProgress: Double {
        guard !tracks.isEmpty else { return 0.0 }
        let totalProgress = tracks.reduce(0.0) { result, track in
            return result + (track.downloadState == .downloaded ? 1.0 : track.downloadProgress)
        }
        return totalProgress / Double(tracks.count)
    }
    
    /// Whether all tracks in the playlist are downloaded
    var isFullyDownloaded: Bool {
        return !tracks.isEmpty && tracks.allSatisfy { $0.downloadState == .downloaded }
    }
}
