//
//  NetworkMonitor.swift
//  Reverie
//
//  Phase 1C: Network-aware behavior using NWPathMonitor
//

import Foundation
import Network
import OSLog

/// Observes network connectivity and exposes state for network-aware behavior
@MainActor
@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    // MARK: - Public State

    var isConnected: Bool = true
    var isWiFi: Bool = false
    var isCellular: Bool = false
    var isExpensive: Bool = false
    var isConstrained: Bool = false

    // MARK: - User Preferences (persisted)

    /// User opted in to allow downloads over cellular
    var allowCellularDownloads: Bool {
        get { UserDefaults.standard.bool(forKey: "allowCellularDownloads") }
        set { UserDefaults.standard.set(newValue, forKey: "allowCellularDownloads") }
    }

    /// User opted in to allow streaming over cellular (defaults to true)
    var allowCellularStreaming: Bool {
        get {
            if !UserDefaults.standard.bool(forKey: "cellularStreamingSet") {
                UserDefaults.standard.set(true, forKey: "allowCellularStreaming")
                UserDefaults.standard.set(true, forKey: "cellularStreamingSet")
                return true
            }
            return UserDefaults.standard.bool(forKey: "allowCellularStreaming")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "allowCellularStreaming")
            UserDefaults.standard.set(true, forKey: "cellularStreamingSet")
        }
    }

    // MARK: - Computed Helpers

    /// Whether downloading is currently allowed based on network + user prefs
    var canDownload: Bool {
        guard isConnected else { return false }
        if isWiFi { return true }
        if isCellular { return allowCellularDownloads }
        return true // other connected types (ethernet, etc.)
    }

    /// Whether streaming is currently allowed based on network + user prefs
    var canStream: Bool {
        guard isConnected else { return false }
        if isWiFi { return true }
        if isCellular { return allowCellularStreaming }
        return true
    }

    /// Whether any network request (search, import) is possible
    var canMakeRequests: Bool {
        isConnected
    }

    // Legacy aliases for backward compatibility
    var shouldAllowBackgroundDownload: Bool { canDownload }
    var shouldAllowStreaming: Bool { canStream }

    /// Human-readable network status for display
    var statusDescription: String {
        if !isConnected { return "Offline" }
        if isWiFi { return "Wi-Fi" }
        if isCellular { return "Cellular" }
        return "Connected"
    }

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.reverie.networkMonitor", qos: .utility)
    private let logger = Logger(subsystem: "com.reverie", category: "network")

    private init() {
        startMonitoring()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isWiFi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
                self.isCellular = path.usesInterfaceType(.cellular)
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                if wasConnected && !self.isConnected {
                    self.logger.info("Network: went offline")
                } else if !wasConnected && self.isConnected {
                    let type = self.isWiFi ? "Wi-Fi" : (self.isCellular ? "Cellular" : "Other")
                    self.logger.info("Network: came online via \(type, privacy: .public)")
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }
}
