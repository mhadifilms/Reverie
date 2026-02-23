//
//  LRCParserTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for LRCParser
//

import Testing
@testable import Reverie

struct LRCParserTests {

    // MARK: - Standard Parsing

    @Test func parseStandardLRC() {
        let lrc = """
        [00:12.34]First line of lyrics
        [00:24.56]Second line of lyrics
        [01:05.00]Third line after a minute
        """

        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 3)
        #expect(lines[0].text == "First line of lyrics")
        #expect(lines[1].text == "Second line of lyrics")
        #expect(lines[2].text == "Third line after a minute")
    }

    @Test func parseTimestampsWithTwoDigitFraction() {
        let lrc = "[01:30.45]Hello world"
        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 1)
        // 1*60 + 30 + 0.45 = 90.45
        #expect(abs(lines[0].time - 90.45) < 0.001)
    }

    @Test func parseTimestampsWithThreeDigitFraction() {
        let lrc = "[02:15.123]Three digit fraction"
        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 1)
        // 2*60 + 15 + 0.123 = 135.123
        #expect(abs(lines[0].time - 135.123) < 0.001)
    }

    @Test func parseTimestampsWithoutFraction() {
        let lrc = "[03:00]No fraction part"
        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 1)
        // 3*60 = 180.0
        #expect(abs(lines[0].time - 180.0) < 0.001)
        #expect(lines[0].text == "No fraction part")
    }

    @Test func parseSortsLinesByTime() {
        let lrc = """
        [01:00.00]Second
        [00:30.00]First
        [02:00.00]Third
        """

        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 3)
        #expect(lines[0].text == "First")
        #expect(lines[1].text == "Second")
        #expect(lines[2].text == "Third")
    }

    // MARK: - Edge Cases

    @Test func parseEmptyString() {
        let lines = LRCParser.parse("")
        #expect(lines.isEmpty)
    }

    @Test func parseNoTimestamps() {
        let lrc = """
        Just plain text
        No timestamps here
        """
        let lines = LRCParser.parse(lrc)
        #expect(lines.isEmpty)
    }

    @Test func parseSkipsBlankLines() {
        let lrc = """
        [00:01.00]Line one

        [00:05.00]Line two
        """

        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 2)
    }

    @Test func parseTrimsWhitespace() {
        let lrc = "  [00:10.00]  Padded text  "
        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 1)
        #expect(lines[0].text == "Padded text")
    }

    @Test func parseThreeDigitMinutes() {
        let lrc = "[100:00.00]Long track"
        let lines = LRCParser.parse(lrc)
        #expect(lines.count == 1)
        // 100*60 = 6000.0
        #expect(abs(lines[0].time - 6000.0) < 0.001)
    }

    @Test func parseEachLineGetsUniqueID() {
        let lrc = """
        [00:01.00]A
        [00:02.00]B
        """
        let lines = LRCParser.parse(lrc)
        #expect(lines[0].id != lines[1].id)
    }

    // MARK: - Active Line (Binary Search)

    @Test func activeLineEmptyLines() {
        let result = LRCParser.activeLine(at: 5.0, in: [])
        #expect(result == nil)
    }

    @Test func activeLineBeforeFirst() {
        let lines = LRCParser.parse("[00:10.00]First line")
        let result = LRCParser.activeLine(at: 5.0, in: lines)
        #expect(result == nil)
    }

    @Test func activeLineExactMatch() {
        let lines = LRCParser.parse("""
        [00:10.00]Line A
        [00:20.00]Line B
        [00:30.00]Line C
        """)

        let result = LRCParser.activeLine(at: 20.0, in: lines)
        #expect(result == 1)
    }

    @Test func activeLineBetweenLines() {
        let lines = LRCParser.parse("""
        [00:10.00]Line A
        [00:20.00]Line B
        [00:30.00]Line C
        """)

        // Between Line B (20s) and Line C (30s) -> should be index 1 (Line B)
        let result = LRCParser.activeLine(at: 25.0, in: lines)
        #expect(result == 1)
    }

    @Test func activeLineAfterLast() {
        let lines = LRCParser.parse("""
        [00:10.00]Line A
        [00:20.00]Line B
        """)

        let result = LRCParser.activeLine(at: 100.0, in: lines)
        #expect(result == 1)
    }

    @Test func activeLineAtZero() {
        let lines = LRCParser.parse("""
        [00:00.00]Starts immediately
        [00:10.00]Second line
        """)

        let result = LRCParser.activeLine(at: 0.0, in: lines)
        #expect(result == 0)
    }

    // MARK: - Encode

    @Test func encodeRoundTrip() {
        let original = """
        [00:12.34]First line
        [01:05.00]Second line
        """

        let lines = LRCParser.parse(original)
        let encoded = LRCParser.encode(lines)
        let reparsed = LRCParser.parse(encoded)

        #expect(reparsed.count == lines.count)
        for i in 0..<lines.count {
            #expect(reparsed[i].text == lines[i].text)
            // Allow small rounding differences from centisecond encoding
            #expect(abs(reparsed[i].time - lines[i].time) < 0.02)
        }
    }

    @Test func encodeFormatsCorrectly() {
        let lrc = "[02:03.50]Test line"
        let lines = LRCParser.parse(lrc)
        let encoded = LRCParser.encode(lines)

        #expect(encoded == "[02:03.50]Test line")
    }

    @Test func encodeEmptyLines() {
        let encoded = LRCParser.encode([])
        #expect(encoded == "")
    }
}
