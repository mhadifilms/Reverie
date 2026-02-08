//
//  AlbumArtView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Displays album artwork with rounded corners and shadow
struct AlbumArtView: View {
    let imageData: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(
        imageData: Data?,
        size: CGFloat = 200,
        cornerRadius: CGFloat = Constants.albumArtCornerRadius
    ) {
        self.imageData = imageData
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                if let imageData = imageData {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    } else {
                        placeholderView
                    }
                    #elseif canImport(AppKit)
                    if let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    } else {
                        placeholderView
                    }
                    #endif
                } else {
                    placeholderView
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    private var placeholderView: some View {
        Image(systemName: "music.note")
            .font(.system(size: size * 0.3))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 20) {
        AlbumArtView(imageData: nil, size: 200)
        AlbumArtView(imageData: nil, size: 150, cornerRadius: 20)
        AlbumArtView(imageData: nil, size: 100, cornerRadius: 8)
    }
    .padding()
}
