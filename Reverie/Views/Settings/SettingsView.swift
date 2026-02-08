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
    
    var body: some View {
        NavigationStack {
            List {
                storageSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }
    
    private var storageSection: some View {
        Section {
            HStack {
                Text("Storage Used")
                Spacer()
                Text("0 MB")
                    .foregroundStyle(.secondary)
            }
            
            Toggle("Save to iCloud Drive", isOn: $saveToiCloud)
            
            NavigationLink("Manage Storage") {
                Text("Storage management coming soon...")
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
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
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
}

#Preview {
    SettingsView()
}
