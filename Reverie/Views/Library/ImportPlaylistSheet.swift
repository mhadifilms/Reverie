//
//  ImportPlaylistSheet.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

struct ImportPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LibraryViewModel
    let modelContext: ModelContext
    
    @State private var playlistURL: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            #if os(macOS)
            VStack(alignment: .leading, spacing: 16) {
                Text("Import from Spotify")
                    .font(.title2.bold())
                
                Text("Paste a Spotify playlist or album link.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spotify URL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    TextField(
                        "",
                        text: $playlistURL,
                        prompt: Text("https://open.spotify.com/playlist/... or /album/...")
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .autocorrectionDisabled()
                    .frame(maxWidth: 520)
                }
                
                HStack(spacing: 12) {
                    Button("Paste from Clipboard") {
                        pasteFromClipboard()
                    }
                    .buttonStyle(.bordered)
                    
                    if let error = viewModel.importError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                Spacer()
                
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(viewModel.isImporting)
                    
                    Spacer()
                    
                    Button(importButtonTitle) {
                        startImport()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidURL || viewModel.isImporting)
                }
            }
            .padding(24)
            .frame(minWidth: 560, minHeight: 320)
            .focusedValue(\.textInputActive, isTextFieldFocused)
            .onAppear {
                isTextFieldFocused = true
            }
            #else
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("Import from Spotify")
                        .font(.title2.bold())
                    
                    Text("Paste a Spotify playlist or album link to import")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                // URL Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spotify URL")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    TextField("https://open.spotify.com/playlist/... or /album/...", text: $playlistURL)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit {
                            if isValidURL && !viewModel.isImporting {
                                startImport()
                            }
                        }
                }
                .padding(.horizontal)
                
                // Error message
                if let error = viewModel.importError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Import button
                Button {
                    startImport()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isImporting {
                            ProgressView()
                        }
                        Text(importButtonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValidURL || viewModel.isImporting)
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
                    .disabled(viewModel.isImporting)
                }
            }
            #endif
        }
    }
    
    private var importButtonTitle: String {
        isAlbumURL ? "Import Album" : "Import Playlist"
    }
    
    private var isAlbumURL: Bool {
        playlistURL.contains("/album/") || playlistURL.hasPrefix("spotify:album:")
    }
    
    private func startImport() {
        Task {
            await viewModel.parsePlaylistForReview(url: playlistURL)
            if viewModel.parsedPlaylistData != nil {
                dismiss()
            }
        }
    }

    #if os(macOS)
    private func pasteFromClipboard() {
        if let pasted = NSPasteboard.general.string(forType: .string) {
            playlistURL = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    #endif
    
    private var isValidURL: Bool {
        playlistURL.contains("spotify.com/playlist/") || 
        playlistURL.contains("spotify.com/album/") ||
        playlistURL.hasPrefix("spotify:playlist:") ||
        playlistURL.hasPrefix("spotify:album:")
    }
}

#Preview {
    ImportPlaylistSheet(
        viewModel: LibraryViewModel(),
        modelContext: ModelContext(
            try! ModelContainer(for: ReveriePlaylist.self, ReverieTrack.self)
        )
    )
}
