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
            Form {
                Section("Playlist Name") {
                    TextField("My Awesome Playlist", text: $playlistName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                }
            }
            .padding()
            .navigationTitle("Create Playlist")
            .focusedValue(\.textInputActive, isTextFieldFocused)
            .onAppear {
                isTextFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPlaylist()
                    }
                    .disabled(!isValidName)
                    .keyboardShortcut(.defaultAction)
                }
            }
            #else
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
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
