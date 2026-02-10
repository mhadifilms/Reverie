//
//  StorageManagementView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI
import SwiftData

@MainActor
struct StorageManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReveriePlaylist.dateImported, order: .reverse) private var playlists: [ReveriePlaylist]
    @Query private var allTracks: [ReverieTrack]
    
    @State private var totalStorage: String = "--"
    @State private var isRefreshing = false
    @State private var isDeleting = false
    
    private let storageManager = StorageManager()
    private let downloadManager = DownloadManager()
    
    var body: some View {
        Form {
            Section("Storage Used") {
                HStack {
                    Text("Total")
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Text(totalStorage)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("Refresh") {
                    Task {
                        await refreshStorage()
                    }
                }
                .disabled(isRefreshing)
            }
            
            if !playlistStorage.isEmpty {
                Section("By Playlist") {
                    ForEach(playlistStorage, id: \.playlist.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.playlist.name)
                                    .font(.body.weight(.medium))
                                Text("\(item.downloadedCount) downloaded")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.size)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button("Remove Downloads") {
                            Task {
                                await removeDownloads(for: item.playlist)
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            
            if orphanedDownloadsCount > 0 {
                Section("Other Downloads") {
                    HStack {
                        Text("Unsorted Tracks")
                        Spacer()
                        Text(formattedBytes(orphanedDownloadsSize))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if totalDownloadedTracks > 0 {
                Section {
                    Button(role: .destructive) {
                        Task {
                            await removeAllDownloads()
                        }
                    } label: {
                        Text("Delete All Downloads")
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("This removes downloaded audio files but keeps playlists and metadata.")
                }
            }
        }
        .navigationTitle("Manage Storage")
        .task {
            await refreshStorage()
        }
    }
    
    private var totalDownloadedTracks: Int {
        allTracks.filter { $0.downloadState == .downloaded }.count
    }
    
    private var playlistStorage: [(playlist: ReveriePlaylist, downloadedCount: Int, size: String)] {
        playlists.compactMap { playlist in
            let downloadedTracks = playlist.tracks.filter { $0.downloadState == .downloaded }
            let sizeBytes = downloadedTracks.compactMap { $0.fileSizeBytes }.reduce(0, +)
            guard sizeBytes > 0 else { return nil }
            return (playlist, downloadedTracks.count, formattedBytes(sizeBytes))
        }
    }
    
    private var orphanedDownloadsSize: Int64 {
        let inPlaylists = Set(playlists.flatMap { $0.tracks.map { $0.id } })
        return allTracks
            .filter { $0.downloadState == .downloaded && !inPlaylists.contains($0.id) }
            .compactMap { $0.fileSizeBytes }
            .reduce(0, +)
    }
    
    private var orphanedDownloadsCount: Int {
        let inPlaylists = Set(playlists.flatMap { $0.tracks.map { $0.id } })
        return allTracks
            .filter { $0.downloadState == .downloaded && !inPlaylists.contains($0.id) }
            .count
    }
    
    private func refreshStorage() async {
        isRefreshing = true
        do {
            let totalBytes = try await storageManager.calculateTotalStorageUsed()
            totalStorage = formattedBytes(totalBytes)
        } catch {
            totalStorage = "--"
        }
        isRefreshing = false
    }
    
    private func removeDownloads(for playlist: ReveriePlaylist) async {
        isDeleting = true
        for track in playlist.tracks where track.downloadState == .downloaded {
            try? await downloadManager.deleteTrack(track)
        }
        try? modelContext.save()
        await refreshStorage()
        isDeleting = false
    }
    
    private func removeAllDownloads() async {
        isDeleting = true
        for track in allTracks where track.downloadState == .downloaded {
            try? await downloadManager.deleteTrack(track)
        }
        try? modelContext.save()
        await refreshStorage()
        isDeleting = false
    }
    
    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    StorageManagementView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
