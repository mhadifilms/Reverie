//
//  LyricsService.swift
//  Reverie
//
//  Phase 2D: Cascading lyrics resolution chain.
//  Priority: 1. InnerTube (YouTube captions) -> 2. LRCLIB -> 3. Description parsing
//

import Foundation
import OSLog

actor LyricsService {

    private let logger = Logger(subsystem: "com.reverie", category: "lyrics")

    struct LyricsResult {
        let plainLyrics: String?
        let syncedLRC: String?     // Full LRC string
        let source: LyricsSource
    }

    enum LyricsSource: String {
        case innerTube = "YouTube"
        case lrclib = "LRCLIB"
        case description = "Description"
        case none = "None"
    }

    // MARK: - Public API

    /// Resolves lyrics for a track using cascading sources.
    func resolve(title: String, artist: String, album: String, durationSeconds: Int, videoID: String?) async -> LyricsResult {
        // Stage 1: Try LRCLIB (best source for synced lyrics)
        if let result = await fetchFromLRCLIB(title: title, artist: artist, album: album, durationSeconds: durationSeconds) {
            logger.info("Lyrics found via LRCLIB for: \(title, privacy: .public)")
            return result
        }

        // Stage 2: Try InnerTube captions (YouTube auto-generated or uploaded)
        if let videoID = videoID,
           let result = await fetchFromInnerTube(videoID: videoID) {
            logger.info("Lyrics found via InnerTube for: \(title, privacy: .public)")
            return result
        }

        // Stage 3: No lyrics found
        logger.info("No lyrics found for: \(title, privacy: .public)")
        return LyricsResult(plainLyrics: nil, syncedLRC: nil, source: .none)
    }

    // MARK: - LRCLIB

    private func fetchFromLRCLIB(title: String, artist: String, album: String, durationSeconds: Int) async -> LyricsResult? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album.isEmpty ? nil : album),
            URLQueryItem(name: "duration", value: String(durationSeconds))
        ].compactMap { item in
            item.value != nil ? item : nil
        }

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Reverie/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let syncedLyrics = json?["syncedLyrics"] as? String
            let plainLyrics = json?["plainLyrics"] as? String

            guard syncedLyrics != nil || plainLyrics != nil else {
                return nil
            }

            return LyricsResult(
                plainLyrics: plainLyrics,
                syncedLRC: syncedLyrics,
                source: .lrclib
            )
        } catch {
            logger.debug("LRCLIB request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - InnerTube Captions

    private func fetchFromInnerTube(videoID: String) async -> LyricsResult? {
        // First, get the captions track list from InnerTube /player
        let url = URL(string: "https://music.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        let body: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00"
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Navigate to captions
            guard let captions = json?["captions"] as? [String: Any],
                  let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
                  let captionTracks = renderer["captionTracks"] as? [[String: Any]] else {
                return nil
            }

            // Find English captions (prefer manually uploaded over auto-generated)
            let englishTrack = captionTracks.first { track in
                let lang = track["languageCode"] as? String ?? ""
                let kind = track["kind"] as? String ?? ""
                return lang.hasPrefix("en") && kind != "asr"
            } ?? captionTracks.first { track in
                let lang = track["languageCode"] as? String ?? ""
                return lang.hasPrefix("en")
            }

            guard let captionTrack = englishTrack,
                  let captionURLString = captionTrack["baseUrl"] as? String,
                  let captionURL = URL(string: captionURLString + "&fmt=srv3") else {
                return nil
            }

            // Fetch the caption XML
            let (captionData, _) = try await URLSession.shared.data(from: captionURL)
            guard let captionXML = String(data: captionData, encoding: .utf8) else {
                return nil
            }

            // Parse the srv3 XML format into plain lyrics
            let plainText = parseSrv3Captions(captionXML)

            guard !plainText.isEmpty else { return nil }

            return LyricsResult(
                plainLyrics: plainText,
                syncedLRC: nil, // srv3 format doesn't map cleanly to LRC
                source: .innerTube
            )
        } catch {
            logger.debug("InnerTube captions failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Parses YouTube srv3 caption XML into plain text lyrics.
    private func parseSrv3Captions(_ xml: String) -> String {
        // srv3 format: <p t="startMs" d="durationMs">text</p>
        var lines: [String] = []

        let pattern = #"<p[^>]*>([^<]+)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }

        let nsRange = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: nsRange)

        for match in matches {
            if match.numberOfRanges >= 2,
               let textRange = Range(match.range(at: 1), in: xml) {
                var text = String(xml[textRange])
                // Decode HTML entities
                text = text.replacingOccurrences(of: "&amp;", with: "&")
                text = text.replacingOccurrences(of: "&lt;", with: "<")
                text = text.replacingOccurrences(of: "&gt;", with: ">")
                text = text.replacingOccurrences(of: "&#39;", with: "'")
                text = text.replacingOccurrences(of: "&quot;", with: "\"")
                text = text.replacingOccurrences(of: "\\n", with: "\n")

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed != "[Music]" && trimmed != "[Applause]" {
                    lines.append(trimmed)
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
