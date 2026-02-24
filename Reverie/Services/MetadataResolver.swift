//
//  MetadataResolver.swift
//  Reverie
//
//  Phase 2B: 4-stage metadata resolution pipeline
//  Stage 1: Search-time (title, artist, album, thumbnail) — already handled by YouTubeMusicSearch
//  Stage 2: Download-time — fetch full video details via InnerTube /player, parse description/channel
//  Stage 3: Background enrichment — fill incomplete records
//  Stage 4: Optional MusicBrainz lookup
//

import Foundation
import SwiftData
import OSLog

actor MetadataResolver {

    private let logger = Logger(subsystem: "com.reverie", category: "metadata")

    // MARK: - InnerTube Player Response Types

    private struct PlayerResponse: Decodable {
        let videoDetails: VideoDetails?
        let microformat: Microformat?
    }

    private struct VideoDetails: Decodable {
        let videoId: String?
        let title: String?
        let lengthSeconds: String?
        let channelId: String?
        let shortDescription: String?
        let author: String?
    }

    private struct Microformat: Decodable {
        let playerMicroformatRenderer: MicroformatRenderer?
    }

    private struct MicroformatRenderer: Decodable {
        let category: String?
        let publishDate: String?
        let description: MicroformatText?
        let ownerChannelName: String?
    }

    private struct MicroformatText: Decodable {
        let simpleText: String?
    }

    // MARK: - MusicBrainz Types

    private struct MBRecordingSearch: Decodable {
        let recordings: [MBRecording]?
    }

    private struct MBRecording: Decodable {
        let id: String
        let title: String?
        let releases: [MBRelease]?
        let tags: [MBTag]?
    }

    private struct MBRelease: Decodable {
        let id: String
        let title: String?
        let date: String?
    }

    private struct MBTag: Decodable {
        let name: String?
        let count: Int?
    }

    // MARK: - Stage 2: Download-Time Enrichment

    /// Fetches full video details from InnerTube /player endpoint and enriches the track.
    /// Call this after download completes, passing a MainActor-isolated track.
    @MainActor
    func enrichOnDownload(track: ReverieTrack, modelContext: ModelContext) async {
        guard let videoID = track.youtubeVideoID else { return }

        do {
            let details = try await fetchPlayerDetails(videoID: videoID)
            applyPlayerDetails(details, to: track)

            // Create or link artist relation
            if track.artistRelation == nil {
                let channelID = details.videoDetails?.channelId
                let artistName = track.artist
                linkOrCreateArtist(
                    name: artistName,
                    channelID: channelID,
                    track: track,
                    modelContext: modelContext
                )
            }

            try? modelContext.save()
            logger.info("Stage 2 enrichment complete for: \(track.title, privacy: .public)")
        } catch {
            logger.error("Stage 2 enrichment failed for \(track.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Stage 3: Background Enrichment

    /// Scans for tracks with incomplete metadata and enriches them.
    @MainActor
    func enrichIncompleteRecords(modelContext: ModelContext, limit: Int = 20) async {
        let downloaded = DownloadState.downloaded
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate<ReverieTrack> { track in
                track.downloadState == downloaded && track.trackDescription == nil
            },
            sortBy: [SortDescriptor(\ReverieTrack.downloadDate, order: .reverse)]
        )

        guard let tracks = try? modelContext.fetch(descriptor) else { return }

        for track in tracks.prefix(limit) {
            await enrichOnDownload(track: track, modelContext: modelContext)
            // Rate-limit to avoid hammering InnerTube
            try? await Task.sleep(for: .milliseconds(500))
        }

        logger.info("Stage 3 background enrichment pass complete")
    }

    // MARK: - Stage 4: MusicBrainz Lookup

    /// Optional MusicBrainz lookup for genre, release date, and MusicBrainz ID.
    @MainActor
    func enrichViaMusicBrainz(track: ReverieTrack, modelContext: ModelContext) async {
        guard track.musicBrainzID == nil else { return }

        let query = "\(track.title) AND artist:\(track.artist)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let url = URL(string: "https://musicbrainz.org/ws/2/recording?query=\(query)&fmt=json&limit=1") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue(Constants.musicBrainzUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let result = try JSONDecoder().decode(MBRecordingSearch.self, from: data)

            if let recording = result.recordings?.first {
                track.musicBrainzID = recording.id

                // Extract genre from tags (highest count)
                if track.genre == nil,
                   let topTag = recording.tags?.max(by: { ($0.count ?? 0) < ($1.count ?? 0) }),
                   let tagName = topTag.name {
                    track.genre = tagName.capitalized
                }

                // Extract release date from first release
                if track.releaseDate == nil,
                   let release = recording.releases?.first,
                   let dateString = release.date {
                    track.releaseDate = parseFlexibleDate(dateString)
                }

                try? modelContext.save()
                logger.info("Stage 4 MusicBrainz enrichment complete for: \(track.title, privacy: .public)")
            }
        } catch {
            logger.error("MusicBrainz lookup failed for \(track.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - InnerTube /player Fetch

    private func fetchPlayerDetails(videoID: String) async throws -> PlayerResponse {
        let url = URL(string: "https://music.youtube.com/youtubei/v1/player")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "videoId": videoID,
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00"
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MetadataError.invalidResponse
        }

        return try JSONDecoder().decode(PlayerResponse.self, from: data)
    }

    // MARK: - Apply Player Details

    @MainActor
    private func applyPlayerDetails(_ details: PlayerResponse, to track: ReverieTrack) {
        // Description
        if track.trackDescription == nil {
            track.trackDescription = details.videoDetails?.shortDescription
        }

        // Duration (if missing)
        if track.durationSeconds == 0,
           let lengthStr = details.videoDetails?.lengthSeconds,
           let length = Int(lengthStr) {
            track.durationSeconds = length
        }

        // Release date from microformat
        if track.releaseDate == nil,
           let dateStr = details.microformat?.playerMicroformatRenderer?.publishDate {
            track.releaseDate = parseFlexibleDate(dateStr)
        }

        // Genre from microformat category
        if track.genre == nil,
           let category = details.microformat?.playerMicroformatRenderer?.category,
           category != "Music" {
            // "Music" is too generic, but keep more specific categories
            track.genre = category
        }

        // Parse credits from description
        if track.credits == nil, let description = details.videoDetails?.shortDescription {
            track.credits = extractCredits(from: description)
        }
    }

    // MARK: - Artist Linking

    @MainActor
    private func linkOrCreateArtist(
        name: String,
        channelID: String?,
        track: ReverieTrack,
        modelContext: ModelContext
    ) {
        // Try to find existing artist by name
        let descriptor = FetchDescriptor<ReverieArtist>(
            predicate: #Predicate<ReverieArtist> { artist in
                artist.name == name
            }
        )

        if let existingArtists = try? modelContext.fetch(descriptor),
           let existing = existingArtists.first {
            track.artistRelation = existing
            // Update channelID if we didn't have one
            if existing.channelID == nil, let channelID = channelID {
                existing.channelID = channelID
            }
        } else {
            // Create new artist
            let newArtist = ReverieArtist(name: name, channelID: channelID)
            modelContext.insert(newArtist)
            track.artistRelation = newArtist
        }
    }

    // MARK: - Helpers

    nonisolated private func parseFlexibleDate(_ dateString: String) -> Date? {
        // Handle "2024-01-15", "2024-01", "2024"
        let formatters: [String] = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        // Try ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        return isoFormatter.date(from: dateString)
    }

    nonisolated private func extractCredits(from description: String) -> String? {
        // Look for common credit patterns in YouTube music descriptions
        let creditPatterns = [
            "Produced by", "Written by", "Composed by", "Lyrics by",
            "Mixed by", "Mastered by", "Featuring", "feat."
        ]

        var creditLines: [String] = []
        let lines = description.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if creditPatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                creditLines.append(trimmed)
            }
        }

        return creditLines.isEmpty ? nil : creditLines.joined(separator: "\n")
    }

    // MARK: - Errors

    enum MetadataError: LocalizedError {
        case invalidResponse
        case parsingFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from YouTube"
            case .parsingFailed: return "Failed to parse metadata"
            }
        }
    }
}
