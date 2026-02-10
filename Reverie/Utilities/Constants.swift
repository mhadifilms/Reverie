//
//  Constants.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import AVFoundation

enum Constants {
    // App Info
    static let appName = "Reverie"
    static let tagline = "Get lost in it."
    
    // Storage
    static let audioDirectoryName = "Audio"
    static let iCloudDirectoryName = "Reverie"
    
    // Download
    static let maxConcurrentDownloads = 3
    static let preferredAudioFormat = "m4a"
    static let targetAudioBitrate = 256 // kbps
    
    // API
    static let musicBrainzUserAgent = "Reverie/1.0 (reverie@example.com)"
    static let musicBrainzRateLimitDelay: TimeInterval = 1.0 // 1 request per second
    
    // UI
    static let defaultCornerRadius: CGFloat = 20
    static let defaultPadding: CGFloat = 16
    static let albumArtCornerRadius: CGFloat = 12
    static let miniPlayerHeight: CGFloat = 64

    // Waveform
    static let waveformBarCount: Int = 48
    static let waveformMinLevel: Float = 0.015
    static let waveformTapBufferSize: AVAudioFrameCount = 2048
    static let waveformAttackSmoothing: Float = 0.58
    static let waveformDecaySmoothing: Float = 0.22
    static let waveformUpdateInterval: TimeInterval = 1.0 / 60.0
    
    // Animation
    static let defaultAnimationDuration: Double = 0.3
    static let springResponse: Double = 0.4
    static let springDampingFraction: Double = 0.8
}
