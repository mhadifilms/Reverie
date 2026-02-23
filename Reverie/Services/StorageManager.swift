//
//  StorageManager.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages audio file storage on device and iCloud Drive
actor StorageManager {
    
    enum StorageLocation {
        case local      // App's Documents directory
        case iCloud     // User's iCloud Drive
    }
    
    enum StorageError: LocalizedError {
        case directoryCreationFailed
        case fileWriteFailed
        case fileDeleteFailed
        case fileNotFound
        case iCloudNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .directoryCreationFailed:
                return "Failed to create storage directory"
            case .fileWriteFailed:
                return "Failed to write file to disk"
            case .fileDeleteFailed:
                return "Failed to delete file"
            case .fileNotFound:
                return "File not found"
            case .iCloudNotAvailable:
                return "iCloud Drive is not available"
            }
        }
    }
    
    private let fileManager = FileManager.default
    
    init() {
        // Ensure audio directory exists
        Task {
            try? await createAudioDirectoryIfNeeded()
        }
    }
    
    /// Sets the preferred storage location
    func setStorageLocation(_ location: StorageLocation) {
        UserDefaults.standard.set(location == .iCloud, forKey: "saveToiCloud")
    }
    
    /// Returns the base audio storage directory URL
    func getAudioDirectory() throws -> URL {
        let baseURL: URL

        switch resolvedStorageLocation() {
        case .local:
            // Use Documents on all platforms for consistency and user accessibility
            baseURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent(Constants.appName)
        case .iCloud:
            // Try to use iCloud, but fall back to local if unavailable
            if let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
                baseURL = ubiquityURL
                    .appendingPathComponent("Documents")
                    .appendingPathComponent(Constants.appName)
            } else {
                // iCloud not available, fall back to local storage
                baseURL = try fileManager.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                .appendingPathComponent(Constants.appName)
            }
        }

        return baseURL.appendingPathComponent(Constants.audioDirectoryName)
    }
    
    private func resolvedStorageLocation() -> StorageLocation {
        UserDefaults.standard.bool(forKey: "saveToiCloud") ? .iCloud : .local
    }
    
    /// Creates the audio storage directory if it doesn't exist
    func createAudioDirectoryIfNeeded() async throws {
        let audioDirectory = try getAudioDirectory()
        
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(
                at: audioDirectory,
                withIntermediateDirectories: true
            )
        }
    }
    
    /// Saves audio data to storage and returns the file path
    func saveAudio(data: Data, filename: String) async throws -> String {
        try await createAudioDirectoryIfNeeded()
        let audioDirectory = try getAudioDirectory()
        let fileURL = audioDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL, options: .atomic)
            // Return relative path for database storage
            return filename
        } catch {
            throw StorageError.fileWriteFailed
        }
    }
    
    /// Retrieves the full URL for a stored audio file
    func getAudioFileURL(relativePath: String) throws -> URL {
        let audioDirectory = try getAudioDirectory()
        return audioDirectory.appendingPathComponent(relativePath)
    }
    
    /// Checks if an audio file exists
    func audioFileExists(relativePath: String) throws -> Bool {
        let fileURL = try getAudioFileURL(relativePath: relativePath)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Deletes an audio file
    func deleteAudio(relativePath: String) async throws {
        let fileURL = try getAudioFileURL(relativePath: relativePath)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw StorageError.fileNotFound
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw StorageError.fileDeleteFailed
        }
    }
    
    /// Calculates total storage used by audio files
    func calculateTotalStorageUsed() async throws -> Int64 {
        let audioDirectory = try getAudioDirectory()
        
        guard fileManager.fileExists(atPath: audioDirectory.path) else {
            return 0
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        
        var totalSize: Int64 = 0
        
        for fileURL in contents {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    /// Deletes all audio files
    func deleteAllAudio() async throws {
        let audioDirectory = try getAudioDirectory()
        
        guard fileManager.fileExists(atPath: audioDirectory.path) else {
            return
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil
        )
        
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Opens the audio folder in Files (iOS) or Finder (macOS)
    func openAudioFolder() async {
        do {
            try await createAudioDirectoryIfNeeded()
            let audioDirectory = try getAudioDirectory()
            await MainActor.run {
                #if os(macOS)
                NSWorkspace.shared.open(audioDirectory)
                #elseif os(iOS)
                UIApplication.shared.open(audioDirectory)
                #endif
            }
        } catch {
            // no-op
        }
    }
    
    /// Checks if iCloud is available
    func isICloudAvailable() -> Bool {
        return fileManager.url(forUbiquityContainerIdentifier: nil) != nil
    }
    
    /// Gets the current storage location
    func getCurrentStorageLocation() -> StorageLocation {
        return resolvedStorageLocation()
    }
    
    /// Migrates all audio files from local to iCloud or vice versa
    func migrateFiles(to destination: StorageLocation, progressHandler: @escaping (Double, String) -> Void) async throws {
        let currentLocation = resolvedStorageLocation()
        
        // No migration needed if already at destination
        guard currentLocation != destination else { return }
        
        // For iCloud migration, check availability
        if destination == .iCloud && !isICloudAvailable() {
            throw StorageError.iCloudNotAvailable
        }
        
        // Get source and destination directories
        let sourceDir: URL
        let destinationDir: URL
        
        switch currentLocation {
        case .local:
            sourceDir = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent(Constants.appName)
            .appendingPathComponent(Constants.audioDirectoryName)
            
            guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
                throw StorageError.iCloudNotAvailable
            }
            destinationDir = ubiquityURL
                .appendingPathComponent("Documents")
                .appendingPathComponent(Constants.appName)
                .appendingPathComponent(Constants.audioDirectoryName)
            
        case .iCloud:
            guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
                throw StorageError.iCloudNotAvailable
            }
            sourceDir = ubiquityURL
                .appendingPathComponent("Documents")
                .appendingPathComponent(Constants.appName)
                .appendingPathComponent(Constants.audioDirectoryName)
            
            destinationDir = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent(Constants.appName)
            .appendingPathComponent(Constants.audioDirectoryName)
        }
        
        // Create destination directory if needed
        if !fileManager.fileExists(atPath: destinationDir.path) {
            try fileManager.createDirectory(
                at: destinationDir,
                withIntermediateDirectories: true
            )
        }
        
        // Check if source directory exists
        guard fileManager.fileExists(atPath: sourceDir.path) else {
            // No files to migrate, just update the preference
            setStorageLocation(destination)
            return
        }
        
        // Get all audio files
        let contents = try fileManager.contentsOfDirectory(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        
        let audioFiles = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return ext == "m4a" || ext == "mp3" || ext == "aac"
        }
        
        guard !audioFiles.isEmpty else {
            // No files to migrate
            setStorageLocation(destination)
            return
        }
        
        // Migrate each file
        let totalCount = audioFiles.count
        
        for (index, audioFile) in audioFiles.enumerated() {
            let fileName = audioFile.lastPathComponent
            let destinationFile = destinationDir.appendingPathComponent(fileName)
            
            // Report progress
            let currentProgress = Double(index) / Double(totalCount)
            let currentStatus = "Moving \(fileName)..."
            await progressHandler(currentProgress, currentStatus)
            
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationFile.path) {
                try fileManager.removeItem(at: destinationFile)
            }
            
            // Move file
            try fileManager.moveItem(at: audioFile, to: destinationFile)
        }
        
        // Update storage preference
        setStorageLocation(destination)
        
        // Final progress update
        await progressHandler(1.0, "Migration complete!")
    }
    
    /// Moves a file from temporary location to permanent storage
    func moveToStorage(from tempURL: URL, filename: String) async throws -> String {
        let audioDirectory = try getAudioDirectory()
        let destinationURL = audioDirectory.appendingPathComponent(filename)
        
        // If file exists, delete it first
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        do {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            return filename
        } catch {
            throw StorageError.fileWriteFailed
        }
    }
    
    /// Cleans up orphaned audio files that have no corresponding track in the database
    func cleanOrphanedFiles(validFilenames: Set<String>) async throws -> Int {
        let audioDirectory = try getAudioDirectory()
        
        guard fileManager.fileExists(atPath: audioDirectory.path) else {
            return 0
        }
        
        let contents = try fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil
        )
        
        var deletedCount = 0
        
        for fileURL in contents {
            let filename = fileURL.lastPathComponent
            
            // Skip hidden files and .DS_Store
            guard !filename.hasPrefix(".") else { continue }
            
            // If this file is not in the valid set, it's orphaned
            if !validFilenames.contains(filename) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                } catch {
                    // Log but continue with other files
                    print("Failed to delete orphaned file \(filename): \(error)")
                }
            }
        }
        
        return deletedCount
    }
}
