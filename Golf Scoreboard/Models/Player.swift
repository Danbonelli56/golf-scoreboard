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
    var email: String? // Email address from contacts
    var phoneNumber: String? // Phone number from contacts
    var createdAt: Date = Date()
    var games: [Game]?
    var shots: [Shot]?
    var playerScores: [PlayerScore]?
    
    init(name: String, handicap: Double = 0.0, isCurrentUser: Bool = false, preferredTeeColor: String? = "White", email: String? = nil, phoneNumber: String? = nil) {
        self.id = UUID()
        self.name = name
        self.handicap = handicap
        self.isCurrentUser = isCurrentUser
        self.preferredTeeColor = preferredTeeColor
        self.email = email
        self.phoneNumber = phoneNumber
        self.createdAt = Date()
    }
}

