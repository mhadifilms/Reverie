//
//  NowPlayingBar.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI

struct NowPlayingBar: View {
    @Bindable var player: AudioPlayer
    @State private var isExpanded = false
    
    var body: some View {
        if player.currentTrack != nil {
            compactPlayer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.currentTrack?.id)
            .sheet(isPresented: $isExpanded) {
                FullPlayerView(player: player)
                    #if os(iOS)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    #endif
            }
        }
    }
    
    private var compactPlayer: some View {
        HStack(spacing: 14) {
            // Album art with glow effect
            ZStack {
                if let artData = player.currentTrack?.albumArtData {
                    #if canImport(UIKit)
                    if let image = UIImage(data: artData) {
                        // Glow effect
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .blur(radius: 12)
                            .opacity(0.6)
                            .offset(y: 2)
                        
                        // Main image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                    #elseif canImport(AppKit)
                    if let image = NSImage(data: artData) {
                        // Glow effect
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .blur(radius: 12)
                            .opacity(0.6)
                            .offset(y: 2)
                        
                        // Main image
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
                    #endif
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.3),
                                    Color.accentColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            // Track info with better typography
            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.title ?? "")
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                
                Text(player.currentTrack?.artist ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 12)
            
            // Control buttons with Liquid Glass
            HStack(spacing: 16) {
                // Play/Pause button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        player.togglePlayPause()
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                
                // Next button
                Button {
                    player.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Full Player View
struct FullPlayerView: View {
    @Bindable var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary, .ultraThinMaterial)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .padding()
            }
            
            // Main content
            VStack(spacing: 24) {
                Spacer()
                
                // Album art - Large and centered
                albumArtView
                
                // Track info
                trackInfoView
                    .padding(.top, 24)
                
                // Progress slider
                progressView
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                
                // Controls
                controlsView
                    .padding(.top, 20)
                
                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    private var albumArtView: some View {
        Group {
            if let artData = player.currentTrack?.albumArtData {
                #if canImport(UIKit)
                if let image = UIImage(data: artData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                #elseif canImport(AppKit)
                if let image = NSImage(data: artData) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                #endif
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.4),
                                Color.accentColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 80, weight: .light))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
    
    private var trackInfoView: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? "")
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text(player.currentTrack?.artist ?? "")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            
            if let album = player.currentTrack?.album, !album.isEmpty {
                Text(album)
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            Slider(value: Binding(
                get: { player.currentTime },
                set: { player.seek(to: $0) }
            ), in: 0...max(player.duration, 1))
            .tint(.accentColor)
            
            HStack {
                Text(formatTime(player.currentTime))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(player.duration))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var controlsView: some View {
        HStack(spacing: 44) {
            // Previous
            Button {
                player.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            
            // Play/Pause - Large center button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    player.togglePlayPause()
                }
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            
            // Next
            Button {
                player.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    @Previewable @State var player = AudioPlayer()
    
    VStack {
        Spacer()
        
        NowPlayingBar(player: player)
    }
    .task {
        // Create a mock track for preview
        let mockTrack = ReverieTrack(
            title: "Bohemian Rhapsody",
            artist: "Queen",
            album: "A Night at the Opera",
            durationSeconds: 354,
            albumArtData: nil,
            youtubeVideoID: "preview",
            downloadState: .downloaded
        )
        
        // Simulate playing
        try? await player.loadTrack(mockTrack)
        player.play()
    }
}
