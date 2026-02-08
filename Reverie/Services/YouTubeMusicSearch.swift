//
//  YouTubeMusicSearch.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import Foundation

/// YouTube Music InnerTube API search service
actor YouTubeMusicSearch {
    
    struct SearchResult: Identifiable {
        let id: String
        let videoID: String
        let title: String
        let artist: String
        let album: String?
        let thumbnailURL: URL?
        let durationSeconds: Int
        
        var formattedDuration: String {
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    enum SearchError: LocalizedError {
        case networkError(Error)
        case invalidResponse
        case parsingFailed
        
        var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from YouTube Music"
            case .parsingFailed:
                return "Failed to parse search results"
            }
        }
    }
    
    /// Searches YouTube Music using InnerTube API
    func search(query: String, limit: Int = 20) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        print("🔍 Searching for: \(query)")
        
        let url = URL(string: "https://music.youtube.com/youtubei/v1/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        let body: [String: Any] = [
            "query": query,
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00"
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("📡 Making request to YouTube Music...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Got response: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    throw SearchError.invalidResponse
                }
            }
            
            print("📦 Data size: \(data.count) bytes")
            
            return try parseSearchResults(from: data, limit: limit)
        } catch let error as URLError {
            print("❌ Network error: \(error.code.rawValue) - \(error.localizedDescription)")
            throw SearchError.networkError(error)
        } catch {
            print("❌ Error: \(error)")
            throw error
        }
    }
    
    /// Parses raw data into search results
    private func parseSearchResults(from data: Data, limit: Int) throws -> [SearchResult] {
        
        // Parse the response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SearchError.invalidResponse
        }
        
        return try parseSearchResults(from: json, limit: limit)
    }
    
    /// Parses InnerTube search response into SearchResult objects
    private func parseSearchResults(from json: [String: Any], limit: Int) throws -> [SearchResult] {
        var results: [SearchResult] = []
        
        // Navigate the nested structure
        guard let contents = json["contents"] as? [String: Any],
              let tabbedSearchResults = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbedSearchResults["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let content = tabRenderer["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            throw SearchError.parsingFailed
        }
        
        // Find the music shelf with results
        for section in sectionContents {
            if let musicShelf = section["musicShelfRenderer"] as? [String: Any],
               let items = musicShelf["contents"] as? [[String: Any]] {
                
                for item in items.prefix(limit) {
                    if let result = parseSearchResultItem(item) {
                        results.append(result)
                    }
                }
                
                if results.count >= limit {
                    break
                }
            }
        }
        
        return results
    }
    
    /// Parses a single search result item
    private func parseSearchResultItem(_ item: [String: Any]) -> SearchResult? {
        guard let musicItem = item["musicResponsiveListItemRenderer"] as? [String: Any] else {
            return nil
        }
        
        // Extract video ID
        guard let playlistItemData = musicItem["playlistItemData"] as? [String: Any],
              let videoID = playlistItemData["videoId"] as? String else {
            return nil
        }
        
        // Extract flex columns (title, artist, album)
        guard let flexColumns = musicItem["flexColumns"] as? [[String: Any]] else {
            return nil
        }
        
        var title = ""
        var artist = ""
        var album: String?
        
        // First column is usually the title
        if flexColumns.count > 0,
           let column = flexColumns[0]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let text = column["text"] as? [String: Any],
           let runs = text["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let titleText = firstRun["text"] as? String {
            title = titleText
        }
        
        // Second column contains artist, album, and other metadata
        if flexColumns.count > 1,
           let column = flexColumns[1]["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
           let text = column["text"] as? [String: Any],
           let runs = text["runs"] as? [[String: Any]] {
            
            // Extract artist (usually first item)
            if runs.count > 0, let artistText = runs[0]["text"] as? String {
                artist = artistText
            }
            
            // Extract album (usually third item, separated by " • ")
            if runs.count > 2, let albumText = runs[2]["text"] as? String {
                album = albumText
            }
        }
        
        // Extract thumbnail
        var thumbnailURL: URL?
        if let thumbnail = musicItem["thumbnail"] as? [String: Any],
           let musicThumbnail = thumbnail["musicThumbnailRenderer"] as? [String: Any],
           let thumbnailData = musicThumbnail["thumbnail"] as? [String: Any],
           let thumbnails = thumbnailData["thumbnails"] as? [[String: Any]],
           let lastThumbnail = thumbnails.last,
           let urlString = lastThumbnail["url"] as? String {
            thumbnailURL = URL(string: urlString)
        }
        
        // Extract duration
        var durationSeconds = 0
        if let fixedColumns = musicItem["fixedColumns"] as? [[String: Any]],
           let firstFixed = fixedColumns.first,
           let column = firstFixed["musicResponsiveListItemFixedColumnRenderer"] as? [String: Any],
           let text = column["text"] as? [String: Any],
           let runs = text["runs"] as? [[String: Any]],
           let firstRun = runs.first,
           let durationText = firstRun["text"] as? String {
            durationSeconds = parseDuration(durationText)
        }
        
        return SearchResult(
            id: videoID,
            videoID: videoID,
            title: title,
            artist: artist,
            album: album,
            thumbnailURL: thumbnailURL,
            durationSeconds: durationSeconds
        )
    }
    
    /// Parses duration string like "3:45" into seconds
    private func parseDuration(_ duration: String) -> Int {
        let components = duration.split(separator: ":").compactMap { Int($0) }
        
        if components.count == 2 {
            // MM:SS
            return components[0] * 60 + components[1]
        } else if components.count == 3 {
            // HH:MM:SS
            return components[0] * 3600 + components[1] * 60 + components[2]
        }
        
        return 0
    }
}
