//
//  BackgroundTaskManager.swift
//  Reverie
//
//  Phase 5C: Background task registration and handling
//

import Foundation
import OSLog
import SwiftData
#if os(iOS)
import BackgroundTasks
#endif

/// Manages background tasks for metadata enrichment and quality re-downloads
@MainActor
final class BackgroundTaskManager {

    static let shared = BackgroundTaskManager()

    private let logger = Logger(subsystem: "com.reverie", category: "background")

    // Task identifiers
    static let metadataRefreshID = "com.reverie.metadata.refresh"
    static let qualityRedownloadID = "com.reverie.quality.redownload"

    private init() {}

    // MARK: - Registration

    /// Registers all background tasks. Call from app launch.
    func registerBackgroundTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.metadataRefreshID,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleMetadataRefresh(task: task as! BGAppRefreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.qualityRedownloadID,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleQualityRedownload(task: task as! BGProcessingTask)
            }
        }

        logger.info("Background tasks registered")
        #endif
    }

    // MARK: - Scheduling

    /// Schedules the metadata refresh task (runs on Wi-Fi)
    func scheduleMetadataRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: Self.metadataRefreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour from now

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled metadata refresh")
        } catch {
            logger.error("Failed to schedule metadata refresh: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    /// Schedules the quality re-download task (requires Wi-Fi + charging)
    func scheduleQualityRedownload() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: Self.qualityRedownloadID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 30) // 30 min from now

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Scheduled quality re-download")
        } catch {
            logger.error("Failed to schedule quality re-download: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    // MARK: - Task Handlers

    #if os(iOS)
    private func handleMetadataRefresh(task: BGAppRefreshTask) async {
        logger.info("Starting background metadata refresh")

        // Always schedule the next run FIRST so a crash/expiry doesn't stop
        // the background loop.
        scheduleMetadataRefresh()

        guard NetworkMonitor.shared.isConnected else {
            task.setTaskCompleted(success: false)
            return
        }

        // Hold a work item we can cancel when the system expires us. Task
        // is a value type, so the expiration handler captures it by copy —
        // cancelling the copy cancels the underlying task.
        let work = Task { [weak self] in
            guard let self = self,
                  let container = Self.sharedModelContainer else { return }
            let context = container.mainContext
            let resolver = MetadataResolver()
            await resolver.enrichIncompleteRecords(modelContext: context, limit: 20)
            self.logger.info("Background metadata refresh pass complete")
        }

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }

        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }

    private func handleQualityRedownload(task: BGProcessingTask) async {
        logger.info("Starting background quality re-download")

        scheduleQualityRedownload()

        guard NetworkMonitor.shared.isWiFi else {
            task.setTaskCompleted(success: false)
            return
        }

        let work = Task { [weak self] in
            guard let self = self,
                  let container = Self.sharedModelContainer else { return }
            let context = container.mainContext
            let manager = DownloadManager()
            await manager.redownloadAll(at: AudioQualityTier.current, modelContext: context)
            self.logger.info("Background quality re-download pass complete")
        }

        task.expirationHandler = {
            // Cancellation here stops the Task; the DownloadManager's own
            // retry/back-off loop also respects Task.cancel().
            work.cancel()
            task.setTaskCompleted(success: false)
        }

        await work.value
        task.setTaskCompleted(success: !work.isCancelled)
    }
    #endif

    // MARK: - Shared Model Container Access
    //
    // Background task handlers run in a fresh @MainActor context without
    // access to the SwiftUI-injected modelContainer. ReverieApp sets this
    // during app init so background tasks can reach SwiftData.
    static var sharedModelContainer: ModelContainer?
}
