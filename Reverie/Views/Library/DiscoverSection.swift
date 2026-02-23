//
//  DiscoverSection.swift
//  Reverie
//
//  Horizontal card carousel of personalized music recommendations.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct DiscoverSection: View {
    @Environment(\.modelContext) private var modelContext
    let audioPlayer: AudioPlayer

    @State private var recommendations: [RecommendedTrack] = []
    @State private var isLoading = false
    @State private var isCollapsed = false
    @State private var selectedTrack: RecommendedTrack?

    @AppStorage("tuningPrompt") private var tuningPrompt = ""

    private let engine = RecommendationEngine()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if !isCollapsed {
                if isLoading {
                    loadingView
                } else if recommendations.isEmpty {
                    emptyStateView
                } else {
                    carouselView
                }
            }
        }
        .task {
            await loadRecommendations()
        }
        .sheet(item: $selectedTrack) { track in
            DiscoverTrackSheet(track: track, audioPlayer: audioPlayer)
                #if os(iOS)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                #endif
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Discover")
                .font(.title2.bold())

            Spacer()

            Button {
                Task { await loadRecommendations() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel("Refresh recommendations")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed ? "Expand Discover" : "Collapse Discover")
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                Text("Finding music for you...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "waveform.and.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Listen to more music to get personalized recommendations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    // MARK: - Carousel

    private var carouselView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(recommendations) { track in
                    DiscoverCard(track: track)
                        .onTapGesture {
                            selectedTrack = track
                        }
                        .accessibilityLabel("\(track.title) by \(track.artist)")
                        .accessibilityHint("Double tap for options")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Data Loading

    func loadRecommendations() async {
        isLoading = true
        let filters = TuningParser.parse(tuningPrompt)
        let results = await engine.generateRecommendations(
            modelContext: modelContext,
            tuningFilters: filters
        )
        recommendations = results
        isLoading = false
    }
}

// MARK: - Discover Card

private struct DiscoverCard: View {
    let track: RecommendedTrack

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                AsyncImage(url: track.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderImage
                    case .empty:
                        placeholderImage
                            .overlay {
                                ProgressView()
                            }
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "music.note")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Discover Track Sheet

struct DiscoverTrackSheet: View {
    let track: RecommendedTrack
    let audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isDownloading = false
    @State private var downloadComplete = false

    private let searchViewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Thumbnail
                AsyncImage(url: track.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    default:
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }

                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title3.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(track.artist)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    if downloadComplete {
                        Label("Downloaded", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await downloadTrack() }
                        } label: {
                            Label(
                                isDownloading ? "Downloading..." : "Download",
                                systemImage: isDownloading ? "arrow.down.circle" : "arrow.down.to.line"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isDownloading)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Recommended")
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

    private func downloadTrack() async {
        isDownloading = true
        await searchViewModel.downloadTrack(videoID: track.videoID, modelContext: modelContext)
        isDownloading = false
        downloadComplete = true
    }
}
