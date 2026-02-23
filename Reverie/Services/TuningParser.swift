//
//  TuningParser.swift
//  Reverie
//
//  Parses natural language tuning prompts into structured filters.
//  Rule-based — no LLM dependency. All processing is local.
//

import Foundation

struct TuningParser {

    // MARK: - Keyword Dictionaries

    private static let genres: Set<String> = [
        "pop", "rock", "hip hop", "hip-hop", "rap", "r&b", "rnb",
        "jazz", "classical", "electronic", "edm", "house", "techno",
        "country", "folk", "indie", "alternative", "metal", "punk",
        "soul", "funk", "blues", "reggae", "latin", "k-pop", "kpop",
        "lo-fi", "lofi", "ambient", "drum and bass", "dnb",
        "trap", "gospel", "disco", "grunge", "ska", "afrobeats",
        "bossa nova", "dancehall", "dubstep", "shoegaze", "synthwave",
        "phonk", "drill", "grime", "garage", "trance", "hardcore",
        "math rock", "post-punk", "emo", "bedroom pop", "city pop"
    ]

    private static let moods: Set<String> = [
        "chill", "relaxing", "calm", "mellow", "peaceful", "serene",
        "energetic", "upbeat", "hype", "pumped", "intense", "aggressive",
        "happy", "joyful", "feel-good", "cheerful", "euphoric",
        "sad", "melancholic", "emotional", "somber", "nostalgic",
        "romantic", "dreamy", "ethereal", "atmospheric",
        "dark", "moody", "brooding", "gritty",
        "focus", "study", "workout", "driving", "party",
        "sleepy", "cozy", "warm", "vibey", "groovy", "smooth"
    ]

    private static let decades: Set<String> = [
        "50s", "1950s", "60s", "1960s", "70s", "1970s",
        "80s", "1980s", "90s", "1990s", "00s", "2000s",
        "10s", "2010s", "20s", "2020s"
    ]

    // MARK: - Parsing

    /// Parses a natural language tuning prompt into structured TuningFilters.
    static func parse(_ prompt: String) -> TuningFilters {
        let lower = prompt.lowercased()
        var filters = TuningFilters()

        let lines = lower.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            let isExclusion = line.hasPrefix("no ") ||
                              line.hasPrefix("not ") ||
                              line.hasPrefix("exclude ") ||
                              line.hasPrefix("avoid ") ||
                              line.hasPrefix("less ") ||
                              line.hasPrefix("don't ") ||
                              line.hasPrefix("without ") ||
                              line.contains("no ") ||
                              line.contains("except ")

            // Check for artist references
            if line.contains("artist") || line.contains("like ") || line.contains("similar to ") {
                let artistNames = extractQuotedOrNamed(from: line)
                if isExclusion {
                    filters.excludeArtists.append(contentsOf: artistNames)
                } else {
                    filters.includeArtists.append(contentsOf: artistNames)
                }
            }

            // Check genres
            for genre in genres {
                if line.contains(genre) {
                    if isExclusion {
                        filters.excludeGenres.append(genre)
                    } else {
                        filters.includeGenres.append(genre)
                    }
                }
            }

            // Check moods
            for mood in moods {
                if line.contains(mood) {
                    filters.moods.append(mood)
                }
            }

            // Check decades
            for decade in decades {
                if line.contains(decade) {
                    filters.eras.append(decade)
                }
            }
        }

        // Also scan the entire prompt for genres/moods/decades in case they span lines
        for genre in genres {
            if lower.contains(genre) && !filters.includeGenres.contains(genre) && !filters.excludeGenres.contains(genre) {
                filters.includeGenres.append(genre)
            }
        }
        for mood in moods {
            if lower.contains(mood) && !filters.moods.contains(mood) {
                filters.moods.append(mood)
            }
        }
        for decade in decades {
            if lower.contains(decade) && !filters.eras.contains(decade) {
                filters.eras.append(decade)
            }
        }

        return filters
    }

    /// Extracts quoted names or names after "like"/"similar to" patterns.
    private static func extractQuotedOrNamed(from text: String) -> [String] {
        var names: [String] = []

        // Extract quoted strings
        let quotePattern = #""([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: quotePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    names.append(String(text[range]))
                }
            }
        }

        // Extract names after "like" or "similar to"
        for prefix in ["like ", "similar to ", "more "] {
            if let range = text.range(of: prefix) {
                let after = text[range.upperBound...]
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: CharacterSet(charactersIn: ".,;"))
                    .first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if !after.isEmpty && !names.contains(after) {
                    names.append(after)
                }
            }
        }

        return names
    }
}
