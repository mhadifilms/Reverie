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
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            
            Text(title)
                .font(.title2.bold())
            
            Spacer()
            
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Playlists", subtitle: "3 playlists", systemImage: "music.note.list")
        SectionHeaderView(title: "Recent Downloads", subtitle: "12 songs", systemImage: "arrow.down.circle")
    }
    .padding()
}
