//
//  SettingsView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("saveToiCloud") private var saveToiCloud = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("tuningPrompt") private var tuningPrompt = ""
    @AppStorage("downloadQuality") private var downloadQuality = "medium"
    @AppStorage("storageBudgetGB") private var storageBudgetGB: Double = 0  // 0 = unlimited
    @AppStorage("allowCellularStreaming") private var allowCellularStreaming = true
    @AppStorage("allowCellularDownloads") private var allowCellularDownloads = false
    @AppStorage("vinylMode") private var vinylMode = false
    #if os(macOS)
    @AppStorage("showMenuBarPlayer") private var showMenuBarPlayer = false
    #endif

    @Environment(\.modelContext) private var modelContext

    @State private var storageUsed: String = "--"
    @State private var isRefreshingStorage = false
    @State private var showRedownloadConfirmation = false
    @State private var downloadManager = DownloadManager()

    private let storageManager = StorageManager()

    private var selectedQuality: AudioQualityTier {
        AudioQualityTier(rawValue: downloadQuality) ?? .medium
    }

    private let network = NetworkMonitor.shared

    var body: some View {
        NavigationStack {
            Form {
                playbackSection
                downloadsSection
                cellularDataSection
                appearanceSection
                recommendationsSection
                storageSection
                aboutSection
            }
            .navigationTitle("Settings")
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .task {
                await refreshStorageUsage()
            }
            .onChange(of: saveToiCloud) { _, _ in
                Task {
                    await refreshStorageUsage()
                }
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section {
            Toggle("Vinyl Mode", isOn: $vinylMode)

            HStack {
                Text("Network")
                Spacer()
                Text(network.statusDescription)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Playback")
        } footer: {
            Text("Vinyl mode spins the album art like a record in the Now Playing screen.")
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            HStack {
                Text("Storage Used")
                Spacer()
                if isRefreshingStorage {
                    ProgressView()
                } else {
                    Text(storageUsed)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Save Location", selection: $saveToiCloud) {
                Text("On Device").tag(false)
                Text("iCloud Drive").tag(true)
            }
            #if os(macOS)
            .pickerStyle(.segmented)
            #endif

            Picker("Storage Budget", selection: $storageBudgetGB) {
                Text("1 GB").tag(1.0)
                Text("2 GB").tag(2.0)
                Text("5 GB").tag(5.0)
                Text("10 GB").tag(10.0)
                Text("Unlimited").tag(0.0)
            }

            Button(openInFilesLabel) {
                Task {
                    await storageManager.openAudioFolder()
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            NavigationLink("Manage Storage") {
                StorageManagementView()
            }
        } header: {
            Text("Storage")
        } footer: {
            if storageBudgetGB > 0 {
                Text("You will be notified when storage exceeds \(Int(storageBudgetGB)) GB. Files are saved to \(saveToiCloud ? "iCloud Drive" : "this device").")
            } else {
                Text("When enabled, audio files will be saved to your iCloud Drive and synced across devices.")
            }
        }
    }

    // MARK: - Downloads Section

    private var downloadsSection: some View {
        Section {
            Picker("Download Quality", selection: $downloadQuality) {
                ForEach(AudioQualityTier.allCases) { tier in
                    Text(tier.displayName).tag(tier.rawValue)
                }
            }

            if downloadManager.isRedownloading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                        Text("Updating \(downloadManager.redownloadCompleted)/\(downloadManager.redownloadTotal) tracks")
                            .font(.body)
                    }
                    ProgressView(
                        value: Double(downloadManager.redownloadCompleted),
                        total: max(Double(downloadManager.redownloadTotal), 1)
                    )
                    .progressViewStyle(.linear)
                }
            } else {
                Button("Re-download All at \(selectedQuality.displayName)") {
                    showRedownloadConfirmation = true
                }
                .confirmationDialog(
                    "Re-download all tracks?",
                    isPresented: $showRedownloadConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Re-download") {
                        Task {
                            await downloadManager.redownloadAll(
                                at: selectedQuality,
                                modelContext: modelContext
                            )
                            await refreshStorageUsage()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will re-download all tracks at \(selectedQuality.displayName) quality. Existing files will be replaced. This may use significant data.")
                }
            }
        } header: {
            Text("Downloads")
        } footer: {
            Text("Higher quality uses more storage. Medium (128 kbps) is recommended for most listeners.")
        }
    }

    // MARK: - Cellular Data Section

    private var cellularDataSection: some View {
        Section {
            Toggle("Stream over Cellular", isOn: $allowCellularStreaming)

            Toggle("Download over Cellular", isOn: $allowCellularDownloads)
        } header: {
            Text("Cellular Data")
        } footer: {
            Text("When disabled, streaming and downloads will only work on Wi-Fi. Downloaded tracks are always available offline.")
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tuning Prompt")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $tuningPrompt)
                    .frame(minHeight: 80)
                    .font(.body)
                    #if os(iOS)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    #endif
            }
        } header: {
            Text("Recommendations")
        } footer: {
            Text("Describe your music taste in plain language. Examples:\n\"More indie rock and shoegaze, no country\"\n\"Chill lo-fi vibes, 90s hip hop, artists like Nujabes\"")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            #if os(macOS)
            .pickerStyle(.segmented)
            #endif

            #if os(macOS)
            Toggle("Show Menu Bar Player", isOn: $showMenuBarPlayer)
            #endif
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://github.com")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func refreshStorageUsage() async {
        isRefreshingStorage = true
        do {
            let bytes = try await storageManager.calculateTotalStorageUsed()
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            storageUsed = formatter.string(fromByteCount: bytes)
        } catch {
            storageUsed = "--"
        }
        isRefreshingStorage = false
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? "1.0"
    }

    private var openInFilesLabel: String {
        #if os(macOS)
        return "Open in Finder"
        #else
        return "Open in Files"
        #endif
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [ReveriePlaylist.self, ReverieTrack.self], inMemory: true)
}
