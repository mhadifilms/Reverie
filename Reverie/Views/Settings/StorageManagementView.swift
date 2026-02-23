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
    
    @AppStorage("saveToiCloud") private var saveToiCloud = false
    
    @State private var totalStorage: String = "--"
    @State private var isRefreshing = false
    @State private var isDeleting = false
    @State private var currentLocation: String = "Local"
    @State private var isMigrating = false
    @State private var migrationProgress: Double = 0.0
    @State private var migrationStatus: String = ""
    @State private var showMigrationAlert = false
    
    private let storageManager = StorageManager()
    private let downloadManager = DownloadManager()
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current Location")
                    Spacer()
                    Text(currentLocation)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Total Used")
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
                .disabled(isRefreshing || isMigrating)
            } header: {
                Text("Storage Overview")
            } footer: {
                Text("Shows total storage used by downloaded audio files.")
            }
            
            // Migration Section
            if totalDownloadedTracks > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if isMigrating {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ProgressView()
                                    Text(migrationStatus)
                                        .font(.body)
                                }
                                
                                ProgressView(value: migrationProgress)
                                    .progressViewStyle(.linear)
                            }
                        } else {
                            if saveToiCloud && currentLocation == "Local" {
                                Button {
                                    showMigrationAlert = true
                                } label: {
                                    Label("Migrate to iCloud", systemImage: "icloud.and.arrow.up")
                                }
                            } else if !saveToiCloud && currentLocation == "iCloud Drive" {
                                Button {
                                    showMigrationAlert = true
                                } label: {
                                    Label("Migrate to Local Storage", systemImage: "internaldrive")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Migration")
                } footer: {
                    if saveToiCloud && currentLocation == "Local" {
                        Text("You have iCloud enabled but files are stored locally. Migrate them to enable sync across devices.")
                    } else if !saveToiCloud && currentLocation == "iCloud Drive" {
                        Text("You have iCloud disabled but files are in iCloud. Migrate them to local storage to free up iCloud space.")
                    }
                }
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
            await updateCurrentLocation()
        }
        .onChange(of: saveToiCloud) { _, _ in
            Task {
                await updateCurrentLocation()
            }
        }
        .alert("Migrate Files?", isPresented: $showMigrationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Migrate") {
                Task {
                    await performMigration()
                }
            }
        } message: {
            if saveToiCloud {
                Text("This will move all downloaded audio files to iCloud Drive. This may take a few moments depending on the number of files.")
            } else {
                Text("This will move all downloaded audio files to local storage on this device.")
            }
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
            try? await downloadManager.deleteTrack(track, modelContext: modelContext)
        }
        try? modelContext.save()
        await refreshStorage()
        isDeleting = false
    }
    
    private func removeAllDownloads() async {
        isDeleting = true
        for track in allTracks where track.downloadState == .downloaded {
            try? await downloadManager.deleteTrack(track, modelContext: modelContext)
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
    
    private func updateCurrentLocation() async {
        let location = await storageManager.getCurrentStorageLocation()
        await MainActor.run {
            currentLocation = location == .iCloud ? "iCloud Drive" : "Local"
        }
    }
    
    private func performMigration() async {
        isMigrating = true
        migrationProgress = 0.0
        migrationStatus = "Starting migration..."
        
        do {
            let destination: StorageManager.StorageLocation = saveToiCloud ? .iCloud : .local
            
            try await storageManager.migrateFiles(to: destination) { progress, status in
                Task { @MainActor in
                    migrationProgress = progress
                    migrationStatus = status
                }
            }
            
            // Update tracks to reflect new storage location
            // The file paths remain the same (relative), only the base directory changed
            try? modelContext.save()
            
            // Refresh storage info
            await refreshStorage()
            await updateCurrentLocation()
            
            migrationStatus = "Migration complete!"
            
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
        }
        
        // Keep showing completion status briefly
        try? await Task.sleep(for: .seconds(2))
        
        isMigrating = false
        migrationProgress = 0.0
        migrationStatus = ""
    }
}

#Preview {
    StorageManagementView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
