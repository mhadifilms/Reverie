//
//  MetadataEmbedder.swift
//  Reverie
//
//  Phase 2C: Embeds metadata atoms into M4A files using AVAssetExportSession.
//  Title, artist, album, album art (JPEG), year, genre, lyrics.
//

import Foundation
import AVFoundation
import OSLog

actor MetadataEmbedder {

    private let logger = Logger(subsystem: "com.reverie", category: "embedder")
    private let storageManager = StorageManager()

    /// Embeds metadata from a ReverieTrack into its M4A file on disk.
    /// Must be called from MainActor context to read track properties.
    func embedMetadata(
        title: String,
        artist: String,
        album: String,
        albumArtData: Data?,
        year: Int?,
        genre: String?,
        lyrics: String?,
        sourceFileURL: URL
    ) async throws -> URL {
        // Load the asset
        let asset = AVURLAsset(url: sourceFileURL)

        // Verify the file is exportable
        guard await asset.load(.isExportable) else {
            logger.warning("Asset is not exportable: \(sourceFileURL.lastPathComponent, privacy: .public)")
            throw EmbedderError.notExportable
        }

        // Create metadata items
        var metadataItems: [AVMutableMetadataItem] = []

        // Title
        metadataItems.append(makeMetadataItem(
            identifier: .commonIdentifierTitle,
            value: title as NSString
        ))

        // Artist
        metadataItems.append(makeMetadataItem(
            identifier: .commonIdentifierArtist,
            value: artist as NSString
        ))

        // Album
        if !album.isEmpty {
            metadataItems.append(makeMetadataItem(
                identifier: .commonIdentifierAlbumName,
                value: album as NSString
            ))
        }

        // Album art (JPEG)
        if let artData = albumArtData {
            let artItem = AVMutableMetadataItem()
            artItem.identifier = .commonIdentifierArtwork
            artItem.value = artData as NSData
            artItem.dataType = kCMMetadataBaseDataType_JPEG as String
            metadataItems.append(artItem)
        }

        // Year (iTunes creation date)
        if let year = year {
            metadataItems.append(makeMetadataItem(
                identifier: .iTunesMetadataContentRating,
                key: AVMetadataKey.iTunesMetadataKeyReleaseDate,
                keySpace: .iTunes,
                value: "\(year)" as NSString
            ))
        }

        // Genre
        if let genre = genre, !genre.isEmpty {
            metadataItems.append(makeMetadataItem(
                identifier: .quickTimeMetadataGenre,
                value: genre as NSString
            ))
            // Also set iTunes genre for broader compatibility
            let iTunesGenre = AVMutableMetadataItem()
            iTunesGenre.keySpace = .iTunes
            iTunesGenre.key = AVMetadataKey.iTunesMetadataKeyUserGenre as NSString
            iTunesGenre.value = genre as NSString
            metadataItems.append(iTunesGenre)
        }

        // Lyrics
        if let lyrics = lyrics, !lyrics.isEmpty {
            let lyricsItem = AVMutableMetadataItem()
            lyricsItem.keySpace = .iTunes
            lyricsItem.key = AVMetadataKey.iTunesMetadataKeyLyrics as NSString
            lyricsItem.value = lyrics as NSString
            metadataItems.append(lyricsItem)
        }

        // Export to a temporary file with embedded metadata
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw EmbedderError.exportSessionCreationFailed
        }

        exportSession.outputFileType = .m4a
        exportSession.outputURL = tempURL
        exportSession.metadata = metadataItems

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            logger.info("Metadata embedded successfully for: \(title, privacy: .public)")
            return tempURL

        case .failed:
            let error = exportSession.error
            logger.error("Export failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
            throw EmbedderError.exportFailed(error)

        case .cancelled:
            throw EmbedderError.exportCancelled

        default:
            throw EmbedderError.exportFailed(nil)
        }
    }

    /// Convenience: reads track properties on MainActor, then embeds metadata.
    @MainActor
    func embedMetadata(for track: ReverieTrack) async throws {
        guard let relativePath = track.localFilePath else { return }

        let fileURL = try await storageManager.getAudioFileURL(relativePath: relativePath)

        // Collect values on MainActor
        let title = track.title
        let artist = track.artist
        let album = track.album
        let artData = track.albumArtData
        let year: Int? = {
            if let date = track.releaseDate {
                return Calendar.current.component(.year, from: date)
            }
            return nil
        }()
        let genre = track.genre
        let lyrics = track.lyrics

        // Run export off MainActor
        let tempURL = try await embedMetadata(
            title: title,
            artist: artist,
            album: album,
            albumArtData: artData,
            year: year,
            genre: genre,
            lyrics: lyrics,
            sourceFileURL: fileURL
        )

        // Replace the original file with the enriched version
        let newPath = try await storageManager.moveToStorage(
            from: tempURL,
            filename: relativePath
        )
        track.localFilePath = newPath
    }

    // MARK: - Helpers

    private func makeMetadataItem(
        identifier: AVMetadataIdentifier,
        value: NSString & NSCopying
    ) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        return item
    }

    private func makeMetadataItem(
        identifier: AVMetadataIdentifier,
        key: AVMetadataKey,
        keySpace: AVMetadataKeySpace,
        value: NSString & NSCopying
    ) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.keySpace = keySpace
        item.key = key as NSString
        item.value = value
        return item
    }

    // MARK: - Errors

    enum EmbedderError: LocalizedError {
        case notExportable
        case exportSessionCreationFailed
        case exportFailed(Error?)
        case exportCancelled

        var errorDescription: String? {
            switch self {
            case .notExportable:
                return "Audio file cannot be exported"
            case .exportSessionCreationFailed:
                return "Failed to create export session"
            case .exportFailed(let error):
                return "Export failed: \(error?.localizedDescription ?? "unknown")"
            case .exportCancelled:
                return "Export was cancelled"
            }
        }
    }
}
