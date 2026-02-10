//
//  SettingsView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("saveToiCloud") private var saveToiCloud = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var storageUsed: String = "--"
    @State private var isRefreshingStorage = false
    
    private let storageManager = StorageManager()
    
    var body: some View {
        NavigationStack {
            Form {
                storageSection
                appearanceSection
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
            
            Button(openInFilesLabel) {
                Task {
                    await storageManager.openAudioFolder()
                }
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            
            NavigationLink("Manage Storage") {
                StorageManagementView()
            }
            
            HStack {
                Text("Audio Quality")
                Spacer()
                Text("Highest Available")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Storage")
        } footer: {
            Text("When enabled, audio files will be saved to your iCloud Drive and synced across devices.")
        }
    }
    
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
        }
    }
    
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
}
