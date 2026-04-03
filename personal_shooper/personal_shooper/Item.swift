//
//  Item.swift
//  personal_shooper
//
//  Created by Pedro Caparros Torres on 26/3/26.
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
