//
//  MetadataResolverTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for MetadataResolver
//  Tests date parsing logic and credit extraction via fixture data.
//  Network-dependent methods are not tested here.
//

import Testing
import Foundation
@testable import Reverie

struct MetadataResolverTests {

    // MARK: - Flexible Date Parsing
    //
    // MetadataResolver.parseFlexibleDate is private, so we test the same logic
    // by replicating the parsing approach used in the resolver. This validates
    // the date format patterns without needing to expose private methods.

    /// Mirrors MetadataResolver's parseFlexibleDate logic for testability.
    private func parseFlexibleDate(_ dateString: String) -> Date? {
        let formatters: [String] = ["yyyy-MM-dd", "yyyy-MM", "yyyy"]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        return isoFormatter.date(from: dateString)
    }

    @Test func parseFullDate() {
        let date = parseFlexibleDate("2024-01-15")
        #expect(date != nil)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2024)
        #expect(components.month == 1)
        #expect(components.day == 15)
    }

    @Test func parseYearMonth() {
        let date = parseFlexibleDate("2023-06")
        #expect(date != nil)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: date!)
        #expect(components.year == 2023)
        #expect(components.month == 6)
    }

    @Test func parseYearOnly() {
        let date = parseFlexibleDate("2020")
        #expect(date != nil)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year], from: date!)
        #expect(components.year == 2020)
    }

    @Test func parseISO8601Date() {
        let date = parseFlexibleDate("2024-03-20")
        #expect(date != nil)
    }

    @Test func parseInvalidDate() {
        #expect(parseFlexibleDate("not a date") == nil)
        #expect(parseFlexibleDate("") == nil)
        #expect(parseFlexibleDate("2024/01/15") == nil)
    }

    // MARK: - Credit Extraction
    //
    // MetadataResolver.extractCredits is private, so we replicate the logic here.

    /// Mirrors MetadataResolver's extractCredits logic for testability.
    private func extractCredits(from description: String) -> String? {
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

    @Test func extractCreditsFromDescription() {
        let description = """
        Official music video for "Test Song"

        Produced by Max Martin
        Written by Test Artist
        Mixed by Serban Ghenea

        (C) 2024 Record Label
        """

        let credits = extractCredits(from: description)
        #expect(credits != nil)
        #expect(credits!.contains("Produced by Max Martin"))
        #expect(credits!.contains("Written by Test Artist"))
        #expect(credits!.contains("Mixed by Serban Ghenea"))
    }

    @Test func extractCreditsWithFeaturing() {
        let description = """
        Song Title
        Featuring Nicki Minaj
        Produced by Metro Boomin
        """

        let credits = extractCredits(from: description)
        #expect(credits != nil)
        #expect(credits!.contains("Featuring Nicki Minaj"))
        #expect(credits!.contains("Produced by Metro Boomin"))
    }

    @Test func extractCreditsWithFeat() {
        let description = "Some Song (feat. Drake)\nLyrics by Songwriter"

        let credits = extractCredits(from: description)
        #expect(credits != nil)
        #expect(credits!.contains("feat. Drake"))
        #expect(credits!.contains("Lyrics by Songwriter"))
    }

    @Test func extractCreditsCaseInsensitive() {
        let description = """
        PRODUCED BY Big Producer
        written by Someone
        MASTERED BY Engineer
        """

        let credits = extractCredits(from: description)
        #expect(credits != nil)
        #expect(credits!.contains("PRODUCED BY Big Producer"))
        #expect(credits!.contains("written by Someone"))
        #expect(credits!.contains("MASTERED BY Engineer"))
    }

    @Test func extractCreditsReturnsNilWhenNone() {
        let description = """
        Official music video
        Subscribe for more videos
        Follow on Instagram
        """

        let credits = extractCredits(from: description)
        #expect(credits == nil)
    }

    @Test func extractCreditsFromEmptyString() {
        #expect(extractCredits(from: "") == nil)
    }

    @Test func extractCreditsAllPatterns() {
        let description = """
        Produced by A
        Written by B
        Composed by C
        Lyrics by D
        Mixed by E
        Mastered by F
        """

        let credits = extractCredits(from: description)
        #expect(credits != nil)
        let lines = credits!.components(separatedBy: "\n")
        #expect(lines.count == 6)
    }

    // MARK: - MetadataError

    @Test func metadataErrorDescriptions() {
        let invalidResponse = MetadataResolver.MetadataError.invalidResponse
        #expect(invalidResponse.errorDescription == "Invalid response from YouTube")

        let parsingFailed = MetadataResolver.MetadataError.parsingFailed
        #expect(parsingFailed.errorDescription == "Failed to parse metadata")
    }

    // MARK: - PlayerResponse Decoding

    @Test func decodeMinimalPlayerResponse() throws {
        let json = """
        {
            "videoDetails": {
                "videoId": "abc123",
                "title": "Test Song",
                "lengthSeconds": "240",
                "channelId": "UCxyz",
                "shortDescription": "A test song",
                "author": "Test Channel"
            },
            "microformat": {
                "playerMicroformatRenderer": {
                    "category": "Music",
                    "publishDate": "2024-01-15",
                    "ownerChannelName": "Test Channel"
                }
            }
        }
        """.data(using: .utf8)!

        // Decode using the same structure MetadataResolver uses internally.
        // We define a mirror struct here since PlayerResponse is private.
        struct TestPlayerResponse: Decodable {
            let videoDetails: TestVideoDetails?
            let microformat: TestMicroformat?
        }
        struct TestVideoDetails: Decodable {
            let videoId: String?
            let title: String?
            let lengthSeconds: String?
            let channelId: String?
            let shortDescription: String?
            let author: String?
        }
        struct TestMicroformat: Decodable {
            let playerMicroformatRenderer: TestMicroformatRenderer?
        }
        struct TestMicroformatRenderer: Decodable {
            let category: String?
            let publishDate: String?
            let ownerChannelName: String?
        }

        let response = try JSONDecoder().decode(TestPlayerResponse.self, from: json)
        #expect(response.videoDetails?.videoId == "abc123")
        #expect(response.videoDetails?.title == "Test Song")
        #expect(response.videoDetails?.lengthSeconds == "240")
        #expect(response.videoDetails?.channelId == "UCxyz")
        #expect(response.videoDetails?.shortDescription == "A test song")
        #expect(response.microformat?.playerMicroformatRenderer?.category == "Music")
        #expect(response.microformat?.playerMicroformatRenderer?.publishDate == "2024-01-15")
    }

    @Test func decodeEmptyPlayerResponse() throws {
        let json = "{}".data(using: .utf8)!

        struct TestPlayerResponse: Decodable {
            let videoDetails: TestVideoDetails?
            let microformat: TestMicroformat?
        }
        struct TestVideoDetails: Decodable { let videoId: String? }
        struct TestMicroformat: Decodable { let playerMicroformatRenderer: TestRenderer? }
        struct TestRenderer: Decodable { let category: String? }

        let response = try JSONDecoder().decode(TestPlayerResponse.self, from: json)
        #expect(response.videoDetails == nil)
        #expect(response.microformat == nil)
    }

    // MARK: - MusicBrainz Response Decoding

    @Test func decodeMusicBrainzRecordingSearch() throws {
        let json = """
        {
            "recordings": [
                {
                    "id": "mb-id-123",
                    "title": "Test Song",
                    "releases": [
                        {
                            "id": "release-1",
                            "title": "Test Album",
                            "date": "2023-06-15"
                        }
                    ],
                    "tags": [
                        {"name": "rock", "count": 5},
                        {"name": "alternative", "count": 3}
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        struct TestMBSearch: Decodable {
            let recordings: [TestMBRecording]?
        }
        struct TestMBRecording: Decodable {
            let id: String
            let title: String?
            let releases: [TestMBRelease]?
            let tags: [TestMBTag]?
        }
        struct TestMBRelease: Decodable {
            let id: String
            let title: String?
            let date: String?
        }
        struct TestMBTag: Decodable {
            let name: String?
            let count: Int?
        }

        let result = try JSONDecoder().decode(TestMBSearch.self, from: json)
        #expect(result.recordings?.count == 1)

        let recording = result.recordings![0]
        #expect(recording.id == "mb-id-123")
        #expect(recording.title == "Test Song")
        #expect(recording.releases?.first?.title == "Test Album")
        #expect(recording.releases?.first?.date == "2023-06-15")

        // Top tag by count should be "rock"
        let topTag = recording.tags?.max(by: { ($0.count ?? 0) < ($1.count ?? 0) })
        #expect(topTag?.name == "rock")
        #expect(topTag?.count == 5)
    }
}
