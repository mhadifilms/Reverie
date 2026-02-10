//
//  SectionHeaderView.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/9/26.
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    
    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }
    
    var body: some View {
        #if os(iOS)
        GlassCard(cornerRadius: 14, padding: 10) {
            headerContent
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        #else
        headerContent
        #endif
    }
    
    private var headerContent: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            Text(title)
                #if os(iOS)
                .font(.title2.bold())
                #else
                .font(.title3.bold())
                #endif
            
            Spacer()
            
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Playlists", subtitle: "3 playlists", systemImage: "music.note.list")
        SectionHeaderView(title: "Recent Downloads", subtitle: "12 songs", systemImage: "arrow.down.circle")
    }
    .padding()
}
