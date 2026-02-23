//
//  CreatePlaylistSheet.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/7/26.
//

import SwiftUI
import SwiftData

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext
    
    @State private var playlistName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Playlist")
                        .font(.title.bold())
                    
                    Text("Give your new playlist a name.")
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
                        .accessibilityHint("Enter a name for your new playlist")
                }
                
                Spacer()
                
                // Action buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Cancel creating playlist")
                    
                    Spacer()
                    
                    Button("Create") {
                        createPlaylist()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidName)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Create playlist")
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
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    
                    Text("Create Playlist")
                        .font(.title2.bold())
                    
                    Text("Give your new playlist a name")
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
                                createPlaylist()
                            }
                        }
                        .accessibilityLabel("Playlist name")
                        .accessibilityHint("Enter a name for your new playlist")
                }
                .padding(.horizontal)
                .focusedValue(\.textInputActive, isTextFieldFocused)
                
                Spacer()
                
                // Create button
                Button {
                    createPlaylist()
                } label: {
                    Text("Create Playlist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValidName)
                .padding(.horizontal)
                .padding(.bottom, 32)
                .accessibilityLabel("Create playlist")
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
                    .accessibilityLabel("Cancel creating playlist")
                }
            }
            #endif
        }
    }
    
    private var isValidName: Bool {
        !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let playlist = ReveriePlaylist(
            name: trimmedName,
            isCustom: true
        )
        
        modelContext.insert(playlist)
        try? modelContext.save()
        
        print("✅ Created new playlist: \(trimmedName)")
        
        dismiss()
    }
}

#Preview {
    CreatePlaylistSheet(
        modelContext: ModelContext(
            try! ModelContainer(for: ReveriePlaylist.self, ReverieTrack.self)
        )
    )
}
