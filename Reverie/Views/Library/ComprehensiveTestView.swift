//
//  ComprehensiveTestView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

/// Comprehensive test view for the complete flow: Import → Download → Play
struct ComprehensiveTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [ReveriePlaylist]
    
    @State private var viewModel = LibraryViewModel()
    @State private var playerViewModel = PlayerViewModel()
    @State private var currentStep = 0
    @State private var status = "Ready to start comprehensive test"
    @State private var isRunning = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Reverie - Comprehensive Test")
                .font(.largeTitle.bold())
            
            // Progress
            HStack(spacing: 16) {
                stepIndicator(1, "Import", currentStep >= 1)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                stepIndicator(2, "Download", currentStep >= 2)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                stepIndicator(3, "Play", currentStep >= 3)
            }
            
            Divider()
            
            // Status
            VStack(spacing: 12) {
                if isRunning {
                    ProgressView()
                }
                
                Text(status)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
            .frame(height: 100)
            
            // Playlist display
            if !playlists.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Imported Playlists")
                        .font(.headline)
                    
                    ForEach(playlists.prefix(3)) { playlist in
                        HStack {
                            Text(playlist.name)
                                .font(.body)
                            Spacer()
                            Text("\(playlist.downloadedTrackCount)/\(playlist.trackCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .frame(width: 500)
            }
            
            // Control buttons
            HStack(spacing: 16) {
                Button("Start Full Test") {
                    runFullTest()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                
                Button("Reset") {
                    reset()
                }
                .disabled(isRunning)
            }
        }
        .padding(40)
        .frame(width: 800, height: 600)
    }
    
    private func stepIndicator(_ number: Int, _ label: String, _ completed: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if completed {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.caption.bold())
                } else {
                    Text("\(number)")
                        .foregroundStyle(.white)
                        .font(.caption.bold())
                }
            }
            Text(label)
                .font(.subheadline.weight(completed ? .bold : .regular))
        }
    }
    
    private func runFullTest() {
        isRunning = true
        currentStep = 0
        
        Task {
            // Step 1: Import a small test playlist
            await step1Import()
            
            // Step 2: Download first track
            await step2Download()
            
            // Step 3: Play the track
            await step3Play()
            
            await MainActor.run {
                isRunning = false
                status = "✅ All tests completed successfully!"
            }
        }
    }
    
    private func step1Import() async {
        await MainActor.run {
            currentStep = 1
            status = "Step 1: Importing Spotify playlist..."
        }
        
        // Use a small test playlist (Spotify's "Top 50 Global" or similar)
        let testURL = "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
        
        do {
            await viewModel.importPlaylist(url: testURL, modelContext: modelContext)
            
            await MainActor.run {
                if let error = viewModel.importError {
                    status = "❌ Import failed: \(error)"
                } else {
                    status = "✅ Step 1 complete: Playlist imported with \(playlists.first?.trackCount ?? 0) tracks"
                }
            }
            
            // Wait a bit to show status
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            await MainActor.run {
                status = "❌ Import error: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }
    
    private func step2Download() async {
        guard let playlist = playlists.first,
              let firstTrack = playlist.tracks.first else {
            await MainActor.run {
                status = "❌ No tracks to download"
                isRunning = false
            }
            return
        }
        
        await MainActor.run {
            currentStep = 2
            status = "Step 2: Downloading \"\(firstTrack.title)\"..."
        }
        
        do {
            await playerViewModel.downloadTrack(firstTrack, modelContext: modelContext)
            
            // Wait for download to complete
            var attempts = 0
            while firstTrack.downloadState != .downloaded && firstTrack.downloadState != .failed && attempts < 60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                attempts += 1
                
                await MainActor.run {
                    status = "Downloading... \(Int(firstTrack.downloadProgress * 100))%"
                }
            }
            
            await MainActor.run {
                if firstTrack.downloadState == .downloaded {
                    status = "✅ Step 2 complete: Track downloaded successfully"
                } else {
                    status = "❌ Download failed or timed out"
                    isRunning = false
                }
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            await MainActor.run {
                status = "❌ Download error: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }
    
    private func step3Play() async {
        guard let playlist = playlists.first,
              let firstTrack = playlist.tracks.first,
              firstTrack.downloadState == .downloaded else {
            await MainActor.run {
                status = "❌ No downloaded tracks to play"
                isRunning = false
            }
            return
        }
        
        await MainActor.run {
            currentStep = 3
            status = "Step 3: Testing playback..."
        }
        
        do {
            await playerViewModel.playTrack(firstTrack, modelContext: modelContext)
            
            // Wait a bit to ensure playback started
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                if playerViewModel.audioPlayer.isPlaying {
                    status = "✅ Step 3 complete: Playback working!"
                    // Stop playback
                    playerViewModel.audioPlayer.pause()
                } else {
                    status = "⚠️ Playback may have issues"
                }
            }
        } catch {
            await MainActor.run {
                status = "❌ Playback error: \(error.localizedDescription)"
            }
        }
    }
    
    private func reset() {
        currentStep = 0
        status = "Ready to start comprehensive test"
        
        // Delete all test data
        for playlist in playlists {
            modelContext.delete(playlist)
        }
        try? modelContext.save()
    }
}

#Preview {
    ComprehensiveTestView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
