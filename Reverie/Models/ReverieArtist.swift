//
//  ReverieArtist.swift
//  Reverie
//
//  Phase 2A: Artist model for metadata enrichment
//

import Foundation
import SwiftData

@Model
final class ReverieArtist {
    var id: UUID
    var name: String
    var channelID: String?
    var thumbnailData: Data?
    var bio: String?
    @Relationship(inverse: \ReverieTrack.artistRelation) var tracks: [ReverieTrack]

    init(name: String, channelID: String? = nil) {
        self.id = UUID()
        self.name = name
        self.channelID = channelID
        self.tracks = []
    }
}
