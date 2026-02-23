//
//  ImageCache.swift
//  Reverie
//
//  Phase 5C: In-memory image cache to avoid redundant thumbnail fetches
//

import Foundation

/// NSCache-backed image data cache. Thread-safe. 50-item limit.
final class ImageCache: @unchecked Sendable {

    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSData>()

    private init() {
        cache.countLimit = 50
    }

    /// Returns cached data for the URL, or fetches and caches it.
    func data(for url: URL) async -> Data? {
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached as Data
        }

        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }

        cache.setObject(data as NSData, forKey: key)
        return data
    }

    /// Stores data in cache under the given URL key.
    func store(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url.absoluteString as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
