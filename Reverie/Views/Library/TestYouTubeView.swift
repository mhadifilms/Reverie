//
//  TestYouTubeView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI

/// Debug view to test YouTube resolution functionality
struct TestYouTubeView: View {
    @State private var testTitle = "Bohemian Rhapsody"
    @State private var testArtist = "Queen"
    @State private var status = "Ready to test"
    @State private var isLoading = false
    @State private var resolvedURL: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test YouTube Resolution")
                .font(.title.bold())
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Song Title")
                    .font(.caption.bold())
                TextField("Title", text: $testTitle)
                    .textFieldStyle(.roundedBorder)
                
                Text("Artist")
                    .font(.caption.bold())
                TextField("Artist", text: $testArtist)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 500)
            
            Button("Test YouTube Resolution") {
                testResolution()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(status)
                    .font(.body)
                    .foregroundStyle(status.contains("Error") ? .red : .primary)
                    .multilineTextAlignment(.leading)
                
                if let url = resolvedURL {
                    Text("Stream URL:")
                        .font(.caption.bold())
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: 600)
        }
        .padding(40)
    }
    
    private func testResolution() {
        isLoading = true
        status = "Testing YouTube resolver..."
        resolvedURL = nil
        
        Task {
            do {
                let resolver = YouTubeResolver()
                status = "Searching YouTube for: \(testTitle) - \(testArtist)"
                let resolved = try await resolver.resolveAudioURL(title: testTitle, artist: testArtist)
                
                await MainActor.run {
                    status = """
                    ✅ Success!
                    
                    Video ID: \(resolved.videoID)
                    Title: \(resolved.videoTitle)
                    Duration: \(resolved.durationSeconds)s
                    Bitrate: \(resolved.bitrate)kbps
                    Format: \(resolved.fileExtension)
                    """
                    resolvedURL = resolved.audioURL.absoluteString
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    status = "❌ Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    TestYouTubeView()
        .frame(width: 700, height: 600)
}
