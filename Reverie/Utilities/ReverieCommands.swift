//
//  ReverieCommands.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI

struct ReverieCommands: Commands {
    @FocusedValue(\.newPlaylistAction) private var newPlaylistAction
    @FocusedValue(\.importPlaylistAction) private var importPlaylistAction
    @FocusedValue(\.focusSearchAction) private var focusSearchAction
    @FocusedValue(\.playPauseAction) private var playPauseAction
    @FocusedValue(\.nextTrackAction) private var nextTrackAction
    @FocusedValue(\.previousTrackAction) private var previousTrackAction
    @FocusedValue(\.toggleLyricsAction) private var toggleLyricsAction
    @FocusedValue(\.toggleNowPlayingAction) private var toggleNowPlayingAction
    @FocusedValue(\.textInputActive) private var textInputActive

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Playlist") {
                newPlaylistAction?()
            }
            .keyboardShortcut("n", modifiers: [.command])
            .disabled(newPlaylistAction == nil)
        }

        CommandGroup(after: .importExport) {
            Button("Import Spotify Playlist\u{2026}") {
                importPlaylistAction?()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(importPlaylistAction == nil)
        }

        CommandGroup(after: .textEditing) {
            Button("Find") {
                focusSearchAction?()
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(focusSearchAction == nil)
        }

        CommandMenu("Playback") {
            Button("Play/Pause") {
                playPauseAction?()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(playPauseAction == nil || textInputActive == true)

            Button("Next Track") {
                nextTrackAction?()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(nextTrackAction == nil)

            Button("Previous Track") {
                previousTrackAction?()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(previousTrackAction == nil)

            Divider()

            Button("Toggle Lyrics") {
                toggleLyricsAction?()
            }
            .keyboardShortcut("l", modifiers: [.command])
            .disabled(toggleLyricsAction == nil)

            Button("Toggle Now Playing") {
                toggleNowPlayingAction?()
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(toggleNowPlayingAction == nil)
        }
    }
}
