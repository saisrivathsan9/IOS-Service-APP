//
//  Item.swift
//  Diary
//
//  Created by Saisrivathsan Manikandan on 8/18/25.
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
