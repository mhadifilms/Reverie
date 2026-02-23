//
//  ReverieFocusFilter.swift
//  Reverie
//
//  Created by Claude on 2/7/26.
//

#if canImport(AppIntents)
import AppIntents
import SwiftUI

// MARK: - Focus Filter

@available(iOS 16.0, macOS 13.0, *)
struct ReverieFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Reverie Playback"
    static var description = IntentDescription("Control music playback during Focus modes")
    
    @Parameter(title: "Enable Playback", default: true)
    var enablePlayback: Bool
    
    @Parameter(title: "Only Downloaded Music", default: true)
    var onlyDownloaded: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("Control playback: \(\.$enablePlayback), downloaded only: \(\.$onlyDownloaded)")
    }
    
    var displayRepresentation: DisplayRepresentation {
        var subtitle = ""
        if !enablePlayback {
            subtitle = "Playback disabled"
        } else if onlyDownloaded {
            subtitle = "Downloaded music only"
        } else {
            subtitle = "All music allowed"
        }
        
        return DisplayRepresentation(
            title: "Reverie",
            subtitle: "\(subtitle)"
        )
    }
    
    var appContext: FocusFilterAppContext {
        // Return empty app context since we're not filtering notifications
        FocusFilterAppContext()
    }
    
    func perform() async throws -> some IntentResult {
        // Store focus filter preferences
        let defaults = UserDefaults.standard
        defaults.set(enablePlayback, forKey: "focusFilter.enablePlayback")
        defaults.set(onlyDownloaded, forKey: "focusFilter.onlyDownloaded")
        
        if !enablePlayback {
            // Pause playback when focus mode doesn't allow it
            NotificationCenter.default.post(name: Notification.Name("PauseForFocus"), object: nil)
        }
        
        return .result()
    }
}

// MARK: - Focus Filter View Model

@MainActor
@Observable
class FocusFilterViewModel {
    var isPlaybackAllowed: Bool {
        UserDefaults.standard.bool(forKey: "focusFilter.enablePlayback")
    }
    
    var onlyDownloadedDuringFocus: Bool {
        UserDefaults.standard.bool(forKey: "focusFilter.onlyDownloaded")
    }
    
    func checkFocusStatus() -> Bool {
        // Check if current Focus mode allows playback
        return isPlaybackAllowed
    }
}

#endif
