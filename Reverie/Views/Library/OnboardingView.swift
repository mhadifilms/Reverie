//
//  OnboardingView.swift
//  Reverie
//
//  One-time taste onboarding. Two screens — genres then artists — that
//  seed RecommendationEngine's cold-start path. Skippable: if the user
//  skips, we fall back to the hardcoded coldStartSeeds.
//
//  Writes to UserDefaults:
//    onboarding.genres  — [String]
//    onboarding.artists — [String]
//    onboarding.completed — Bool
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboarding.completed") private var completed = false

    @State private var step: Step = .welcome
    @State private var pickedGenres: Set<String> = []
    @State private var pickedArtists: Set<String> = []

    enum Step { case welcome, genres, artists, done }

    // Curated genre tiles. Each one doubles as a search query seed for the
    // recommendation engine, so we pick broadly-recognised labels.
    private let genres: [GenreTile] = [
        .init(name: "Indie", hues: [Color(hex: 0x4A5A4B), Color(hex: 0xD6D8C9)]),
        .init(name: "Lo-fi", hues: [Color(hex: 0x8A6A4B), Color(hex: 0xE8DFC9)]),
        .init(name: "Hip-hop", hues: [Color(hex: 0x1A1A1A), Color(hex: 0x5A4A5A)]),
        .init(name: "Pop", hues: [Color(hex: 0xC94A6C), Color(hex: 0xF2C4D8)]),
        .init(name: "Rock", hues: [Color(hex: 0x2A2A2A), Color(hex: 0x7A4A4A)]),
        .init(name: "Electronic", hues: [Color(hex: 0x083D48), Color(hex: 0x4FC7A7)]),
        .init(name: "Jazz", hues: [Color(hex: 0x2A2A2A), Color(hex: 0x6A5A4A)]),
        .init(name: "Classical", hues: [Color(hex: 0x075057), Color(hex: 0x84A8BE)]),
        .init(name: "R&B", hues: [Color(hex: 0x4A1E3A), Color(hex: 0xB57BA0)]),
        .init(name: "Ambient", hues: [Color(hex: 0x1A5140), Color(hex: 0x5FB98F)]),
        .init(name: "Folk", hues: [Color(hex: 0x5A7A4A), Color(hex: 0xC6E5D2)]),
        .init(name: "Country", hues: [Color(hex: 0x7A5A3A), Color(hex: 0xD9BE8C)]),
        .init(name: "Metal", hues: [Color(hex: 0x111111), Color(hex: 0x444444)]),
        .init(name: "World", hues: [Color(hex: 0x8A6A3B), Color(hex: 0xE8C97B)])
    ]

    // Lightweight artist list — just names — used only as seeds for
    // familiarity scoring. A real app would pull these from a live feed;
    // for launch a curated cross-genre list is enough to get a varied
    // first-session rail without nagging a popular-artists API on first run.
    private let artists: [String] = [
        "Taylor Swift", "The Weeknd", "Drake", "Billie Eilish", "Kendrick Lamar",
        "Arctic Monkeys", "Tame Impala", "Radiohead", "Mac DeMarco", "Clairo",
        "Kanye West", "Frank Ocean", "Tyler, The Creator", "SZA", "Bad Bunny",
        "Harry Styles", "Olivia Rodrigo", "Bon Iver", "Phoebe Bridgers", "Mitski",
        "Daft Punk", "Fred again..", "Jamie xx", "Nujabes", "J Dilla"
    ]

    var body: some View {
        ZStack {
            CanopyTheme.Palette.paper.ignoresSafeArea()
            LinearGradient(
                colors: [
                    CanopyTheme.Palette.mintVeil,
                    CanopyTheme.Palette.paper
                ],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            switch step {
            case .welcome: welcomeStep
            case .genres:  genresStep
            case .artists: artistsStep
            case .done:    doneStep
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            CanopyMark(size: 48, color: CanopyTheme.Palette.greenDeep)

            VStack(spacing: 8) {
                Text("Welcome to Reverie")
                    .font(CanopyTheme.Typography.displayTitle)
                    .foregroundStyle(CanopyTheme.Palette.ink)
                Text("A quiet place for your music.")
                    .font(CanopyTheme.Typography.heroItalic)
                    .foregroundStyle(CanopyTheme.Palette.green)
            }

            Text("Tell us what you love. We'll use it to build your home page — you can change this anytime in Settings.")
                .font(CanopyTheme.Typography.body)
                .foregroundStyle(CanopyTheme.Palette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    step = .genres
                } label: {
                    Text("Get started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.canopyPrimary(fullWidth: true))

                Button {
                    skip()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CanopyTheme.Palette.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Genres

    private var genresStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingHeader(
                step: "1 of 2",
                title: "Pick a few genres",
                subtitle: "We'll start a radio from them. Pick 3 or more."
            )

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(genres) { genre in
                        genreTile(genre)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            VStack(spacing: 10) {
                Button {
                    step = .artists
                } label: {
                    Text(pickedGenres.count >= 3 ? "Next" : "Pick \(3 - pickedGenres.count) more")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.canopyPrimary(fullWidth: true))
                .disabled(pickedGenres.count < 3)

                Button { skip() } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CanopyTheme.Palette.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func genreTile(_ genre: GenreTile) -> some View {
        Button {
            toggleGenre(genre.name)
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: genre.hues, startPoint: .topLeading, endPoint: .bottomTrailing))

                Text(genre.name)
                    .font(CanopyTheme.Typography.trackTitle)
                    .foregroundStyle(.white)
                    .padding(12)

                if pickedGenres.contains(genre.name) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 3)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(height: 84)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(genre.name)
        .accessibilityAddTraits(pickedGenres.contains(genre.name) ? .isSelected : [])
    }

    // MARK: - Artists

    private var artistsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingHeader(
                step: "2 of 2",
                title: "Any favourite artists?",
                subtitle: "We'll weight their similar-artists higher. Pick 3 or more (optional)."
            )

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(artists, id: \.self) { artist in
                        artistTile(artist)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            VStack(spacing: 10) {
                Button {
                    finish()
                } label: {
                    Text("Build my home page")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.canopyPrimary(fullWidth: true))

                Button { step = .genres } label: {
                    Text("Back")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(CanopyTheme.Palette.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    private func artistTile(_ name: String) -> some View {
        let isPicked = pickedArtists.contains(name)
        return Button {
            toggleArtist(name)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CanopyTheme.Palette.green, CanopyTheme.Palette.greenDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(name.prefix(1)))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CanopyTheme.Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: isPicked ? "checkmark.circle.fill" : "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(isPicked ? CanopyTheme.Palette.green : CanopyTheme.Palette.faint)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPicked ? CanopyTheme.Palette.mintVeil : CanopyTheme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(CanopyTheme.Palette.hair, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    // MARK: - Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(CanopyTheme.Palette.mintVeil).frame(width: 120, height: 120)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(CanopyTheme.Palette.greenDeep)
            }
            Text("Building your home page")
                .font(CanopyTheme.Typography.displayTitle)
                .foregroundStyle(CanopyTheme.Palette.ink)
            Spacer()
        }
        .onAppear {
            completed = true
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                dismiss()
            }
        }
    }

    // MARK: - Chrome

    private func onboardingHeader(step: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step)
                .font(CanopyTheme.Typography.micro)
                .tracking(0.9)
                .foregroundStyle(CanopyTheme.Palette.muted)
            Text(title)
                .font(CanopyTheme.Typography.displayTitle)
                .foregroundStyle(CanopyTheme.Palette.ink)
            Text(subtitle)
                .font(CanopyTheme.Typography.caption)
                .foregroundStyle(CanopyTheme.Palette.muted)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
    }

    // MARK: - State

    private func toggleGenre(_ name: String) {
        if pickedGenres.contains(name) {
            pickedGenres.remove(name)
        } else {
            pickedGenres.insert(name)
        }
        HapticManager.shared.tap()
    }

    private func toggleArtist(_ name: String) {
        if pickedArtists.contains(name) {
            pickedArtists.remove(name)
        } else {
            pickedArtists.insert(name)
        }
        HapticManager.shared.tap()
    }

    private func finish() {
        UserDefaults.standard.set(Array(pickedGenres), forKey: "onboarding.genres")
        UserDefaults.standard.set(Array(pickedArtists), forKey: "onboarding.artists")
        step = .done
    }

    private func skip() {
        // Record an empty onboarding so we don't show it every launch, but
        // leave the AppStorage arrays empty — the engine will fall back to
        // its generic cold-start seed set.
        completed = true
        dismiss()
    }

    private struct GenreTile: Identifiable {
        let name: String
        let hues: [Color]
        var id: String { name }
    }
}
