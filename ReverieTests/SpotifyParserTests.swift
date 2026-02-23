//
//  SpotifyParserTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for SpotifyParser URL normalization and ID extraction
//

import Testing
@testable import Reverie

struct SpotifyParserTests {

    // MARK: - URL Normalization

    /// Tests are scoped to the public and testable surface:
    /// - normalizeSpotifyURL (via parsePlaylist throwing on unsupported types)
    /// - extractPlaylistID / extractAlbumID (via parsePlaylist routing)
    /// Since SpotifyParser is an actor with mostly private methods,
    /// we test URL handling through the public parsePlaylist entry point.
    /// Network-dependent parsing is NOT tested here (requires live endpoints).

    // MARK: - Playlist URL Routing

    @Test func parsePlaylistRejectsUnsupportedURL() async {
        let parser = SpotifyParser()
        do {
            _ = try await parser.parsePlaylist(from: "https://open.spotify.com/track/abc123")
            #expect(Bool(false), "Should have thrown unsupportedURLType")
        } catch let error as SpotifyParser.SpotifyError {
            #expect(error == .unsupportedURLType)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test func parsePlaylistRejectsRandomString() async {
        let parser = SpotifyParser()
        do {
            _ = try await parser.parsePlaylist(from: "not a url at all")
            #expect(Bool(false), "Should have thrown unsupportedURLType")
        } catch let error as SpotifyParser.SpotifyError {
            #expect(error == .unsupportedURLType)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    @Test func parsePlaylistRejectsEmptyString() async {
        let parser = SpotifyParser()
        do {
            _ = try await parser.parsePlaylist(from: "")
            #expect(Bool(false), "Should have thrown unsupportedURLType")
        } catch let error as SpotifyParser.SpotifyError {
            #expect(error == .unsupportedURLType)
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }

    // MARK: - SpotifyError Descriptions

    @Test func errorDescriptions() {
        #expect(SpotifyParser.SpotifyError.invalidURL.errorDescription == "Invalid Spotify URL")
        #expect(SpotifyParser.SpotifyError.parsingError.errorDescription == "Failed to parse Spotify data")
        #expect(SpotifyParser.SpotifyError.unsupportedURLType.errorDescription == "Only playlist and album URLs are supported")
    }

    @Test func networkErrorDescription() {
        let underlyingError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        let error = SpotifyParser.SpotifyError.networkError(underlyingError)
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    // MARK: - Data Structures

    @Test func playlistDataInitialization() {
        let track = SpotifyParser.TrackData(
            title: "Test Song",
            artist: "Test Artist",
            album: "Test Album",
            durationMs: 180000,
            albumArtURL: "https://example.com/art.jpg",
            spotifyID: "abc123"
        )

        #expect(track.title == "Test Song")
        #expect(track.artist == "Test Artist")
        #expect(track.album == "Test Album")
        #expect(track.durationMs == 180000)
        #expect(track.albumArtURL == "https://example.com/art.jpg")
        #expect(track.spotifyID == "abc123")
    }

    @Test func playlistDataWithNilOptionals() {
        let track = SpotifyParser.TrackData(
            title: "Minimal",
            artist: "Unknown",
            album: "",
            durationMs: 0,
            albumArtURL: nil,
            spotifyID: nil
        )

        #expect(track.albumArtURL == nil)
        #expect(track.spotifyID == nil)
    }

    @Test func playlistDataStructure() {
        let playlist = SpotifyParser.PlaylistData(
            id: "abc123",
            name: "My Playlist",
            coverArtURL: "https://example.com/cover.jpg",
            tracks: [
                SpotifyParser.TrackData(
                    title: "Song 1",
                    artist: "Artist 1",
                    album: "Album 1",
                    durationMs: 200000,
                    albumArtURL: nil,
                    spotifyID: "track1"
                )
            ]
        )

        #expect(playlist.id == "abc123")
        #expect(playlist.name == "My Playlist")
        #expect(playlist.coverArtURL == "https://example.com/cover.jpg")
        #expect(playlist.tracks.count == 1)
        #expect(playlist.tracks[0].title == "Song 1")
    }

    @Test func playlistDataWithNilCover() {
        let playlist = SpotifyParser.PlaylistData(
            id: "xyz",
            name: "No Cover",
            coverArtURL: nil,
            tracks: []
        )

        #expect(playlist.coverArtURL == nil)
        #expect(playlist.tracks.isEmpty)
    }
}

// MARK: - Equatable conformance for test assertions

extension SpotifyParser.SpotifyError: @retroactive Equatable {
    public static func == (lhs: SpotifyParser.SpotifyError, rhs: SpotifyParser.SpotifyError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.parsingError, .parsingError),
             (.unsupportedURLType, .unsupportedURLType):
            return true
        case (.networkError, .networkError):
            return true
        default:
            return false
        }
    }
}
