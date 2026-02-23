//
//  ReverieL iveActivity.swift
//  Reverie
//
//  Created by Claude on 2/7/26.
//

import SwiftUI
import WidgetKit
import AppIntents

#if os(iOS)
#if canImport(ActivityKit)
import ActivityKit
#endif
#endif

#if canImport(ActivityKit) && os(iOS)

// MARK: - Activity Attributes

struct NowPlayingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var trackTitle: String
        var trackArtist: String
        var isPlaying: Bool
        var currentTime: TimeInterval
        var duration: TimeInterval
    }
    
    var trackID: String
}

// MARK: - Live Activity Views

struct NowPlayingLiveActivity: View {
    let context: ActivityViewContext<NowPlayingAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.trackTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(context.state.trackArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.title2)
                .foregroundStyle(.primary)
        }
        .padding()
    }
}

// MARK: - Expanded View (Dynamic Island)

struct NowPlayingExpandedView: View {
    let context: ActivityViewContext<NowPlayingAttributes>
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Album art
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.trackTitle)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(context.state.trackArtist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * CGFloat(context.state.currentTime / max(context.state.duration, 1)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            
            // Playback controls
            HStack(spacing: 40) {
                Button(intent: SkipBackwardIntent()) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                
                Button(intent: PlayPauseIntent()) {
                    Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }
                
                Button(intent: SkipForwardIntent()) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
            }
            .foregroundStyle(.primary)
        }
        .padding()
    }
}

// MARK: - Compact View (Dynamic Island)

struct NowPlayingCompactView: View {
    let context: ActivityViewContext<NowPlayingAttributes>
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                .font(.caption)
            
            Text(context.state.trackTitle)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

// MARK: - Minimal View (Dynamic Island)

struct NowPlayingMinimalView: View {
    let context: ActivityViewContext<NowPlayingAttributes>
    
    var body: some View {
        Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
            .font(.caption2)
    }
}

#endif
