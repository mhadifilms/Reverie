//
//  SearchView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var searchViewModel = SearchViewModel()
    @State private var downloadManager: DownloadManager?
    
    let audioPlayer: AudioPlayer?
    let onNavigateToLibrary: (() -> Void)?
    
    init(audioPlayer: AudioPlayer? = nil, onNavigateToLibrary: (() -> Void)? = nil) {
        self.audioPlayer = audioPlayer
        self.onNavigateToLibrary = onNavigateToLibrary
    }
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            searchContent
        }
        #else
        searchContent
        #endif
    }
    
    private var searchContent: some View {
        VStack(spacing: 0) {
            if searchViewModel.searchResults.isEmpty && !searchViewModel.isSearching {
                emptyStateView
            } else {
                resultsListView
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search for songs on YouTube...")
        .onChange(of: searchText) { oldValue, newValue in
            Task {
                // Debounce search
                try? await Task.sleep(for: .milliseconds(500))
                guard searchText == newValue else { return }
                await searchViewModel.search(query: newValue)
            }
        }
        .onAppear {
            if downloadManager == nil {
                downloadManager = DownloadManager()
                searchViewModel.setDownloadManager(downloadManager!)
            }
        }
        .alert("Error", isPresented: .constant(searchViewModel.errorMessage != nil)) {
            Button("OK") {
                searchViewModel.errorMessage = nil
            }
        } message: {
            if let error = searchViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Search for Music")
                .font(.title2.bold())
            
            Text("Find songs by title or artist name on YouTube")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsListView: some View {
        ScrollView {
            #if os(iOS)
            LazyVStack(spacing: 8) {
                resultsContent
            }
            .padding(16)
            #else
            LazyVStack(spacing: 12) {
                resultsContent
            }
            .padding(32)
            #endif
        }
    }
    
    @ViewBuilder
    private var resultsContent: some View {
        if searchViewModel.isSearching {
            HStack {
                ProgressView()
                Text("Searching...")
                    .foregroundStyle(.secondary)
            }
            .padding()
        } else {
            ForEach(searchViewModel.searchResults) { result in
                SearchResultRow(
                    result: result,
                    viewModel: searchViewModel,
                    modelContext: modelContext,
                    audioPlayer: audioPlayer,
                    onNavigateToLibrary: onNavigateToLibrary,
                    onDownload: {
                        Task {
                            await searchViewModel.downloadTrack(videoID: result.videoID, modelContext: modelContext)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchViewModel.SearchResultItem
    let viewModel: SearchViewModel
    let modelContext: ModelContext
    let audioPlayer: AudioPlayer?
    let onNavigateToLibrary: (() -> Void)?
    let onDownload: () -> Void
    @State private var isHovered = false
    @State private var downloadProgress: Double = 0.0
    @State private var isDownloaded = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Album art / thumbnail
            Group {
                if let thumbnailURL = result.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            placeholderArt
                        @unknown default:
                            placeholderArt
                        }
                    }
                } else {
                    placeholderArt
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 4) {
                    Text(result.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let album = result.album, !album.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(album)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Duration
            if result.durationSeconds > 0 {
                Text(result.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            // Download button
            DownloadButton(
                state: buttonState,
                progress: downloadProgress,
                onDownload: {
                    onDownload()
                },
                onPlay: {
                    playTrack()
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            updateDownloadState()
        }
        .onChange(of: result.isDownloading) { _, _ in
            updateDownloadState()
        }
        .task {
            // Poll for download progress while downloading
            while result.isDownloading {
                try? await Task.sleep(for: .milliseconds(100))
                updateDownloadState()
            }
        }
    }
    
    private var buttonState: DownloadButton.DownloadButtonState {
        if isDownloaded {
            return .downloaded
        } else if result.isDownloading {
            return .downloading
        } else {
            return .notDownloaded
        }
    }
    
    private func updateDownloadState() {
        // Check if downloaded
        isDownloaded = viewModel.checkIfDownloaded(videoID: result.videoID, modelContext: modelContext)
        
        // Update progress if downloading
        if result.isDownloading {
            downloadProgress = viewModel.getDownloadProgress(for: result.videoID)
        }
    }
    
    private func playTrack() {
        guard let audioPlayer = audioPlayer,
              let trackID = viewModel.videoIDToTrackID[result.videoID] else {
            return
        }
        
        // Fetch the track from database
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { $0.id == trackID }
        )
        
        guard let tracks = try? modelContext.fetch(descriptor),
              let track = tracks.first else {
            return
        }
        
        // Navigate to Library tab
        onNavigateToLibrary?()
        
        // Play the track
        Task {
            try await audioPlayer.loadTrack(track)
            audioPlayer.play()
        }
    }
    
    private var placeholderArt: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
