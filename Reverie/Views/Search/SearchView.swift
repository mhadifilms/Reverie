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
            iOSSearchContent
                .toolbar(.hidden, for: .navigationBar)
        }
        #else
        searchContent
        #endif
    }

    #if os(iOS)
    /// iOS layout rebuilt to match the Canopy.html `ScreenSearch`:
    ///
    ///   • Status-bar spacer
    ///   • Large "Search" title
    ///   • Custom pill search field (44pt, 14-pt radius, hair border)
    ///   • Either the spec's two-section empty state (Recent + Browse by mood)
    ///     OR the existing results list, so all download/detail logic keeps
    ///     working without touching the view model.
    private var iOSSearchContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CanopyTheme.Space.lg) {
                Color.clear.frame(height: 8)

                Text("Search")
                    .font(CanopyTheme.Typography.displayTitle)
                    .foregroundStyle(CanopyTheme.Palette.ink)
                    .padding(.horizontal, CanopyTheme.Space.xl)

                searchPill
                    .padding(.horizontal, CanopyTheme.Space.xl)

                if searchViewModel.isSearching {
                    searchingState
                        .padding(.top, CanopyTheme.Space.xxl)
                } else if !searchText.isEmpty && searchViewModel.searchResults.isEmpty {
                    noResultsInline
                        .padding(.top, CanopyTheme.Space.xxl)
                } else if !searchViewModel.searchResults.isEmpty {
                    resultsList
                        .padding(.horizontal, CanopyTheme.Space.xl)
                } else {
                    recentSection
                        .padding(.horizontal, CanopyTheme.Space.xl)
                    browseByMoodSection
                        .padding(.horizontal, CanopyTheme.Space.xl)
                }

                Color.clear.frame(height: 40)
            }
            .padding(.top, CanopyTheme.Space.lg)
        }
        .background(CanopyTheme.Palette.paper.ignoresSafeArea())
        .onChange(of: searchText) { _, newValue in
            Task {
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
            searchViewModel.signalModelContext = modelContext
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { searchViewModel.errorMessage = nil }
        } message: {
            if let error = searchViewModel.errorMessage { Text(error) }
        }
        .focusedValue(\.focusSearchAction) { isSearchFocused = true }
        .sheet(isPresented: $showDetailSheet) {
            if let selectedResult {
                SearchResultDetailSheet(
                    result: selectedResult,
                    viewModel: searchViewModel,
                    modelContext: modelContext,
                    audioPlayer: audioPlayer
                )
            }
        }
    }

    // MARK: - Search pill

    private var searchPill: some View {
        HStack(spacing: CanopyTheme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CanopyTheme.Palette.faint)

            TextField("Artists, songs, lyrics…", text: $searchText)
                .font(CanopyTheme.Typography.body)
                .foregroundStyle(CanopyTheme.Palette.ink)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(CanopyTheme.Palette.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .frame(height: 44)
        .padding(.horizontal, CanopyTheme.Space.md)
        .background(
            RoundedRectangle(cornerRadius: CanopyTheme.Radius.md, style: .continuous)
                .fill(CanopyTheme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CanopyTheme.Radius.md, style: .continuous)
                .strokeBorder(CanopyTheme.Palette.hair, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = true }
    }

    // MARK: - Recent searches

    @ViewBuilder
    private var recentSection: some View {
        if searchViewModel.recentSearches.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recent")
                        .font(CanopyTheme.Typography.title2)
                        .foregroundStyle(CanopyTheme.Palette.ink)
                    Spacer()
                    Button("Clear") {
                        searchViewModel.clearRecentSearches()
                    }
                    .font(CanopyTheme.Typography.captionEmphasized)
                    .foregroundStyle(CanopyTheme.Palette.green)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear recent searches")
                }
                .padding(.bottom, CanopyTheme.Space.sm)

                ForEach(Array(searchViewModel.recentSearches.enumerated()), id: \.element) { index, query in
                    Button {
                        searchText = query
                        Task { await searchViewModel.search(query: query) }
                    } label: {
                        HStack(spacing: CanopyTheme.Space.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CanopyTheme.Palette.faint)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            Text(query)
                                .font(CanopyTheme.Typography.body)
                                .foregroundStyle(CanopyTheme.Palette.ink)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CanopyTheme.Palette.faint)
                        }
                        .padding(.vertical, CanopyTheme.Space.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search for \(query)")

                    if index < searchViewModel.recentSearches.count - 1 {
                        Divider()
                            .overlay(CanopyTheme.Palette.hair)
                    }
                }
            }
        }
    }

    // MARK: - Browse by mood grid

    private var browseByMoodSection: some View {
        let moods: [Mood] = [
            .init(title: "Ambient", hues: [Color(hex: 0x1A5140), Color(hex: 0x5FB98F)]),
            .init(title: "Lo-fi", hues: [Color(hex: 0x8A6A4B), Color(hex: 0xE8DFC9)]),
            .init(title: "Jazz", hues: [Color(hex: 0x2A2A2A), Color(hex: 0x6A5A4A)]),
            .init(title: "Classical", hues: [Color(hex: 0x075057), Color(hex: 0x84A8BE)]),
            .init(title: "Electronic", hues: [Color(hex: 0x083D48), Color(hex: 0x4FC7A7)]),
            .init(title: "Folk", hues: [Color(hex: 0x5A7A4A), Color(hex: 0xC6E5D2)]),
            .init(title: "Hip-hop", hues: [Color(hex: 0x1A1A1A), Color(hex: 0x5A4A5A)]),
            .init(title: "World", hues: [Color(hex: 0x8A6A3B), Color(hex: 0xE8C97B)]),
        ]

        return VStack(alignment: .leading, spacing: CanopyTheme.Space.md) {
            Text("Browse by mood")
                .font(CanopyTheme.Typography.title2)
                .foregroundStyle(CanopyTheme.Palette.ink)
                .padding(.top, CanopyTheme.Space.xl)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(moods) { mood in
                    Button {
                        searchText = mood.title.lowercased()
                        Task { await searchViewModel.search(query: mood.title.lowercased()) }
                    } label: {
                        moodTile(mood)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Browse \(mood.title)")
                }
            }
        }
    }

    private struct Mood: Identifiable {
        let title: String
        let hues: [Color]
        var id: String { title }
    }

    private func moodTile(_ mood: Mood) -> some View {
        Text(mood.title)
            .font(CanopyTheme.Typography.trackTitle)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 76)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: mood.hues,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    // MARK: - Results list (paper card with SearchResultRow)

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            let results = searchViewModel.searchResults
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
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
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedResult = result
                    showDetailSheet = true
                }
                .padding(.horizontal, CanopyTheme.Space.md)

                if index < results.count - 1 {
                    Divider()
                        .overlay(CanopyTheme.Palette.hair)
                        .padding(.leading, 72)
                }
            }
        }
        .padding(.vertical, CanopyTheme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: CanopyTheme.Radius.lg, style: .continuous)
                .fill(CanopyTheme.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CanopyTheme.Radius.lg, style: .continuous)
                .strokeBorder(CanopyTheme.Palette.hair, lineWidth: 0.5)
        )
    }

    // MARK: - Transient states

    private var searchingState: some View {
        HStack(spacing: CanopyTheme.Space.sm) {
            ProgressView().tint(CanopyTheme.Palette.green)
            Text("Searching…")
                .font(CanopyTheme.Typography.caption)
                .foregroundStyle(CanopyTheme.Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsInline: some View {
        VStack(spacing: CanopyTheme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(CanopyTheme.Palette.faint)
            Text("No results")
                .font(CanopyTheme.Typography.headline)
                .foregroundStyle(CanopyTheme.Palette.ink)
            Text("Try a different title or artist name.")
                .font(CanopyTheme.Typography.caption)
                .foregroundStyle(CanopyTheme.Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
    #endif

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
        .background(CanopyTheme.Palette.paper.ignoresSafeArea())
        .navigationTitle("Search")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search for songs on YouTube..."
        )
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
            // Wire signal collector for recommendations
            searchViewModel.signalModelContext = modelContext
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
                .frame(minWidth: 520, idealWidth: 540, minHeight: 520, idealHeight: 560)
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))

            VStack(spacing: 6) {
                Text("Search for Music")
                    .font(.title2.bold())

                Text("Find songs by title or artist name")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if searchText.isEmpty && !searchViewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Recent Searches")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            searchViewModel.clearRecentSearches()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Clear recent searches")
                    }
                    .padding(.horizontal, 32)

                    ForEach(searchViewModel.recentSearches, id: \.self) { query in
                        Button {
                            searchText = query
                            isSearchFocused = false
                            Task {
                                await searchViewModel.search(query: query)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(query)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search for \(query)")
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
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
            .accessibilityLabel("Clear search")
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
                .accessibilityLabel("\(result.title) by \(result.artist)")
                .accessibilityHint("Double tap for download options")
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
            // Inline action buttons (iOS)
            HStack(spacing: 8) {
                if result.isDownloading {
                    ProgressView(value: downloadProgress)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("Downloading")
                        .accessibilityValue("\(Int(downloadProgress * 100)) percent")
                } else if isDownloaded {
                    // Play button for downloaded tracks
                    Button {
                        playTrack()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play \(result.title)")
                } else {
                    // Download button
                    Button {
                        onDownload()
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Download \(result.title)")
                }
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
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
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
            .accessibilityLabel(primaryButtonTitle)
            .accessibilityHint(isDownloaded ? "Play this track" : "Download this track")
            
            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(uiColor: .systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
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
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
