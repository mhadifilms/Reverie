//
//  SpotifyParser.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation

/// Extracts playlist data from Spotify URLs via web scraping
actor SpotifyParser {
    
    struct PlaylistData {
        let id: String
        let name: String
        let coverArtURL: String?
        let tracks: [TrackData]
    }
    
    struct TrackData {
        let title: String
        let artist: String
        let album: String
        let durationMs: Int
        let albumArtURL: String?
        let spotifyID: String?
    }
    
    enum SpotifyError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parsingError
        case unsupportedURLType
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Spotify URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .parsingError:
                return "Failed to parse Spotify data"
            case .unsupportedURLType:
                return "Only playlist and album URLs are supported"
            }
        }
    }
    
    /// Parses a Spotify playlist or album URL and extracts all track data
    func parsePlaylist(from urlString: String) async throws -> PlaylistData {
        // Determine if it's a playlist or album
        if urlString.contains("/album/") {
            return try await parseAlbum(from: urlString)
        } else if urlString.contains("/playlist/") {
            return try await parsePlaylistURL(from: urlString)
        } else {
            throw SpotifyError.unsupportedURLType
        }
    }
    
    /// Parses a Spotify playlist URL and extracts all track data
    private func parsePlaylistURL(from urlString: String) async throws -> PlaylistData {
        // Extract playlist ID from URL
        guard let playlistID = extractPlaylistID(from: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        // Use the embed URL which has the track data
        let embedURL = "https://open.spotify.com/embed/playlist/\(playlistID)"
        
        guard let url = URL(string: embedURL) else {
            throw SpotifyError.invalidURL
        }
        
        print("🎵 Fetching playlist from embed: \(embedURL)")
        
        // Fetch the HTML page with proper headers
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw SpotifyError.parsingError
        }
        
        print("✅ Downloaded HTML page")
        
        // Parse using the same embed structure
        let playlistData = try parseHTMLForEmbedPlaylistData(html: html, playlistID: playlistID)
        
        return playlistData
    }
    
    /// Parses a Spotify album URL and extracts all track data
    /// Uses the Spotify embed page which still has __NEXT_DATA__
    private func parseAlbum(from urlString: String) async throws -> PlaylistData {
        // Extract album ID from URL
        guard let albumID = extractAlbumID(from: urlString) else {
            throw SpotifyError.invalidURL
        }
        
        // Use the embed URL which has the track data
        let embedURL = "https://open.spotify.com/embed/album/\(albumID)"
        
        guard let url = URL(string: embedURL) else {
            throw SpotifyError.invalidURL
        }
        
        print("🎵 Fetching album from embed: \(embedURL)")
        
        // Fetch the HTML page with proper headers
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw SpotifyError.parsingError
        }
        
        print("✅ Downloaded HTML page")
        
        // Parse the HTML for embedded JSON data
        let albumData = try parseHTMLForEmbedAlbumData(html: html, albumID: albumID)
        
        return albumData
    }
    
    /// Parses HTML from Spotify embed page to extract playlist data
    private func parseHTMLForEmbedPlaylistData(html: String, playlistID: String) throws -> PlaylistData {
        // Spotify embed pages have data in <script id="__NEXT_DATA__" type="application/json">
        guard let scriptStart = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let scriptEnd = html.range(of: "</script>", range: scriptStart.upperBound..<html.endIndex) else {
            print("❌ Could not find __NEXT_DATA__ script tag")
            throw SpotifyError.parsingError
        }
        
        let jsonString = String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Could not convert JSON string to data")
            throw SpotifyError.parsingError
        }
        
        // Parse the JSON
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Navigate: props.pageProps.state.data.entity
        guard let props = json?["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let data = state["data"] as? [String: Any],
              let entity = data["entity"] as? [String: Any] else {
            print("❌ Could not navigate to entity in JSON structure")
            throw SpotifyError.parsingError
        }
        
        print("✅ Found playlist entity")
        
        // Extract playlist info
        let name = entity["name"] as? String ?? "Unknown Playlist"
        print("📀 Playlist name: \(name)")
        
        // Extract cover art
        var coverArtURL: String?
        if let visual = entity["visualIdentity"] as? [String: Any],
           let imageURL = visual["image"] as? String {
            coverArtURL = imageURL
            print("🖼️ Found cover art")
        }
        
        // Extract tracks from trackList
        guard let trackList = entity["trackList"] as? [[String: Any]] else {
            print("❌ Could not find trackList in entity")
            throw SpotifyError.parsingError
        }
        
        var tracks: [TrackData] = []
        
        for trackItem in trackList {
            let trackName = trackItem["title"] as? String ?? "Unknown"
            let artistName = trackItem["subtitle"] as? String ?? "Unknown Artist"
            let durationMs = trackItem["duration"] as? Int ?? 0
            
            // Extract Spotify ID from URI
            var spotifyID: String?
            if let uri = trackItem["uri"] as? String {
                spotifyID = uri.replacingOccurrences(of: "spotify:track:", with: "")
            }
            
            // For playlists, we don't know the album name from this structure
            let track = TrackData(
                title: trackName,
                artist: artistName,
                album: "",
                durationMs: durationMs,
                albumArtURL: nil,
                spotifyID: spotifyID
            )
            
            tracks.append(track)
        }
        
        print("✅ Extracted \(tracks.count) tracks from playlist")
        
        return PlaylistData(
            id: playlistID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
    
    /// Parses HTML from Spotify embed page to extract album data
    private func parseHTMLForEmbedAlbumData(html: String, albumID: String) throws -> PlaylistData {
        // Spotify embed pages have data in <script id="__NEXT_DATA__" type="application/json">
        guard let scriptStart = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let scriptEnd = html.range(of: "</script>", range: scriptStart.upperBound..<html.endIndex) else {
            print("❌ Could not find __NEXT_DATA__ script tag")
            throw SpotifyError.parsingError
        }
        
        let jsonString = String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Could not convert JSON string to data")
            throw SpotifyError.parsingError
        }
        
        // Parse the JSON
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Navigate: props.pageProps.state.data.entity
        guard let props = json?["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let data = state["data"] as? [String: Any],
              let entity = data["entity"] as? [String: Any] else {
            print("❌ Could not navigate to entity in JSON structure")
            throw SpotifyError.parsingError
        }
        
        print("✅ Found album entity")
        
        // Extract album info
        let name = entity["name"] as? String ?? "Unknown Album"
        print("📀 Album name: \(name)")
        
        // Extract cover art
        var coverArtURL: String?
        if let visual = entity["visualIdentity"] as? [String: Any],
           let imageURL = visual["image"] as? String {
            coverArtURL = imageURL
            print("🖼️ Found cover art")
        }
        
        // Extract tracks from trackList
        guard let trackList = entity["trackList"] as? [[String: Any]] else {
            print("❌ Could not find trackList in entity")
            throw SpotifyError.parsingError
        }
        
        var tracks: [TrackData] = []
        
        for trackItem in trackList {
            let trackName = trackItem["title"] as? String ?? "Unknown"
            let artistName = trackItem["subtitle"] as? String ?? "Unknown Artist"
            let durationMs = trackItem["duration"] as? Int ?? 0
            
            // Extract Spotify ID from URI
            var spotifyID: String?
            if let uri = trackItem["uri"] as? String {
                spotifyID = uri.replacingOccurrences(of: "spotify:track:", with: "")
            }
            
            let track = TrackData(
                title: trackName,
                artist: artistName,
                album: name,
                durationMs: durationMs,
                albumArtURL: coverArtURL,
                spotifyID: spotifyID
            )
            
            tracks.append(track)
        }
        
        print("✅ Extracted \(tracks.count) tracks from album")
        
        return PlaylistData(
            id: albumID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
    
    /// Parses Spotify album JSON response
    private func parseSpotifyAlbumJSON(data: Data, albumID: String) throws -> PlaylistData {
        // Parse the JSON response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpotifyError.parsingError
        }
        
        // Extract album info
        let name = json["name"] as? String ?? "Unknown Album"
        let images = json["images"] as? [[String: Any]]
        let coverArtURL = images?.first?["url"] as? String
        
        print("📀 Album: \(name)")
        
        // Extract tracks
        guard let tracksContainer = json["tracks"] as? [String: Any],
              let tracksArray = tracksContainer["items"] as? [[String: Any]] else {
            throw SpotifyError.parsingError
        }
        
        var tracks: [TrackData] = []
        
        for trackData in tracksArray {
            let trackName = trackData["name"] as? String ?? "Unknown"
            
            // Extract artists
            var artistName = "Unknown Artist"
            if let artists = trackData["artists"] as? [[String: Any]],
               let firstArtist = artists.first,
               let artistNameValue = firstArtist["name"] as? String {
                artistName = artistNameValue
            }
            
            // Extract duration
            let durationMs = trackData["duration_ms"] as? Int ?? 0
            
            // Extract Spotify ID
            let spotifyID = trackData["id"] as? String
            
            let track = TrackData(
                title: trackName,
                artist: artistName,
                album: name,
                durationMs: durationMs,
                albumArtURL: coverArtURL,
                spotifyID: spotifyID
            )
            
            tracks.append(track)
        }
        
        print("✅ Extracted \(tracks.count) tracks from album")
        
        return PlaylistData(
            id: albumID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
    
    /// Extracts playlist ID from various Spotify URL formats
    private func extractPlaylistID(from urlString: String) -> String? {
        // Handle formats:
        // https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M
        // https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=...
        // spotify:playlist:37i9dQZF1DXcBWIGoYBM5M
        
        if urlString.contains("spotify.com/playlist/") {
            // Extract from web URL
            let components = urlString.components(separatedBy: "playlist/")
            guard components.count >= 2 else { return nil }
            let idPart = components[1].components(separatedBy: "?")[0]
            return idPart
        } else if urlString.hasPrefix("spotify:playlist:") {
            // Extract from URI
            return urlString.replacingOccurrences(of: "spotify:playlist:", with: "")
        }
        
        return nil
    }
    
    /// Extracts album ID from various Spotify URL formats
    private func extractAlbumID(from urlString: String) -> String? {
        // Handle formats:
        // https://open.spotify.com/album/4psDRFbIlUM1KUb1omccXo
        // https://open.spotify.com/album/4psDRFbIlUM1KUb1omccXo?si=...
        // spotify:album:4psDRFbIlUM1KUb1omccXo
        
        if urlString.contains("spotify.com/album/") {
            // Extract from web URL
            let components = urlString.components(separatedBy: "album/")
            guard components.count >= 2 else { return nil }
            let idPart = components[1].components(separatedBy: "?")[0]
            return idPart
        } else if urlString.hasPrefix("spotify:album:") {
            // Extract from URI
            return urlString.replacingOccurrences(of: "spotify:album:", with: "")
        }
        
        return nil
    }
    
    /// Parses HTML to extract playlist data from embedded JSON
    private func parseHTMLForPlaylistData(html: String, playlistID: String) throws -> PlaylistData {
        // Spotify embeds data in <script id="__NEXT_DATA__" type="application/json">
        // Find the script tag
        guard let scriptStart = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let scriptEnd = html.range(of: "</script>", range: scriptStart.upperBound..<html.endIndex) else {
            throw SpotifyError.parsingError
        }
        
        let jsonString = String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw SpotifyError.parsingError
        }
        
        // Parse the JSON
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Navigate through the nested structure
        guard let props = json?["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let data = state["data"] as? [String: Any],
              let playlistMetadata = data["playlistMetadata"] as? [String: Any] else {
            throw SpotifyError.parsingError
        }
        
        // Extract playlist info
        let name = playlistMetadata["name"] as? String ?? "Unknown Playlist"
        
        // Extract cover art
        var coverArtURL: String?
        if let images = playlistMetadata["images"] as? [[String: Any]],
           let firstImage = images.first,
           let url = firstImage["url"] as? String {
            coverArtURL = url
        }
        
        // Extract tracks
        guard let contents = data["contents"] as? [String: Any],
              let items = contents["items"] as? [[String: Any]] else {
            throw SpotifyError.parsingError
        }
        
        var tracks: [TrackData] = []
        
        for item in items {
            guard let itemContent = item["itemV2"] as? [String: Any],
                  let trackData = itemContent["data"] as? [String: Any] else {
                continue
            }
            
            let trackName = trackData["name"] as? String ?? "Unknown"
            
            // Extract artists
            var artistName = "Unknown Artist"
            if let artists = trackData["artists"] as? [String: Any],
               let items = artists["items"] as? [[String: Any]],
               let firstArtist = items.first,
               let profile = firstArtist["profile"] as? [String: Any],
               let name = profile["name"] as? String {
                artistName = name
            }
            
            // Extract album
            var albumName = ""
            var albumArtURL: String?
            if let albumData = trackData["albumOfTrack"] as? [String: Any] {
                albumName = albumData["name"] as? String ?? ""
                
                if let coverArt = albumData["coverArt"] as? [String: Any],
                   let sources = coverArt["sources"] as? [[String: Any]],
                   let firstSource = sources.first,
                   let url = firstSource["url"] as? String {
                    albumArtURL = url
                }
            }
            
            // Extract duration
            var durationMs = 0
            if let duration = trackData["duration"] as? [String: Any],
               let totalMs = duration["totalMilliseconds"] as? Int {
                durationMs = totalMs
            }
            
            // Extract Spotify ID
            var spotifyID: String?
            if let uri = trackData["uri"] as? String {
                spotifyID = uri.replacingOccurrences(of: "spotify:track:", with: "")
            }
            
            let track = TrackData(
                title: trackName,
                artist: artistName,
                album: albumName,
                durationMs: durationMs,
                albumArtURL: albumArtURL,
                spotifyID: spotifyID
            )
            
            tracks.append(track)
        }
        
        return PlaylistData(
            id: playlistID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
    
    /// Parses HTML to extract album data from embedded JSON
    private func parseHTMLForAlbumData(html: String, albumID: String) throws -> PlaylistData {
        // Spotify embeds data in <script id="__NEXT_DATA__" type="application/json">
        // Find the script tag
        guard let scriptStart = html.range(of: "<script id=\"__NEXT_DATA__\" type=\"application/json\">"),
              let scriptEnd = html.range(of: "</script>", range: scriptStart.upperBound..<html.endIndex) else {
            print("❌ Could not find __NEXT_DATA__ script tag")
            throw SpotifyError.parsingError
        }
        
        let jsonString = String(html[scriptStart.upperBound..<scriptEnd.lowerBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Could not convert JSON string to data")
            throw SpotifyError.parsingError
        }
        
        // Parse the JSON
        let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Navigate through the nested structure for albums
        guard let props = json?["props"] as? [String: Any],
              let pageProps = props["pageProps"] as? [String: Any],
              let state = pageProps["state"] as? [String: Any],
              let data = state["data"] as? [String: Any],
              let albumMetadata = data["albumUnion"] as? [String: Any] else {
            print("❌ Could not navigate to albumUnion in JSON structure")
            throw SpotifyError.parsingError
        }
        
        print("✅ Found album metadata")
        
        // Extract album info
        let name = albumMetadata["name"] as? String ?? "Unknown Album"
        print("📀 Album name: \(name)")
        
        // Extract cover art
        var coverArtURL: String?
        if let coverArt = albumMetadata["coverArt"] as? [String: Any],
           let sources = coverArt["sources"] as? [[String: Any]],
           let firstSource = sources.first,
           let url = firstSource["url"] as? String {
            coverArtURL = url
            print("🖼️ Found cover art")
        }
        
        // Extract tracks
        guard let discs = albumMetadata["discs"] as? [String: Any],
              let items = discs["items"] as? [[String: Any]] else {
            print("❌ Could not find discs/items in album")
            throw SpotifyError.parsingError
        }
        
        var tracks: [TrackData] = []
        
        for disc in items {
            guard let discTracks = disc["tracks"] as? [String: Any],
                  let trackItems = discTracks["items"] as? [[String: Any]] else {
                continue
            }
            
            for trackItem in trackItems {
                guard let trackData = trackItem["track"] as? [String: Any] else {
                    continue
                }
                
                let trackName = trackData["name"] as? String ?? "Unknown"
                
                // Extract artists
                var artistName = "Unknown Artist"
                if let artists = trackData["artists"] as? [String: Any],
                   let items = artists["items"] as? [[String: Any]],
                   let firstArtist = items.first,
                   let profile = firstArtist["profile"] as? [String: Any],
                   let artistNameValue = profile["name"] as? String {
                    artistName = artistNameValue
                }
                
                // Extract duration
                var durationMs = 0
                if let duration = trackData["duration"] as? [String: Any],
                   let totalMs = duration["totalMilliseconds"] as? Int {
                    durationMs = totalMs
                }
                
                // Extract Spotify ID
                var spotifyID: String?
                if let uri = trackData["uri"] as? String {
                    spotifyID = uri.replacingOccurrences(of: "spotify:track:", with: "")
                }
                
                let track = TrackData(
                    title: trackName,
                    artist: artistName,
                    album: name,
                    durationMs: durationMs,
                    albumArtURL: coverArtURL,
                    spotifyID: spotifyID
                )
                
                tracks.append(track)
            }
        }
        
        print("✅ Extracted \(tracks.count) tracks from album")
        
        return PlaylistData(
            id: albumID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
    
    /// Fallback: Use Spotify Web API with Client Credentials flow
    /// This requires a Spotify Developer App (client ID + secret)
    func parsePlaylistViaAPI(playlistID: String, clientID: String, clientSecret: String) async throws -> PlaylistData {
        // Step 1: Get access token
        let token = try await getAccessToken(clientID: clientID, clientSecret: clientSecret)
        
        // Step 2: Fetch playlist data
        let playlistData = try await fetchPlaylistFromAPI(playlistID: playlistID, token: token)
        
        return playlistData
    }
    
    private func getAccessToken(clientID: String, clientSecret: String) async throws -> String {
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientID):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=client_credentials"
        request.httpBody = body.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct TokenResponse: Codable {
            let access_token: String
        }
        
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return response.access_token
    }
    
    private func fetchPlaylistFromAPI(playlistID: String, token: String) async throws -> PlaylistData {
        let playlistURL = URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)")!
        var request = URLRequest(url: playlistURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse the JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else { throw SpotifyError.parsingError }
        
        // Extract playlist info
        let name = json["name"] as? String ?? "Unknown Playlist"
        let images = json["images"] as? [[String: Any]]
        let coverArtURL = images?.first?["url"] as? String
        
        // Extract tracks
        guard let tracksContainer = json["tracks"] as? [String: Any],
              let tracksArray = tracksContainer["items"] as? [[String: Any]] else {
            throw SpotifyError.parsingError
        }
        
        let tracks = tracksArray.compactMap { item -> TrackData? in
            guard let track = item["track"] as? [String: Any] else { return nil }
            
            let title = track["name"] as? String ?? "Unknown"
            let artists = track["artists"] as? [[String: Any]]
            let artist = artists?.first?["name"] as? String ?? "Unknown Artist"
            let albumData = track["album"] as? [String: Any]
            let album = albumData?["name"] as? String ?? ""
            let durationMs = track["duration_ms"] as? Int ?? 0
            let albumImages = albumData?["images"] as? [[String: Any]]
            let albumArtURL = albumImages?.first?["url"] as? String
            let spotifyID = track["id"] as? String
            
            return TrackData(
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                albumArtURL: albumArtURL,
                spotifyID: spotifyID
            )
        }
        
        return PlaylistData(
            id: playlistID,
            name: name,
            coverArtURL: coverArtURL,
            tracks: tracks
        )
    }
}
