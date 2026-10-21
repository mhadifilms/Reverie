//
//  ReverieApp.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
import SwiftData

@main
struct ReverieApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ReveriePlaylist.self,
            ReverieTrack.self,
            ReverieArtist.self,
            ReverieAlbum.self,
            ListeningSignal.self,
        ])

        // Configure iCloud sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // Enable iCloud sync
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var sharedAudioPlayer = AudioPlayer()
    #if os(macOS)
    @AppStorage("showMenuBarPlayer") private var showMenuBarPlayer = false
    #endif

    init() {
        // Expose the container to background task handlers which run outside
        // the SwiftUI environment and otherwise have no way to reach SwiftData.
        BackgroundTaskManager.sharedModelContainer = sharedModelContainer

        // Register background tasks (iOS only)
        #if os(iOS)
        BackgroundTaskManager.shared.registerBackgroundTasks()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(audioPlayer: sharedAudioPlayer)
                .onReceive(NotificationCenter.default.publisher(for: scenePhaseNotification)) { _ in
                    // Schedule background tasks when going to background
                    #if os(iOS)
                    BackgroundTaskManager.shared.scheduleMetadataRefresh()
                    #endif
                }
                // Handoff: resume playback handed off from another device running
                // Reverie. AudioPlayer publishes a "com.reverie.playback" activity
                // containing the trackID; we fetch the local match and continue.
                .onContinueUserActivity("com.reverie.playback") { activity in
                    guard let info = activity.userInfo,
                          let trackIDString = info["trackID"] as? String,
                          let trackID = UUID(uuidString: trackIDString) else {
                        return
                    }
                    let elapsed = info["currentTime"] as? Double ?? 0
                    let wasPlaying = info["isPlaying"] as? Bool ?? false
                    let context = sharedModelContainer.mainContext

                    let descriptor = FetchDescriptor<ReverieTrack>(
                        predicate: #Predicate { $0.id == trackID }
                    )
                    guard let tracks = try? context.fetch(descriptor),
                          let track = tracks.first else { return }

                    Task { @MainActor in
                        let ok = await sharedAudioPlayer.playTrack(track, modelContext: context)
                        if ok {
                            if elapsed > 0 { sharedAudioPlayer.seek(to: elapsed) }
                            if !wasPlaying { sharedAudioPlayer.pause() }
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            ReverieCommands()
            #if os(macOS)
            SidebarCommands()
            ToolbarCommands()
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }

        MenuBarExtra("Reverie", systemImage: "music.note", isInserted: $showMenuBarPlayer) {
            MenuBarPlayerView(player: sharedAudioPlayer, accentColor: .accentColor)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    #if os(iOS)
    private var scenePhaseNotification: Notification.Name {
        UIApplication.didEnterBackgroundNotification
    }
    #else
    private var scenePhaseNotification: Notification.Name {
        // macOS: no background task scheduling needed
        NSApplication.didResignActiveNotification
    }
    #endif
}
