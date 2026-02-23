//
//  TuningParserTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for TuningParser
//

import Testing
@testable import Reverie

struct TuningParserTests {

    // MARK: - Genre Extraction

    @Test func parseSingleGenre() {
        let filters = TuningParser.parse("I want more jazz")
        #expect(filters.includeGenres.contains("jazz"))
    }

    @Test func parseMultipleGenres() {
        let filters = TuningParser.parse("I like rock and hip hop")
        #expect(filters.includeGenres.contains("rock"))
        #expect(filters.includeGenres.contains("hip hop"))
    }

    @Test func parseHyphenatedGenres() {
        let filters = TuningParser.parse("Play some lo-fi and k-pop")
        #expect(filters.includeGenres.contains("lo-fi"))
        #expect(filters.includeGenres.contains("k-pop"))
    }

    @Test func parseMultiWordGenres() {
        let filters = TuningParser.parse("I love bossa nova and drum and bass")
        #expect(filters.includeGenres.contains("bossa nova"))
        #expect(filters.includeGenres.contains("drum and bass"))
    }

    @Test func parseCaseInsensitiveGenres() {
        let filters = TuningParser.parse("More JAZZ and ROCK")
        #expect(filters.includeGenres.contains("jazz"))
        #expect(filters.includeGenres.contains("rock"))
    }

    // MARK: - Exclusions

    @Test func parseExcludeGenresWithNo() {
        let filters = TuningParser.parse("no country")
        #expect(filters.excludeGenres.contains("country"))
        #expect(!filters.includeGenres.contains("country"))
    }

    @Test func parseExcludeGenresWithExclude() {
        let filters = TuningParser.parse("exclude metal")
        #expect(filters.excludeGenres.contains("metal"))
    }

    @Test func parseExcludeGenresWithAvoid() {
        let filters = TuningParser.parse("avoid punk")
        #expect(filters.excludeGenres.contains("punk"))
    }

    @Test func parseExcludeGenresWithNot() {
        let filters = TuningParser.parse("not country please")
        #expect(filters.excludeGenres.contains("country"))
    }

    @Test func parseExcludeGenresWithWithout() {
        let filters = TuningParser.parse("without rap")
        #expect(filters.excludeGenres.contains("rap"))
    }

    // MARK: - Artist Preferences

    @Test func parseIncludeArtistWithQuotes() {
        let filters = TuningParser.parse("artists like \"Radiohead\"")
        #expect(filters.includeArtists.contains("radiohead"))
    }

    @Test func parseIncludeArtistWithLike() {
        let filters = TuningParser.parse("similar to coldplay")
        #expect(filters.includeArtists.contains("coldplay"))
    }

    @Test func parseExcludeArtist() {
        let filters = TuningParser.parse("no artist like \"Drake\"")
        #expect(filters.excludeArtists.contains("drake"))
    }

    // MARK: - Era / Decade

    @Test func parseSingleDecade() {
        let filters = TuningParser.parse("90s music only")
        #expect(filters.eras.contains("90s"))
    }

    @Test func parseFullDecade() {
        let filters = TuningParser.parse("music from 1980s")
        #expect(filters.eras.contains("1980s"))
    }

    @Test func parseMultipleDecades() {
        let filters = TuningParser.parse("80s and 90s hits")
        #expect(filters.eras.contains("80s"))
        #expect(filters.eras.contains("90s"))
    }

    @Test func parse2000sDecade() {
        let filters = TuningParser.parse("2000s nostalgia")
        #expect(filters.eras.contains("2000s"))
    }

    // MARK: - Mood

    @Test func parseSingleMood() {
        let filters = TuningParser.parse("something chill")
        #expect(filters.moods.contains("chill"))
    }

    @Test func parseMultipleMoods() {
        let filters = TuningParser.parse("I want something dreamy and ethereal")
        #expect(filters.moods.contains("dreamy"))
        #expect(filters.moods.contains("ethereal"))
    }

    @Test func parseActivityMoods() {
        let filters = TuningParser.parse("music for a workout")
        #expect(filters.moods.contains("workout"))
    }

    @Test func parseFocusMood() {
        let filters = TuningParser.parse("need focus music for study")
        #expect(filters.moods.contains("focus"))
        #expect(filters.moods.contains("study"))
    }

    // MARK: - Combined Prompts

    @Test func parseCombinedPrompt() {
        let filters = TuningParser.parse("chill 90s jazz, no metal")
        #expect(filters.moods.contains("chill"))
        #expect(filters.eras.contains("90s"))
        #expect(filters.includeGenres.contains("jazz"))
        #expect(filters.excludeGenres.contains("metal"))
    }

    @Test func parseMultilinePrompt() {
        let prompt = """
        More indie and shoegaze
        No country
        80s and 90s vibes
        """
        let filters = TuningParser.parse(prompt)
        #expect(filters.includeGenres.contains("indie"))
        #expect(filters.includeGenres.contains("shoegaze"))
        #expect(filters.excludeGenres.contains("country"))
        #expect(filters.eras.contains("80s"))
        #expect(filters.eras.contains("90s"))
    }

    // MARK: - Empty / No Match

    @Test func parseEmptyPrompt() {
        let filters = TuningParser.parse("")
        #expect(filters.includeGenres.isEmpty)
        #expect(filters.excludeGenres.isEmpty)
        #expect(filters.includeArtists.isEmpty)
        #expect(filters.excludeArtists.isEmpty)
        #expect(filters.eras.isEmpty)
        #expect(filters.moods.isEmpty)
    }

    @Test func parseIrrelevantText() {
        let filters = TuningParser.parse("I want something unique and different")
        // "unique" and "different" are not in mood/genre dictionaries
        #expect(filters.includeGenres.isEmpty)
        #expect(filters.moods.isEmpty)
    }
}
