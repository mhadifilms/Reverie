//
//  CreatePlaylistSheet.swift
//  Reverie
//
//  Name-your-playlist modal. Canopy-styled to match the Import sheet so
//  the two entry points into the Add menu read as one design language.
//

import SwiftUI
import SwiftData

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let modelContext: ModelContext

    @State private var playlistName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CanopyTheme.Space.xl) {
            header
            nameField
            Spacer(minLength: 0)
            actionRow
        }
        .padding(.horizontal, CanopyTheme.Space.xxl)
        .padding(.top, CanopyTheme.Space.xxl)
        .padding(.bottom, CanopyTheme.Space.xl)
        .background(CanopyTheme.Palette.paper.ignoresSafeArea())
        .focusedValue(\.textInputActive, isTextFieldFocused)
        .onAppear { isTextFieldFocused = true }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 280, idealHeight: 320)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(CanopyTheme.Palette.mintVeil)
                    .frame(width: 40, height: 40)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CanopyTheme.Palette.greenDeep)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("New playlist")
                    .font(CanopyTheme.Typography.title)
                    .foregroundStyle(CanopyTheme.Palette.ink)
                Text("Give it a name you'll recognise later.")
                    .font(CanopyTheme.Typography.caption)
                    .foregroundStyle(CanopyTheme.Palette.muted)
            }
        }
    }

    // MARK: - Name field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name")
                .font(CanopyTheme.Typography.micro)
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(CanopyTheme.Palette.muted)

            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CanopyTheme.Palette.faint)

                TextField("My playlist", text: $playlistName)
                    .textFieldStyle(.plain)
                    .font(CanopyTheme.Typography.body)
                    .foregroundStyle(CanopyTheme.Palette.ink)
                    .focused($isTextFieldFocused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    #endif
                    .onSubmit {
                        if isValidName { createPlaylist() }
                    }
                    .accessibilityLabel("Playlist name")
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
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .buttonStyle(.canopyLight)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Cancel creating playlist")

            Spacer(minLength: 0)

            Button {
                createPlaylist()
            } label: {
                Label("Create playlist", systemImage: "plus")
            }
            .buttonStyle(.canopyPrimary)
            .disabled(!isValidName)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Create playlist")
        }
    }

    // MARK: - Helpers

    private var isValidName: Bool {
        !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let playlist = ReveriePlaylist(name: trimmedName, isCustom: true)
        modelContext.insert(playlist)
        try? modelContext.save()
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
