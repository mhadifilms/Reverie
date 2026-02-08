//
//  DownloadButton.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI

/// App Store-style circular download button that transforms into a play button
struct DownloadButton: View {
    let state: DownloadButtonState
    let progress: Double
    let onDownload: () -> Void
    let onPlay: () -> Void
    let onCancel: (() -> Void)?
    
    enum DownloadButtonState {
        case notDownloaded
        case downloading
        case downloaded
        case failed
    }
    
    init(
        state: DownloadButtonState,
        progress: Double,
        onDownload: @escaping () -> Void,
        onPlay: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.state = state
        self.progress = progress
        self.onDownload = onDownload
        self.onPlay = onPlay
        self.onCancel = onCancel
    }
    
    var body: some View {
        Button {
            switch state {
            case .notDownloaded, .failed:
                onDownload()
            case .downloading:
                onCancel?()
            case .downloaded:
                onPlay()
            }
        } label: {
            ZStack {
                switch state {
                case .notDownloaded:
                    // Download icon with circle
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                case .downloading:
                    // Circular progress indicator with X to cancel
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.blue.opacity(0.2), lineWidth: 2.5)
                            .frame(width: 28, height: 28)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                Color.blue,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: progress)
                        
                        // X icon in center to cancel
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                    
                case .failed:
                    // Retry icon
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                case .downloaded:
                    // Play button
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
    }
}

#Preview {
    VStack(spacing: 40) {
        DownloadButton(
            state: .notDownloaded,
            progress: 0,
            onDownload: {},
            onPlay: {}
        )
        
        DownloadButton(
            state: .downloading,
            progress: 0.35,
            onDownload: {},
            onPlay: {}
        )
        
        DownloadButton(
            state: .downloading,
            progress: 0.75,
            onDownload: {},
            onPlay: {}
        )
        
        DownloadButton(
            state: .downloaded,
            progress: 1.0,
            onDownload: {},
            onPlay: {}
        )
    }
    .padding()
}
