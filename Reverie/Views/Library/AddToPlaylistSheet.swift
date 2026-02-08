//
//  AddToPlaylistSheet.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
import SwiftData

struct AddToPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ReveriePlaylist.dateCreated, order: .reverse) private var playlists: [ReveriePlaylist]
    
    let track: ReverieTrack
    let modelContext: ModelContext
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if availablePlaylists.isEmpty {
                    emptyStateView
                } else {
                    playlistsList
                }
            }
            .navigationTitle("Add to Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var availablePlaylists: [ReveriePlaylist] {
        playlists.filter { !track.playlists.contains($0) }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No Playlists Available")
                .font(.title3.bold())
            
            Text("This song is already in all your playlists")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var playlistsList: some View {
        List {
            ForEach(availablePlaylists) { playlist in
                Button {
                    addToPlaylist(playlist)
                } label: {
                    HStack(spacing: 12) {
                        // Playlist cover art
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay {
                                if let coverData = playlist.coverArtData {
                                    #if canImport(UIKit)
                                    if let uiImage = UIImage(data: coverData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                    #elseif canImport(AppKit)
                                    if let nsImage = NSImage(data: coverData) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                    #endif
                                } else {
                                    Image(systemName: playlist.isCustom ? "music.note.list" : "music.note")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Text("\(playlist.trackCount) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }
    
    private func addToPlaylist(_ playlist: ReveriePlaylist) {
        // Add track to playlist
        track.playlists.append(playlist)
        playlist.tracks.append(track)
        
        // Save changes
        try? modelContext.save()
        
        print("✅ Added \"\(track.title)\" to \"\(playlist.name)\"")
        
        // Show feedback and dismiss
        HapticManager.shared.downloadComplete()
        dismiss()
    }
}

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ReveriePlaylist.self, ReverieTrack.self, configurations: config)
    
    // Create mock data
    let track = ReverieTrack(
        title: "Bohemian Rhapsody",
        artist: "Queen",
        album: "A Night at the Opera"
    )
    
    let playlist1 = ReveriePlaylist(name: "Rock Classics", isCustom: true)
    let playlist2 = ReveriePlaylist(name: "Favorites", isCustom: true)
    
    container.mainContext.insert(track)
    container.mainContext.insert(playlist1)
    container.mainContext.insert(playlist2)
    
    return AddToPlaylistSheet(track: track, modelContext: container.mainContext)
        .modelContainer(container)
}
