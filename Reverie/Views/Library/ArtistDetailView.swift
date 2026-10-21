//
//  ArtistDetailView.swift
//  Reverie
//
//  Lightweight artist sheet — lists every library track by an artist name,
//  sourced from the SwiftData @Query. Tapping a row plays via the shared
//  AudioPlayer so the unified local-or-stream path is respected.
//

import SwiftUI
import SwiftData

struct ArtistDetailView: View {
    let artistName: String
    let audioPlayer: AudioPlayer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tracks: [ReverieTrack]

    init(artistName: String, audioPlayer: AudioPlayer) {
        self.artistName = artistName
        self.audioPlayer = audioPlayer
        // #Predicate captures artistName at init time — SwiftData recompiles
        // the predicate so this is the correct pattern for a parameterised query.
        let target = artistName
        _tracks = Query(
            filter: #Predicate<ReverieTrack> { $0.artist == target },
            sort: [SortDescriptor(\ReverieTrack.title)]
        )
    }

    private var downloadedCount: Int {
        tracks.filter { $0.downloadState == .downloaded }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if tracks.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(tracks) { track in
                                trackRow(track)
                                Divider().opacity(0.08)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(artistName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "person.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(artistName)
                    .font(.title3.bold())
                    .lineLimit(1)
                let totalText = tracks.count == 1 ? "1 song" : "\(tracks.count) songs"
                Text("\(totalText) · \(downloadedCount) downloaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No songs by \(artistName) in your library yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func trackRow(_ track: ReverieTrack) -> some View {
        Button {
            Task {
                await audioPlayer.playTrack(track, modelContext: modelContext)
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                AlbumArtView(imageData: track.albumArtData, size: 44, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if track.downloadState == .downloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Downloaded")
                }

                if track.durationSeconds > 0 {
                    Text(track.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.title)")
        .accessibilityHint("Play")
    }
}
