//
//  EditPlaylistSheet.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
import SwiftData

struct EditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let playlist: ReveriePlaylist
    let modelContext: ModelContext
    
    @State private var playlistName: String
    @FocusState private var isTextFieldFocused: Bool
    
    init(playlist: ReveriePlaylist, modelContext: ModelContext) {
        self.playlist = playlist
        self.modelContext = modelContext
        _playlistName = State(initialValue: playlist.name)
    }
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Playlist")
                        .font(.title.bold())
                    
                    Text("Update your playlist name.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                // Input section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playlist Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField("My Awesome Playlist", text: $playlistName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .font(.body)
                        .accessibilityLabel("Playlist name")
                        .accessibilityHint("Enter a new name for the playlist")
                        .accessibilityValue(playlistName)
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Cancel editing")
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidName)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Save changes")
                }
            }
            .padding(32)
            .frame(minWidth: 500, idealWidth: 520, minHeight: 280, idealHeight: 300)
            .focusedValue(\.textInputActive, isTextFieldFocused)
            .onAppear {
                isTextFieldFocused = true
            }
            #else
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Edit Playlist")
                        .font(.title2.bold())
                    
                    Text("Update your playlist name")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    TextField("My Awesome Playlist", text: $playlistName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValidName {
                                saveChanges()
                            }
                        }
                        .accessibilityLabel("Playlist name")
                        .accessibilityHint("Enter a new name for the playlist")
                        .accessibilityValue(playlistName)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save button
                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValidName)
                .padding(.horizontal)
                .padding(.bottom, 32)
                .accessibilityLabel("Save changes")
            }
            .navigationBarTitleDisplayMode(.inline)
            .focusedValue(\.textInputActive, isTextFieldFocused)
            .onAppear {
                isTextFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel editing")
                }
            }
            #endif
        }
    }
    
    private var isValidName: Bool {
        !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveChanges() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        playlist.name = trimmedName
        try? modelContext.save()
        
        print("✅ Updated playlist name to: \(trimmedName)")
        
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ReveriePlaylist.self, ReverieTrack.self, configurations: config)
    
    let playlist = ReveriePlaylist(name: "My Playlist", isCustom: true)
    container.mainContext.insert(playlist)
    
    return EditPlaylistSheet(playlist: playlist, modelContext: container.mainContext)
}
