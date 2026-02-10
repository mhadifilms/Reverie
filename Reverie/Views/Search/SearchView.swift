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
    @FocusState private var isSearchFocused: Bool
    @State private var selectedResult: SearchViewModel.SearchResultItem?
    @State private var showDetailSheet = false
    
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
            if shouldShowEmptyState {
                emptyStateView
            } else if shouldShowNoResults {
                noResultsView
            } else {
                resultsListView
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Search for songs on YouTube...")
        .searchFocused($isSearchFocused)
        .focusedValue(\.textInputActive, isSearchFocused)
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
        .alert("Error", isPresented: errorBinding) {
            Button("OK") {
                searchViewModel.errorMessage = nil
            }
        } message: {
            if let error = searchViewModel.errorMessage {
                Text(error)
            }
        }
        .focusedValue(\.focusSearchAction) {
            isSearchFocused = true
        }
        .sheet(isPresented: $showDetailSheet) {
            if let selectedResult {
                SearchResultDetailSheet(
                    result: selectedResult,
                    viewModel: searchViewModel,
                    modelContext: modelContext,
                    audioPlayer: audioPlayer
                )
                #if os(macOS)
                .frame(width: 520, height: 520)
                #endif
            }
        }
    }
    
    private var shouldShowEmptyState: Bool {
        searchText.isEmpty && searchViewModel.searchResults.isEmpty && !searchViewModel.isSearching
    }
    
    private var shouldShowNoResults: Bool {
        !searchText.isEmpty && searchViewModel.searchResults.isEmpty && !searchViewModel.isSearching
    }
    
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { searchViewModel.errorMessage != nil },
            set: { if !$0 { searchViewModel.errorMessage = nil } }
        )
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
            
            if searchText.isEmpty && !searchViewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Searches")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            searchViewModel.clearRecentSearches()
                        }
                        .font(.caption)
                    }
                    
                    ForEach(searchViewModel.recentSearches, id: \.self) { query in
                        Button {
                            searchText = query
                            isSearchFocused = false
                            Task {
                                await searchViewModel.search(query: query)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(query)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            
            Text("No Results")
                .font(.title2.bold())
            
            Text("Try a different title or artist name.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Clear Search") {
                searchText = ""
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsListView: some View {
        #if os(macOS)
        List {
            if searchViewModel.isSearching {
                HStack {
                    ProgressView()
                    Text("Searching...")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
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
                        },
                        onCancel: {
                            Task {
                                await searchViewModel.cancelDownload(videoID: result.videoID, modelContext: modelContext)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            }
        }
        .listStyle(.inset)
        #else
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
        .scrollDismissesKeyboard(.interactively)
        #endif
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
            #if os(iOS)
            if !searchViewModel.searchResults.isEmpty {
                SectionHeaderView(
                    title: "Results",
                    subtitle: "\(searchViewModel.searchResults.count) matches",
                    systemImage: "magnifyingglass"
                )
                .padding(.bottom, 4)
            }
            ForEach(Array(searchViewModel.searchResults.enumerated()), id: \.element.id) { index, result in
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
                    },
                    onCancel: {
                        Task {
                            await searchViewModel.cancelDownload(videoID: result.videoID, modelContext: modelContext)
                        }
                    }
                )
                #if os(iOS)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedResult = result
                    showDetailSheet = true
                }
                #endif
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(
                    .easeOut(duration: 0.25).delay(Double(index) * 0.02),
                    value: searchViewModel.searchResults.count
                )
            }
            #else
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
                    },
                    onCancel: {
                        Task {
                            await searchViewModel.cancelDownload(videoID: result.videoID, modelContext: modelContext)
                        }
                    }
                )
            }
            #endif
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
    let onCancel: () -> Void
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
            
            #if os(macOS)
            // Download button
            DownloadButton(
                state: buttonState,
                progress: downloadProgress,
                onDownload: {
                    onDownload()
                },
                onPlay: {
                    playTrack()
                },
                onCancel: {
                    onCancel()
                }
            )
            #else
            // Status indicator (details shown on tap)
            if result.isDownloading {
                ProgressView(value: downloadProgress)
                    .frame(width: 24, height: 24)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        #if os(macOS)
        .listRowBackground(Color.clear)
        #else
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
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
    
    @ViewBuilder
    private var rowBackground: some View {
        #if os(iOS)
        RoundedRectangle(cornerRadius: 10)
            .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        #else
        Color.clear
        #endif
    }
}

// MARK: - Search Result Detail Sheet (iOS)
struct SearchResultDetailSheet: View {
    let result: SearchViewModel.SearchResultItem
    let viewModel: SearchViewModel
    let modelContext: ModelContext
    let audioPlayer: AudioPlayer?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isDownloading = false
    @State private var isDownloaded = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Artwork
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
            .frame(width: 220, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            
            VStack(spacing: 6) {
                Text(result.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(result.artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let album = result.album, !album.isEmpty {
                    Text(album)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                if result.durationSeconds > 0 {
                    Text(result.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal)
            
            Button {
                handlePrimaryAction()
            } label: {
                HStack(spacing: 10) {
                    if isDownloading {
                        ProgressView()
                    } else {
                        Image(systemName: isDownloaded ? "play.fill" : "arrow.down.circle.fill")
                    }
                    Text(primaryButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDownloading)
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .padding(.top, 24)
        .onAppear {
            isDownloaded = viewModel.checkIfDownloaded(videoID: result.videoID, modelContext: modelContext)
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
    
    private var primaryButtonTitle: String {
        if isDownloading {
            return "Downloading..."
        }
        return isDownloaded ? "Play" : "Download & Play"
    }
    
    private func handlePrimaryAction() {
        if isDownloaded {
            playDownloadedTrack()
            dismiss()
        } else {
            Task {
                isDownloading = true
                await viewModel.downloadAndPlay(
                    videoID: result.videoID,
                    modelContext: modelContext,
                    audioPlayer: audioPlayer
                )
                isDownloading = false
                isDownloaded = true
                dismiss()
            }
        }
    }
    
    private func playDownloadedTrack() {
        guard let audioPlayer,
              let trackID = viewModel.videoIDToTrackID[result.videoID] else {
            return
        }
        
        let descriptor = FetchDescriptor<ReverieTrack>(
            predicate: #Predicate { $0.id == trackID }
        )
        
        guard let tracks = try? modelContext.fetch(descriptor),
              let track = tracks.first else {
            return
        }
        
        Task {
            try? await audioPlayer.loadTrack(track)
            audioPlayer.play()
        }
    }
    
    private var placeholderArt: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
