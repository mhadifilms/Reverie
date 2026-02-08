//
//  DownloadState.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation

/// Represents the download state of a track
enum DownloadState: String, Codable {
    case notDownloaded      // Track exists in library but not downloaded
    case queued             // Queued for download
    case downloading        // Currently downloading
    case downloaded         // Successfully downloaded and available offline
    case failed             // Download failed
    
    var isPlayable: Bool {
        return self == .downloaded
    }
    
    var isInProgress: Bool {
        return self == .downloading || self == .queued
    }
}
