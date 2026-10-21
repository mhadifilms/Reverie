//
//  ImportPlaylistSheet.swift
//  Reverie
//
//  Paste a Spotify link, parse it in LibraryViewModel, hand off to the
//  SpotifyImportReviewView for track-match confirmation. Canopy-styled on
//  both platforms — matches the typography, palette, and button styles
//  used by Library / Search / Settings so the sheet doesn't feel bolted-on.
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
        content
            .background(CanopyTheme.Palette.paper.ignoresSafeArea())
            .focusedValue(\.textInputActive, isTextFieldFocused)
            .onAppear { isTextFieldFocused = true }
            #if os(macOS)
            .frame(minWidth: 520, idealWidth: 560, minHeight: 380, idealHeight: 440)
            #endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: CanopyTheme.Space.xl) {
            header
            urlField
            if let err = viewModel.importError {
                errorBanner(err)
            }
            Spacer(minLength: 0)
            actionRow
        }
        .padding(.horizontal, CanopyTheme.Space.xxl)
        .padding(.top, CanopyTheme.Space.xxl)
        .padding(.bottom, CanopyTheme.Space.xl)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(CanopyTheme.Palette.mintVeil)
                        .frame(width: 40, height: 40)
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CanopyTheme.Palette.greenDeep)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from Spotify")
                        .font(CanopyTheme.Typography.title)
                        .foregroundStyle(CanopyTheme.Palette.ink)
                    Text("Paste a playlist or album link. We'll match each track to YouTube.")
                        .font(CanopyTheme.Typography.caption)
                        .foregroundStyle(CanopyTheme.Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - URL field

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spotify link")
                .font(CanopyTheme.Typography.micro)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(CanopyTheme.Palette.muted)

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CanopyTheme.Palette.faint)

                TextField(
                    "https://open.spotify.com/playlist/… or /album/…",
                    text: $playlistURL
                )
                .textFieldStyle(.plain)
                .font(CanopyTheme.Typography.body)
                .foregroundStyle(CanopyTheme.Palette.ink)
                .focused($isTextFieldFocused)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .submitLabel(.go)
                #endif
                .onSubmit {
                    if isValidURL && !viewModel.isImporting { startImport() }
                }
                .accessibilityLabel("Spotify URL")

                if !playlistURL.isEmpty {
                    Button {
                        playlistURL = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(CanopyTheme.Palette.faint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear URL")
                }
            }
            .frame(height: 44)
            .padding(.horizontal, CanopyTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.md, style: .continuous)
                    .fill(CanopyTheme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.md, style: .continuous)
                    .strokeBorder(
                        isTextFieldFocused
                            ? CanopyTheme.Palette.green.opacity(0.6)
                            : CanopyTheme.Palette.hair,
                        lineWidth: isTextFieldFocused ? 1 : 0.5
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: isTextFieldFocused)

            Button {
                pasteFromClipboard()
            } label: {
                Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                    .font(CanopyTheme.Typography.captionEmphasized)
                    .foregroundStyle(CanopyTheme.Palette.green)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste URL from clipboard")
        }
    }

    // MARK: - Error

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(Color(red: 0.75, green: 0.28, blue: 0.22))
            Text(message)
                .font(CanopyTheme.Typography.caption)
                .foregroundStyle(CanopyTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.96, green: 0.88, blue: 0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(red: 0.80, green: 0.55, blue: 0.48).opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.canopyLight)
            .disabled(viewModel.isImporting)
            .accessibilityLabel("Cancel import")
            .keyboardShortcut(.cancelAction)

            Spacer(minLength: 0)

            Button {
                startImport()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                    Text(importButtonTitle)
                }
            }
            .buttonStyle(.canopyPrimary)
            .disabled(!isValidURL || viewModel.isImporting)
            .accessibilityLabel(importButtonTitle)
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Helpers

    private var importButtonTitle: String {
        isAlbumURL ? "Import album" : "Import playlist"
    }

    private var isAlbumURL: Bool {
        playlistURL.contains("/album/") || playlistURL.hasPrefix("spotify:album:")
    }

    private var isValidURL: Bool {
        playlistURL.contains("spotify.com/playlist/") ||
        playlistURL.contains("spotify.com/album/") ||
        playlistURL.hasPrefix("spotify:playlist:") ||
        playlistURL.hasPrefix("spotify:album:")
    }

    private func startImport() {
        Task {
            await viewModel.parsePlaylistForReview(url: playlistURL)
            if viewModel.parsedPlaylistData != nil {
                dismiss()
            }
        }
    }

    private func pasteFromClipboard() {
        #if os(macOS)
        if let pasted = NSPasteboard.general.string(forType: .string) {
            playlistURL = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #elseif canImport(UIKit)
        if let pasted = UIPasteboard.general.string {
            playlistURL = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
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
