//
//  SectionHeaderView.swift
//  Reverie
//
//  Section header styled per the Canopy.html `CSectionHead`:
//  display-serif-friendly title with a muted green action/subtitle on the
//  trailing edge. System image is optional and renders in the ink color.
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
        HStack(alignment: .firstTextBaseline, spacing: CanopyTheme.Space.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CanopyTheme.Palette.greenDeep)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(CanopyTheme.Typography.title)
                .foregroundStyle(CanopyTheme.Palette.ink)

            Spacer()

            if let subtitle {
                Text(subtitle)
                    .font(CanopyTheme.Typography.captionEmphasized)
                    .foregroundStyle(CanopyTheme.Palette.green)
            }
        }
        .padding(.vertical, CanopyTheme.Space.sm)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Playlists", subtitle: "3 playlists", systemImage: "music.note.list")
        SectionHeaderView(title: "Recent Downloads", subtitle: "12 songs", systemImage: "arrow.down.circle")
    }
    .padding()
    .background(CanopyTheme.Palette.paper)
}
