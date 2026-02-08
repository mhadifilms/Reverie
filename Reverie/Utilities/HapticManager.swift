//
//  HapticManager.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Centralized haptic feedback manager
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    #if canImport(UIKit)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    #endif
    
    private init() {
        #if canImport(UIKit)
        // Prepare generators for lower latency
        light.prepare()
        medium.prepare()
        heavy.prepare()
        notification.prepare()
        #endif
    }
    
    #if canImport(UIKit)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            light.impactOccurred()
            light.prepare()
        case .medium:
            medium.impactOccurred()
            medium.prepare()
        case .heavy:
            heavy.impactOccurred()
            heavy.prepare()
        default:
            medium.impactOccurred()
            medium.prepare()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
        notification.prepare()
    }
    
    // Convenience methods for common actions
    func playPause() {
        impact(.medium)
    }
    
    func skip() {
        impact(.light)
    }
    
    func downloadComplete() {
        notification(.success)
    }
    
    func error() {
        notification(.error)
    }
    
    func longPress() {
        impact(.heavy)
    }
    #else
    // macOS stubs - no haptic feedback on Mac
    func playPause() {}
    func skip() {}
    func downloadComplete() {}
    func error() {}
    func longPress() {}
    #endif
}
