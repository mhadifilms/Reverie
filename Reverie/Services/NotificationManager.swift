//
//  NotificationManager.swift
//  Reverie
//
//  Thin wrapper over UNUserNotificationCenter. Requests authorization the
//  first time something actually wants to notify the user (first download
//  completion, download failure), and posts local notifications if the app
//  is backgrounded. Lazy-auth avoids nagging fresh users on first launch.
//

import Foundation
import UserNotifications
import OSLog
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
final class NotificationManager {

    static let shared = NotificationManager()

    private let logger = Logger(subsystem: "com.reverie", category: "notifications")

    /// Tri-state auth cache. `nil` means "never asked yet".
    private var authorized: Bool?

    private init() {}

    // MARK: - Authorization

    /// Requests notification authorization. Called lazily before any post().
    /// Returns true if the user has granted (now or previously) permission.
    @discardableResult
    func ensureAuthorization() async -> Bool {
        if let authorized { return authorized }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorized = true
            return true
        case .denied:
            authorized = false
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                authorized = granted
                return granted
            } catch {
                logger.error("Auth request failed: \(error.localizedDescription, privacy: .public)")
                authorized = false
                return false
            }
        @unknown default:
            authorized = false
            return false
        }
    }

    // MARK: - Posting

    /// Posts a local "download complete" notification, but only when the app
    /// is NOT in the foreground — in-app error banner already covers that case.
    func notifyDownloadComplete(trackTitle: String) async {
        guard !isForeground else { return }
        guard await ensureAuthorization() else { return }
        await post(
            id: "download-complete-\(UUID().uuidString)",
            title: "Saved to library",
            body: trackTitle
        )
    }

    /// Posts a local failure notification. Foreground is covered by the
    /// in-app banner, so we skip duplicates there.
    func notifyError(title: String, message: String) async {
        guard !isForeground else { return }
        guard await ensureAuthorization() else { return }
        await post(
            id: "error-\(UUID().uuidString)",
            title: title,
            body: message
        )
    }

    // MARK: - Helpers

    private func post(id: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.debug("Notification add failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var isForeground: Bool {
        #if canImport(UIKit)
        return UIApplication.shared.applicationState == .active
        #elseif canImport(AppKit)
        return NSApplication.shared.isActive
        #else
        return true
        #endif
    }
}
