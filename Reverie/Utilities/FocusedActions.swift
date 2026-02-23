//
//  FocusedActions.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI

struct NewPlaylistActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ImportPlaylistActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct FocusSearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct PlayPauseActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct NextTrackActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct PreviousTrackActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ToggleLyricsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct ToggleNowPlayingActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct TextInputActiveKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var newPlaylistAction: (() -> Void)? {
        get { self[NewPlaylistActionKey.self] }
        set { self[NewPlaylistActionKey.self] = newValue }
    }
    
    var importPlaylistAction: (() -> Void)? {
        get { self[ImportPlaylistActionKey.self] }
        set { self[ImportPlaylistActionKey.self] = newValue }
    }
    
    var focusSearchAction: (() -> Void)? {
        get { self[FocusSearchActionKey.self] }
        set { self[FocusSearchActionKey.self] = newValue }
    }
    
    var playPauseAction: (() -> Void)? {
        get { self[PlayPauseActionKey.self] }
        set { self[PlayPauseActionKey.self] = newValue }
    }
    
    var nextTrackAction: (() -> Void)? {
        get { self[NextTrackActionKey.self] }
        set { self[NextTrackActionKey.self] = newValue }
    }
    
    var previousTrackAction: (() -> Void)? {
        get { self[PreviousTrackActionKey.self] }
        set { self[PreviousTrackActionKey.self] = newValue }
    }
    
    var toggleLyricsAction: (() -> Void)? {
        get { self[ToggleLyricsActionKey.self] }
        set { self[ToggleLyricsActionKey.self] = newValue }
    }

    var toggleNowPlayingAction: (() -> Void)? {
        get { self[ToggleNowPlayingActionKey.self] }
        set { self[ToggleNowPlayingActionKey.self] = newValue }
    }

    var textInputActive: Bool? {
        get { self[TextInputActiveKey.self] }
        set { self[TextInputActiveKey.self] = newValue }
    }
}
