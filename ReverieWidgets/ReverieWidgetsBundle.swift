//
//  ReverieWidgetsBundle.swift
//  ReverieWidgets
//
//  Created by Muhammad Hadi Yusufali on 2/22/26.
//

import WidgetKit
import SwiftUI

@main
struct ReverieWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ReverieNowPlayingWidget()
        NowPlayingLiveActivity()
    }
}
