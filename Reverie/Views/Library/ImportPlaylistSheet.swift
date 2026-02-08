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
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
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
                    Task {
                        await viewModel.parsePlaylistForReview(url: playlistURL)
                        if viewModel.parsedPlaylistData != nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isImporting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(playlistURL.contains("/album/") ? "Import Album" : "Import Playlist")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidURL ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValidURL || viewModel.isImporting)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isImporting)
                }
            }
            .onAppear {
                isTextFieldFocused = true
            }
        }
    }
    
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
