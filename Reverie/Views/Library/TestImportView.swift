//
//  TestImportView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

/// Debug view to test Spotify import functionality
struct TestImportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var testURL = "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
    @State private var status = "Ready to test"
    @State private var isLoading = false
    @State private var viewModel = LibraryViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test Spotify Import")
                .font(.title.bold())
            
            TextField("Spotify Playlist URL", text: $testURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 500)
            
            Button("Test Import") {
                testImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            
            if isLoading {
                ProgressView()
            }
            
            Text(status)
                .font(.body)
                .foregroundStyle(status.contains("Error") ? .red : .primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .padding(40)
    }
    
    private func testImport() {
        isLoading = true
        status = "Testing Spotify parser..."
        
        Task {
            do {
                let parser = SpotifyParser()
                status = "Parsing playlist from URL..."
                let playlistData = try await parser.parsePlaylist(from: testURL)
                
                await MainActor.run {
                    status = """
                    ✅ Success!
                    
                    Playlist: \(playlistData.name)
                    Tracks: \(playlistData.tracks.count)
                    Cover Art: \(playlistData.coverArtURL != nil ? "✓" : "✗")
                    
                    First track: \(playlistData.tracks.first?.title ?? "None")
                    By: \(playlistData.tracks.first?.artist ?? "Unknown")
                    """
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
    TestImportView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
        .frame(width: 700, height: 500)
}
