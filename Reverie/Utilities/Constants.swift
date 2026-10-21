//
//  Constants.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import AVFoundation

/// Pure constants. Marked member-by-member as `nonisolated` so they can be
/// read from any actor (notably StorageManager, which is a file I/O actor)
/// without triggering Swift-6 actor-isolation errors. The values are all
/// Sendable literals so `nonisolated` is sound.
enum Constants {
    // App Info
    nonisolated static let appName = "Reverie"
    nonisolated static let tagline = "Get lost in it."

    // Storage
    nonisolated static let audioDirectoryName = "Audio"
    nonisolated static let iCloudDirectoryName = "Reverie"

    // Download
    nonisolated static let maxConcurrentDownloads = 3
    nonisolated static let preferredAudioFormat = "m4a"
    nonisolated static let targetAudioBitrate = 256 // kbps

    // API
    nonisolated static let musicBrainzUserAgent = "Reverie/1.0 (reverie@example.com)"
    nonisolated static let musicBrainzRateLimitDelay: TimeInterval = 1.0

    // UI
    nonisolated static let defaultCornerRadius: CGFloat = 20
    nonisolated static let defaultPadding: CGFloat = 16
    nonisolated static let albumArtCornerRadius: CGFloat = 12
    nonisolated static let miniPlayerHeight: CGFloat = 64

    // Waveform
    nonisolated static let waveformBarCount: Int = 64
    nonisolated static let waveformMinLevel: Float = 0.015
    nonisolated static let waveformTapBufferSize: AVAudioFrameCount = 2048
    nonisolated static let waveformAttackSmoothing: Float = 0.58
    nonisolated static let waveformDecaySmoothing: Float = 0.22
    nonisolated static let waveformUpdateInterval: TimeInterval = 1.0 / 60.0

    // Animation
    nonisolated static let defaultAnimationDuration: Double = 0.3
    nonisolated static let springResponse: Double = 0.4
    nonisolated static let springDampingFraction: Double = 0.8
}
