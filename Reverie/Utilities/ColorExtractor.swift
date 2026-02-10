//
//  ColorExtractor.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Extracts a dominant color from album art for dynamic theming
enum ColorExtractor {
    static func dominantColor(from data: Data) -> Color? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data)?.cgImage else { return nil }
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let image = cgImage
        #endif
        return dominantColor(from: image)
    }
    
    private static func dominantColor(from image: CGImage) -> Color? {
        let width = 40
        let height = 40
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return nil }
        let pointer = pixelData.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
        
        var redTotal: Int = 0
        var greenTotal: Int = 0
        var blueTotal: Int = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelCount * bytesPerPixel, by: bytesPerPixel) {
            redTotal += Int(pointer[i])
            greenTotal += Int(pointer[i + 1])
            blueTotal += Int(pointer[i + 2])
        }
        
        let red = Double(redTotal) / Double(pixelCount * 255)
        let green = Double(greenTotal) / Double(pixelCount * 255)
        let blue = Double(blueTotal) / Double(pixelCount * 255)
        
        return Color(red: red, green: green, blue: blue)
    }
}
