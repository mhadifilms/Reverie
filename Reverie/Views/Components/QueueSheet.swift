//
//  QueueSheet.swift
//  Reverie
//
//  Phase 4A: Queue management half-sheet for the full player.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct QueueSheet: View {
    @Bindable var player: AudioPlayer
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    #if !os(macOS)
    @State private var editMode: EditMode = .inactive
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if player.playbackQueue.tracks.isEmpty {
                    emptyState
                } else {
                    queueList
                }
            }
            .navigationTitle("Up Next")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #if !os(macOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
            }
            #if !os(macOS)
            .environment(\.editMode, $editMode)
            #endif
            .tint(accentColor)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Queue", systemImage: "music.note.list")
        } description: {
            Text("Play a track or playlist to build a queue.")
        }
    }

    private var queueList: some View {
        List {
            // Now Playing
            if let currentIndex = currentPlayingIndex {
                Section("Now Playing") {
                    queueRow(for: player.playbackQueue.tracks[currentIndex], index: currentIndex, isCurrent: true)
                }
            }

            // Up Next
            let upNextTracks = upNextIndices
            if !upNextTracks.isEmpty {
                Section("Up Next") {
                    ForEach(upNextTracks, id: \.self) { index in
                        queueRow(for: player.playbackQueue.tracks[index], index: index, isCurrent: false)
                    }
                    .onMove { source, destination in
                        handleMove(source: source, destination: destination)
                    }
                    .onDelete { offsets in
                        handleDelete(offsets: offsets)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
    }

    private func queueRow(for track: ReverieTrack, index: Int, isCurrent: Bool) -> some View {
        Button {
            if !isCurrent {
                if let jumpedTrack = player.playbackQueue.jumpTo(index: index) {
                    Task {
                        try? await player.loadTrack(jumpedTrack)
                        player.play()
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Album art thumbnail
                queueArtwork(for: track)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? accentColor : .primary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isCurrent && player.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func queueArtwork(for track: ReverieTrack) -> some View {
        Group {
            if let imageData = track.albumArtData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    artworkPlaceholder
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    artworkPlaceholder
                }
                #endif
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Index Helpers

    private var currentPlayingIndex: Int? {
        let idx = player.playbackQueue.currentIndex
        guard idx >= 0 && idx < player.playbackQueue.tracks.count else { return nil }
        return idx
    }

    private var upNextIndices: [Int] {
        guard let current = currentPlayingIndex else {
            return Array(player.playbackQueue.tracks.indices)
        }
        let start = current + 1
        guard start < player.playbackQueue.tracks.count else { return [] }
        return Array(start..<player.playbackQueue.tracks.count)
    }

    // MARK: - Actions

    private func handleMove(source: IndexSet, destination: Int) {
        let upNext = upNextIndices
        guard let sourceFirst = source.first,
              sourceFirst < upNext.count else { return }

        let actualSource = upNext[sourceFirst]
        let actualDestination: Int
        if destination < upNext.count {
            actualDestination = upNext[destination]
        } else {
            actualDestination = player.playbackQueue.tracks.count - 1
        }

        player.playbackQueue.move(from: actualSource, to: actualDestination)
    }

    private func handleDelete(offsets: IndexSet) {
        let upNext = upNextIndices
        // Delete in reverse order to avoid index shifting
        let indicesToRemove = offsets.map { upNext[$0] }.sorted(by: >)
        for index in indicesToRemove {
            player.playbackQueue.remove(at: index)
        }
    }
}
