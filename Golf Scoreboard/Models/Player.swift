//
//  Player.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var name: String
    var handicap: Double
    var isCurrentUser: Bool
    var preferredTeeColor: String? // e.g., "White"
    var createdAt: Date
    
    init(name: String, handicap: Double = 0.0, isCurrentUser: Bool = false, preferredTeeColor: String? = "White") {
        self.id = UUID()
        self.name = name
        self.handicap = handicap
        self.isCurrentUser = isCurrentUser
        self.preferredTeeColor = preferredTeeColor
        self.createdAt = Date()
    }
}

