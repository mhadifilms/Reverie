//
//  SpotifyImportReviewView.swift
//  Reverie
//
//  Created by Claude on 2/7/26.
//

import SwiftUI
import SwiftData

/// Review screen for Spotify imports - shows Spotify tracks matched to YouTube
struct SpotifyImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    let playlistData: SpotifyParser.PlaylistData
    let spotifyURL: String
    @Bindable var libraryViewModel: LibraryViewModel
    let modelContext: ModelContext
    
    @State private var matchedTracks: [TrackMatch] = []
    @State private var isSearching = false
    @State private var isConfirming = false
    @State private var selectedTrack: TrackMatch?
    @State private var showSearchSheet = false
    
    struct TrackMatch: Identifiable {
        let id = UUID()
        let spotifyTrack: SpotifyParser.TrackData
        var youtubeMatch: YouTubeMusicSearch.SearchResult?
        var isLoading: Bool = false
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with album info
                headerView
                
                Divider()
                
                // Track list with matches
                if isSearching {
                    ProgressView("Searching YouTube Music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    #if os(macOS)
                    List {
                        ForEach(matchedTracks) { match in
                            TrackMatchRow(
                                match: match,
                                onSearchAlternative: {
                                    selectedTrack = match
                                    showSearchSheet = true
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                    }
                    .listStyle(.inset)
                    #else
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(matchedTracks) { match in
                                TrackMatchRow(
                                    match: match,
                                    onSearchAlternative: {
                                        selectedTrack = match
                                        showSearchSheet = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    #endif
                }
                
                #if os(iOS)
                Divider()
                // Bottom action bar
                bottomActionBar
                #endif
            }
            .navigationTitle("Review Import")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .frame(minWidth: 800, idealWidth: 900, minHeight: 600, idealHeight: 700)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel import")
                }
                
                #if os(macOS)
                ToolbarItem(placement: .secondaryAction) {
                    Button("Search All Again") {
                        Task {
                            await searchAllTracks()
                        }
                    }
                    .disabled(isSearching || isConfirming)
                    .accessibilityLabel("Search all tracks again")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Confirm & Download") {
                        confirmImport()
                    }
                    .disabled(isSearching || isConfirming || matchedTracks.filter({ $0.youtubeMatch != nil }).isEmpty)
                    .accessibilityLabel("Confirm and download matched tracks")
                    .accessibilityHint("\(matchedTracks.filter({ $0.youtubeMatch != nil }).count) tracks will be downloaded")
                }
                
                ToolbarItem(placement: .status) {
                    Text("\(matchedTracks.filter({ $0.youtubeMatch != nil }).count)/\(matchedTracks.count) matched")
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .sheet(isPresented: $showSearchSheet) {
                if let track = selectedTrack {
                    AlternativeSearchSheet(
                        spotifyTrack: track.spotifyTrack,
                        onSelect: { newMatch in
                            updateMatch(for: track, with: newMatch)
                        }
                    )
                }
            }
        }
        .task {
            await searchAllTracks()
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Album art
            Group {
                if let coverURL = playlistData.coverArtURL.flatMap({ URL(string: $0) }) {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            playlistArtPlaceholder
                        @unknown default:
                            playlistArtPlaceholder
                        }
                    }
                } else {
                    playlistArtPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlistData.name)
                    .font(.headline)
                
                Text("\(matchedTracks.count) tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if matchedTracks.filter({ $0.youtubeMatch != nil }).count < matchedTracks.count {
                    Text("\(matchedTracks.filter({ $0.youtubeMatch == nil }).count) missing matches")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
        }
        .padding()
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
    }
    
    #if os(iOS)
    private var bottomActionBar: some View {
        HStack {
            Button("Search All Again") {
                Task {
                    await searchAllTracks()
                }
            }
            .disabled(isSearching || isConfirming)
            .accessibilityLabel("Search all tracks again")
            
            Spacer()
            
            Text("\(matchedTracks.filter({ $0.youtubeMatch != nil }).count)/\(matchedTracks.count) matched")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Confirm & Download") {
                confirmImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSearching || isConfirming || matchedTracks.filter({ $0.youtubeMatch != nil }).isEmpty)
            .accessibilityLabel("Confirm and download matched tracks")
            .accessibilityHint("\(matchedTracks.filter({ $0.youtubeMatch != nil }).count) tracks will be downloaded")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    #endif
    
    private var playlistArtPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
    }
    
    private func searchAllTracks() async {
        isSearching = true
        matchedTracks = playlistData.tracks.map { TrackMatch(spotifyTrack: $0, isLoading: true) }
        
        let ytSearch = YouTubeMusicSearch()
        
        for index in matchedTracks.indices {
            let track = matchedTracks[index].spotifyTrack
            let searchQuery = "\(track.title) \(track.artist)"
            
            do {
                let results = try await ytSearch.search(query: searchQuery)
                if let firstResult = results.first {
                    matchedTracks[index].youtubeMatch = firstResult
                }
                matchedTracks[index].isLoading = false
            } catch {
                print("Search failed for \(track.title): \(error)")
                matchedTracks[index].isLoading = false
            }
        }
        
        isSearching = false
    }
    
    private func updateMatch(for trackMatch: TrackMatch, with newMatch: YouTubeMusicSearch.SearchResult) {
        if let index = matchedTracks.firstIndex(where: { $0.id == trackMatch.id }) {
            matchedTracks[index].youtubeMatch = newMatch
        }
    }
    
    private func confirmImport() {
        print("🎯 CONFIRM IMPORT BUTTON CLICKED")
        print("📊 Total tracks to import: \(matchedTracks.filter({ $0.youtubeMatch != nil }).count)")
        isConfirming = true

        Task {
            print("🔄 Starting import process...")
            await libraryViewModel.importConfirmedTracks(
                playlistData: playlistData,
                matches: matchedTracks,
                spotifyURL: spotifyURL,
                modelContext: modelContext
            )

            print("✅ Import complete, dismissing view")
            dismiss()
        }
    }
}

// MARK: - Track Match Row

struct TrackMatchRow: View {
    let match: SpotifyImportReviewView.TrackMatch
    let onSearchAlternative: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number and info
            VStack(alignment: .leading, spacing: 4) {
                Text(match.spotifyTrack.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(match.spotifyTrack.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Match indicator
            if match.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityLabel("Searching for match")
            } else if let youtubeMatch = match.youtubeMatch {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .accessibilityHidden(true)
                        
                        Text(youtubeMatch.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Matched to \(youtubeMatch.title)")
                    
                    Button("Change") {
                        onSearchAlternative()
                    }
                    .font(.caption)
                    #if os(macOS)
                    .buttonStyle(.link)
                    #else
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    #endif
                    .accessibilityLabel("Change match for \(match.spotifyTrack.title)")
                }
            } else {
                Button("Find Match") {
                    onSearchAlternative()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.orange)
                .accessibilityLabel("Find match for \(match.spotifyTrack.title)")
            }
        }
        .padding(12)
        #if os(iOS)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        #endif
    }
}

// MARK: - Alternative Search Sheet

struct AlternativeSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let spotifyTrack: SpotifyParser.TrackData
    let onSelect: (YouTubeMusicSearch.SearchResult) -> Void
    
    @State private var searchQuery: String
    @State private var searchResults: [YouTubeMusicSearch.SearchResult] = []
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool
    
    init(spotifyTrack: SpotifyParser.TrackData, onSelect: @escaping (YouTubeMusicSearch.SearchResult) -> Void) {
        self.spotifyTrack = spotifyTrack
        self.onSelect = onSelect
        _searchQuery = State(initialValue: "\(spotifyTrack.title) \(spotifyTrack.artist)")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Search bar
                TextField("Search YouTube Music", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .padding(.horizontal)
                    .focusedValue(\.textInputActive, isSearchFocused)
                    .accessibilityLabel("Search YouTube Music")
                    .accessibilityHint("Enter search terms and press return to search")
                
                Divider()
                
                // Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    Text("No results")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults) { result in
                        Button {
                            onSelect(result)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.body)
                                    
                                    if !result.artist.isEmpty {
                                        Text(result.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(result.title) by \(result.artist)")
                        .accessibilityHint("Double tap to select this match")
                    }
                }
            }
            .navigationTitle("Find Alternative")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel search")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Search") {
                        performSearch()
                    }
                    .disabled(searchQuery.isEmpty || isSearching)
                    .accessibilityLabel("Search for alternatives")
                }
            }
        }
        .frame(width: 500, height: 600)
        .task {
            performSearch()
        }
    }
    
    private func performSearch() {
        isSearching = true
        searchResults = []
        
        Task {
            let ytSearch = YouTubeMusicSearch()
            do {
                searchResults = try await ytSearch.search(query: searchQuery)
            } catch {
                print("Search failed: \(error)")
            }
            isSearching = false
        }
    }
}
