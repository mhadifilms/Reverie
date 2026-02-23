//
//  LRCParser.swift
//  Reverie
//
//  Phase 2D: Parses LRC (Lyric) format into timed lyric lines.
//  Supports standard LRC: [mm:ss.xx] or [mm:ss.xxx] lines.
//

import Foundation

struct LRCParser {

    struct LyricLine: Identifiable {
        let id = UUID()
        let time: TimeInterval
        let text: String
    }

    /// Parses an LRC string into sorted lyric lines.
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        // Pattern matches [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
        let pattern = #"\[(\d{1,3}):(\d{2})(?:\.(\d{2,3}))?\](.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = regex.matches(in: trimmed, options: [], range: nsRange)

            for match in matches {
                guard match.numberOfRanges >= 4 else { continue }

                guard let minuteRange = Range(match.range(at: 1), in: trimmed),
                      let secondRange = Range(match.range(at: 2), in: trimmed),
                      let textRange = Range(match.range(at: 4), in: trimmed) else {
                    continue
                }

                let minutes = Double(trimmed[minuteRange]) ?? 0
                let seconds = Double(trimmed[secondRange]) ?? 0

                var fraction: Double = 0
                if match.range(at: 3).location != NSNotFound,
                   let fracRange = Range(match.range(at: 3), in: trimmed) {
                    let fracStr = String(trimmed[fracRange])
                    // Normalize: "xx" -> 0.xx, "xxx" -> 0.xxx
                    let divisor = pow(10.0, Double(fracStr.count))
                    fraction = (Double(fracStr) ?? 0) / divisor
                }

                let time = minutes * 60.0 + seconds + fraction
                let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)

                if !text.isEmpty {
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// Encodes lyric lines back to LRC format string.
    static func encode(_ lines: [LyricLine]) -> String {
        lines.map { line in
            let totalSeconds = line.time
            let minutes = Int(totalSeconds) / 60
            let seconds = Int(totalSeconds) % 60
            let centiseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)
            return String(format: "[%02d:%02d.%02d]%@", minutes, seconds, centiseconds, line.text)
        }.joined(separator: "\n")
    }

    /// Finds the index of the active lyric line for a given playback time.
    static func activeLine(at time: TimeInterval, in lines: [LyricLine]) -> Int? {
        guard !lines.isEmpty else { return nil }

        // Binary search for the last line whose time <= current time
        var low = 0
        var high = lines.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= time {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }
}
