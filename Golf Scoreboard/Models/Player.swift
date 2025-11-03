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
    var id: UUID = UUID()
    var name: String = ""
    var handicap: Double = 0.0
    var isCurrentUser: Bool = false
    var preferredTeeColor: String? // e.g., "White"
    var createdAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \Game.players) var games: [Game]?
    @Relationship(deleteRule: .nullify, inverse: \Shot.player) var shots: [Shot]?
    @Relationship(deleteRule: .nullify, inverse: \PlayerScore.player) var playerScores: [PlayerScore]?
    
    init(name: String, handicap: Double = 0.0, isCurrentUser: Bool = false, preferredTeeColor: String? = "White") {
        self.id = UUID()
        self.name = name
        self.handicap = handicap
        self.isCurrentUser = isCurrentUser
        self.preferredTeeColor = preferredTeeColor
        self.createdAt = Date()
    }
}

