//
//  TestSearchView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI

struct TestSearchView: View {
    @State private var searchQuery = "Blinding Lights The Weeknd"
    @State private var results: [YouTubeMusicSearch.SearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    
    private let searchService = YouTubeMusicSearch()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("YouTube Music InnerTube API Test")
                .font(.title.bold())
            
            HStack {
                TextField("Search query", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                
                Button("Search") {
                    Task {
                        await performSearch()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSearching)
            }
            .padding()
            
            if isSearching {
                ProgressView("Searching...")
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .padding()
            } else if results.isEmpty {
                Text("No results yet. Try searching!")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(results.count) Results:")
                            .font(.headline)
                        
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Title: \(result.title)")
                                    .font(.body.bold())
                                Text("Artist: \(result.artist)")
                                Text("Album: \(result.album ?? "N/A")")
                                Text("Video ID: \(result.videoID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Duration: \(result.formattedDuration)")
                                    .font(.caption)
                                if let thumbnail = result.thumbnailURL {
                                    AsyncImage(url: thumbnail) { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 120, height: 90)
                                }
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private func performSearch() async {
        isSearching = true
        errorMessage = nil
        results = []
        
        do {
            results = try await searchService.search(query: searchQuery, limit: 5)
            print("✅ Found \(results.count) results")
            for result in results {
                print("  - \(result.title) by \(result.artist)")
            }
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Search failed: \(error)")
        }
        
        isSearching = false
    }
}

#Preview {
    TestSearchView()
}
