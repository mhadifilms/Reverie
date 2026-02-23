//
//  ListeningSignal.swift
//  Reverie
//
//  Tracks user listening behavior for on-device recommendations.
//  All data stays local — never leaves the device.
//

import Foundation
import SwiftData

@Model
final class ListeningSignal {
    var id: UUID
    var timestamp: Date
    var signalType: String  // "play", "skip", "complete", "search", "download"
    var trackID: UUID?
    var artistName: String?
    var query: String?
    var durationListened: TimeInterval?
    var isFullPlay: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        signalType: String,
        trackID: UUID? = nil,
        artistName: String? = nil,
        query: String? = nil,
        durationListened: TimeInterval? = nil,
        isFullPlay: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.signalType = signalType
        self.trackID = trackID
        self.artistName = artistName
        self.query = query
        self.durationListened = durationListened
        self.isFullPlay = isFullPlay
    }
}
