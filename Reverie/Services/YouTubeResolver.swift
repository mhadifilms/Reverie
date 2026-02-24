//
//  YouTubeResolver.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//
// NOTE: This service requires YouTubeKit to be added as a Swift Package dependency.
// See SETUP.md for instructions on adding YouTubeKit.

import Foundation

// Conditional import - will use YouTubeKit if available
#if canImport(YouTubeKit)
import YouTubeKit
#endif

/// Quality tier for audio downloads
enum AudioQualityTier: String, Codable, CaseIterable, Identifiable {
    case high   // 256kbps AAC (itag 141)
    case medium // 128kbps AAC (itag 140) - DEFAULT
    case low    // 48-64kbps AAC (itag 139)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "High (256 kbps)"
        case .medium: return "Medium (128 kbps)"
        case .low: return "Low (64 kbps)"
        }
    }

    var approximateBitrate: Int {
        switch self {
        case .high: return 256
        case .medium: return 128
        case .low: return 64
        }
    }

    /// Returns the current user-selected quality tier
    static var current: AudioQualityTier {
        let raw = UserDefaults.standard.string(forKey: "downloadQuality") ?? "medium"
        return AudioQualityTier(rawValue: raw) ?? .medium
    }
}

/// Resolves YouTube audio streams for music tracks
actor YouTubeResolver {

    struct SearchResult {
        let videoID: String
        let title: String
    }

    struct ResolvedAudio {
        let videoID: String
        let videoTitle: String
        let audioURL: URL
        let fileExtension: String
        let bitrate: Int
        let durationSeconds: Int
    }

    enum YouTubeError: LocalizedError {
        case searchFailed
        case noResultsFound
        case extractionFailed
        case networkError(Error)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .searchFailed:
                return "Failed to search YouTube"
            case .noResultsFound:
                return "No matching videos found"
            case .extractionFailed:
                return "Failed to extract audio stream"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from YouTube"
            }
        }
    }

    /// Resolves audio URL for a specific YouTube video ID at the given quality tier
    func resolveAudioURL(videoID: String, quality: AudioQualityTier = .current) async throws -> ResolvedAudio {
        return try await extractAudioStream(videoID: videoID, quality: quality)
    }
    
    /// Searches YouTube for a track and resolves the best audio stream
    func resolveAudioURL(title: String, artist: String) async throws -> ResolvedAudio {
        // Step 1: Search YouTube for the track
        let query = "\(title) \(artist) audio"
        let videoID = try await searchYouTube(query: query)
        
        // Step 2: Extract audio stream URL
        let audioData = try await extractAudioStream(videoID: videoID)
        
        return audioData
    }
    
    /// Searches YouTube and returns video information
    func searchYouTube(query: String, limit: Int = 5) async throws -> [SearchResult] {
        #if canImport(YouTubeKit)
        // For now, return empty since YouTubeKit doesn't have built-in search
        // We'll use a simple HTML scraping approach
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = URL(string: "https://www.youtube.com/results?search_query=\(encodedQuery)")!
        
        let (data, _) = try await URLSession.shared.data(from: searchURL)
        let html = String(data: data, encoding: .utf8) ?? ""
        
        // Extract video IDs and titles from search results
        var results: [SearchResult] = []
        let pattern = #"\"videoId\":\"([^\"]{11})\".*?\"title\":\{\"runs\":\[\{\"text\":\"([^\"]+)\""#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches.prefix(limit) {
                if match.numberOfRanges == 3,
                   let videoIDRange = Range(match.range(at: 1), in: html),
                   let titleRange = Range(match.range(at: 2), in: html) {
                    let videoID = String(html[videoIDRange])
                    let title = String(html[titleRange])
                        .replacingOccurrences(of: "\\\\u0026", with: "&")
                        .replacingOccurrences(of: "\\", with: "")
                    results.append(SearchResult(videoID: videoID, title: title))
                }
            }
        }
        
        guard !results.isEmpty else {
            throw YouTubeError.noResultsFound
        }
        
        return results
        #else
        throw YouTubeError.searchFailed
        #endif
    }
    
    /// Searches YouTube and returns the first matching video ID
    private func searchYouTube(query: String) async throws -> String {
        let results = try await searchYouTube(query: query, limit: 1)
        guard let first = results.first else {
            throw YouTubeError.noResultsFound
        }
        return first.videoID
    }
    
    /// Extracts the first video ID from YouTube search results HTML (fallback only)
    private func extractFirstVideoID(from html: String) -> String? {
        guard let range = html.range(of: "\"videoId\":\"") else { return nil }
        let start = range.upperBound
        let substring = html[start...]
        guard let endRange = substring.range(of: "\"") else { return nil }
        let videoID = String(substring[start..<endRange.lowerBound])
        guard videoID.count == 11 else { return nil }
        return videoID
    }
    
    /// Extracts audio stream URL for a video at the requested quality tier
    private func extractAudioStream(videoID: String, quality: AudioQualityTier = .medium) async throws -> ResolvedAudio {
        #if canImport(YouTubeKit)
        // Use YouTubeKit with both local and remote fallback
        let youtube = try await YouTube(videoID: videoID, methods: [.local, .remote])

        // Get all available streams
        let streams = try await youtube.streams

        // Filter for audio-only M4A streams
        let audioStreams = streams.filter { stream in
            stream.includesAudioTrack && !stream.includesVideoTrack && stream.fileExtension == .m4a
        }

        guard !audioStreams.isEmpty else {
            throw YouTubeError.extractionFailed
        }

        // Select stream closest to the desired quality bitrate
        let targetBps = quality.approximateBitrate * 1000
        let selectedStream = audioStreams.min(by: {
            abs(($0.bitrate ?? 0) - targetBps) < abs(($1.bitrate ?? 0) - targetBps)
        }) ?? audioStreams[0]

        // Get the stream URL
        let streamURL = selectedStream.url

        // Extract video metadata
        let metadata = try await youtube.metadata
        let videoTitle = metadata?.title ?? "Unknown"

        let durationSeconds = 0

        return ResolvedAudio(
            videoID: videoID,
            videoTitle: videoTitle,
            audioURL: streamURL,
            fileExtension: "m4a",
            bitrate: (selectedStream.bitrate ?? 128000) / 1000,
            durationSeconds: durationSeconds
        )
        #else
        // Fallback: Basic extraction (will fail for most videos due to cipher)
        let videoURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
        let (data, _) = try await URLSession.shared.data(from: videoURL)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw YouTubeError.extractionFailed
        }
        
        // Extract video title
        var videoTitle = "Unknown"
        if let titleRange = html.range(of: "\"title\":\""),
           let titleEnd = html.range(of: "\"", range: titleRange.upperBound..<html.endIndex) {
            videoTitle = String(html[titleRange.upperBound..<titleEnd.lowerBound])
                .replacingOccurrences(of: "\\u0026", with: "&")
                .replacingOccurrences(of: "\\", with: "")
        }
        
        // Extract duration
        var durationSeconds = 0
        if let durationRange = html.range(of: "\"lengthSeconds\":\""),
           let durationEnd = html.range(of: "\"", range: durationRange.upperBound..<html.endIndex) {
            let durationString = String(html[durationRange.upperBound..<durationEnd.lowerBound])
            durationSeconds = Int(durationString) ?? 0
        }
        
        // Try to extract streaming data (will likely fail without cipher)
        guard let playerResponseStart = html.range(of: "var ytInitialPlayerResponse = "),
              let playerResponseEnd = html.range(of: ";</script>", range: playerResponseStart.upperBound..<html.endIndex) else {
            throw YouTubeError.extractionFailed
        }
        
        let playerResponseString = String(html[playerResponseStart.upperBound..<playerResponseEnd.lowerBound])
        guard let playerResponseData = playerResponseString.data(using: .utf8),
              let playerResponse = try? JSONSerialization.jsonObject(with: playerResponseData) as? [String: Any],
              let streamingData = playerResponse["streamingData"] as? [String: Any],
              let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] else {
            throw YouTubeError.extractionFailed
        }
        
        // Filter for audio-only streams with direct URLs (rare)
        let audioStreams = adaptiveFormats.filter { format in
            guard let mimeType = format["mimeType"] as? String,
                  format["url"] != nil else { return false }
            return mimeType.contains("audio") && mimeType.contains("mp4")
        }
        
        guard let bestAudio = audioStreams.max(by: { stream1, stream2 in
            let bitrate1 = stream1["bitrate"] as? Int ?? 0
            let bitrate2 = stream2["bitrate"] as? Int ?? 0
            return bitrate1 < bitrate2
        }),
              let audioURLString = bestAudio["url"] as? String,
              let audioURL = URL(string: audioURLString) else {
            throw YouTubeError.extractionFailed
        }
        
        let bitrate = (bestAudio["bitrate"] as? Int ?? 128000) / 1000
        
        return ResolvedAudio(
            videoID: videoID,
            videoTitle: videoTitle,
            audioURL: audioURL,
            fileExtension: "m4a",
            bitrate: bitrate,
            durationSeconds: durationSeconds
        )
        #endif
    }
    
}
