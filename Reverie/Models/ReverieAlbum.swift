//
//  ReverieAlbum.swift
//  Reverie
//
//  Phase 2A: Album model for metadata enrichment
//

import Foundation
import SwiftData

@Model
final class ReverieAlbum {
    var id: UUID
    var title: String
    var artistName: String
    var artist: ReverieArtist?
    var releaseDate: Date?
    var albumArtData: Data?
    var albumDescription: String?
    @Relationship(inverse: \ReverieTrack.albumRelation) var tracks: [ReverieTrack]

    init(title: String, artistName: String) {
        self.id = UUID()
        self.title = title
        self.artistName = artistName
        self.tracks = []
    }
}
