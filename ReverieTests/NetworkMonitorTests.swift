//
//  NetworkMonitorTests.swift
//  ReverieTests
//
//  Phase 5D: Unit tests for NetworkMonitor computed property logic
//

import Testing
import Foundation
@testable import Reverie

/// Tests the NetworkMonitor computed properties (canDownload, canStream, statusDescription)
/// by directly manipulating the shared instance's observable state.
/// Note: These tests use the singleton so they run serially to avoid state interference.
@MainActor
struct NetworkMonitorTests {

    // MARK: - Helpers

    /// Saves and restores UserDefaults state around each test scenario.
    private func withNetworkState(
        isConnected: Bool,
        isWiFi: Bool,
        isCellular: Bool,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        allowCellularDownloads: Bool = false,
        allowCellularStreaming: Bool = true,
        body: (NetworkMonitor) -> Void
    ) {
        let monitor = NetworkMonitor.shared

        // Save original state
        let origConnected = monitor.isConnected
        let origWiFi = monitor.isWiFi
        let origCellular = monitor.isCellular
        let origExpensive = monitor.isExpensive
        let origConstrained = monitor.isConstrained

        // Apply test state
        monitor.isConnected = isConnected
        monitor.isWiFi = isWiFi
        monitor.isCellular = isCellular
        monitor.isExpensive = isExpensive
        monitor.isConstrained = isConstrained

        // Set user preferences
        UserDefaults.standard.set(allowCellularDownloads, forKey: "allowCellularDownloads")
        UserDefaults.standard.set(allowCellularStreaming, forKey: "allowCellularStreaming")
        UserDefaults.standard.set(true, forKey: "cellularStreamingSet")

        body(monitor)

        // Restore original state
        monitor.isConnected = origConnected
        monitor.isWiFi = origWiFi
        monitor.isCellular = origCellular
        monitor.isExpensive = origExpensive
        monitor.isConstrained = origConstrained
    }

    // MARK: - canDownload

    @Test func canDownloadOnWiFi() {
        withNetworkState(isConnected: true, isWiFi: true, isCellular: false) { monitor in
            #expect(monitor.canDownload == true)
        }
    }

    @Test func canDownloadOnCellularAllowed() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: true, allowCellularDownloads: true) { monitor in
            #expect(monitor.canDownload == true)
        }
    }

    @Test func cannotDownloadOnCellularDenied() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: true, allowCellularDownloads: false) { monitor in
            #expect(monitor.canDownload == false)
        }
    }

    @Test func cannotDownloadOffline() {
        withNetworkState(isConnected: false, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.canDownload == false)
        }
    }

    @Test func canDownloadOnOtherConnected() {
        // e.g. ethernet — not WiFi, not cellular, but connected
        withNetworkState(isConnected: true, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.canDownload == true)
        }
    }

    // MARK: - canStream

    @Test func canStreamOnWiFi() {
        withNetworkState(isConnected: true, isWiFi: true, isCellular: false) { monitor in
            #expect(monitor.canStream == true)
        }
    }

    @Test func canStreamOnCellularAllowed() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: true, allowCellularStreaming: true) { monitor in
            #expect(monitor.canStream == true)
        }
    }

    @Test func cannotStreamOnCellularDenied() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: true, allowCellularStreaming: false) { monitor in
            #expect(monitor.canStream == false)
        }
    }

    @Test func cannotStreamOffline() {
        withNetworkState(isConnected: false, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.canStream == false)
        }
    }

    @Test func canStreamOnOtherConnected() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: false, allowCellularStreaming: false) { monitor in
            // Not WiFi, not cellular, but connected — should allow
            #expect(monitor.canStream == true)
        }
    }

    // MARK: - canMakeRequests

    @Test func canMakeRequestsWhenConnected() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.canMakeRequests == true)
        }
    }

    @Test func cannotMakeRequestsOffline() {
        withNetworkState(isConnected: false, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.canMakeRequests == false)
        }
    }

    // MARK: - Legacy Aliases

    @Test func legacyAliasesMatchComputed() {
        withNetworkState(isConnected: true, isWiFi: true, isCellular: false) { monitor in
            #expect(monitor.shouldAllowBackgroundDownload == monitor.canDownload)
            #expect(monitor.shouldAllowStreaming == monitor.canStream)
        }
    }

    // MARK: - statusDescription

    @Test func statusDescriptionOffline() {
        withNetworkState(isConnected: false, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.statusDescription == "Offline")
        }
    }

    @Test func statusDescriptionWiFi() {
        withNetworkState(isConnected: true, isWiFi: true, isCellular: false) { monitor in
            #expect(monitor.statusDescription == "Wi-Fi")
        }
    }

    @Test func statusDescriptionCellular() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: true) { monitor in
            #expect(monitor.statusDescription == "Cellular")
        }
    }

    @Test func statusDescriptionOtherConnected() {
        withNetworkState(isConnected: true, isWiFi: false, isCellular: false) { monitor in
            #expect(monitor.statusDescription == "Connected")
        }
    }

    // MARK: - Combined Scenarios

    @Test func wifiOverridesCellularFlags() {
        // Both WiFi and cellular set (unlikely but defensive)
        withNetworkState(isConnected: true, isWiFi: true, isCellular: true, allowCellularDownloads: false) { monitor in
            // WiFi check comes first, so downloads should be allowed
            #expect(monitor.canDownload == true)
            #expect(monitor.canStream == true)
            #expect(monitor.statusDescription == "Wi-Fi")
        }
    }

    @Test func offlineOverridesEverything() {
        withNetworkState(isConnected: false, isWiFi: true, isCellular: true, allowCellularDownloads: true, allowCellularStreaming: true) { monitor in
            #expect(monitor.canDownload == false)
            #expect(monitor.canStream == false)
            #expect(monitor.canMakeRequests == false)
            #expect(monitor.statusDescription == "Offline")
        }
    }
}
