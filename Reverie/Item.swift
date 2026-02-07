//
//  Item.swift
//  Reverie
//
//  Created by Muhammad Hadi Yusufali on 2/6/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
