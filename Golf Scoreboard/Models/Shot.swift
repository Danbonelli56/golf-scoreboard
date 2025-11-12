//
//  Shot.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import SwiftData

enum ShotResult: String, Codable, CaseIterable {
    case straight = "Straight"
    case right = "Right"
    case left = "Left"
    case outOfBounds = "Out of Bounds"
    case hazard = "In a Hazard"
    case trap = "In the Trap"
    case other = "Other"
}

@Model
final class Shot {
    @Relationship(inverse: \Game.shots) var game: Game?
    @Relationship(inverse: \Player.shots) var player: Player?
    var holeNumber: Int = 1
    var shotNumber: Int = 1
    var distanceToHole: Int? // in yards (distance remaining to hole)
    var originalDistanceFeet: Int? // original feet value if input was in feet (for putts)
    var club: String?
    var result: String = "Straight" // ShotResult as string
    var isPutt: Bool = false
    var createdAt: Date = Date()
    var distanceTraveled: Int? // in yards (how far the shot actually traveled)
    var isPenalty: Bool = false // true if this shot resulted in a penalty (hazard, OB, etc.)
    var isRetaking: Bool = false // true if retaking from tee (vs taking a drop)
    var isLong: Bool = false // true if shot went long (past target)
    var isShort: Bool = false // true if shot came short (didn't reach target)
    var isInBunker: Bool = false // true if shot landed in a bunker/sand trap
    
    init(player: Player? = nil, holeNumber: Int, shotNumber: Int, 
         distanceToHole: Int? = nil, originalDistanceFeet: Int? = nil, club: String? = nil, 
         result: ShotResult = .straight, isPutt: Bool = false, distanceTraveled: Int? = nil, isPenalty: Bool = false, isRetaking: Bool = false, isLong: Bool = false, isShort: Bool = false, isInBunker: Bool = false) {
        self.player = player
        self.holeNumber = holeNumber
        self.shotNumber = shotNumber
        self.distanceToHole = distanceToHole
        self.originalDistanceFeet = originalDistanceFeet
        self.club = club
        self.result = result.rawValue
        self.isPutt = isPutt
        self.distanceTraveled = distanceTraveled
        self.isPenalty = isPenalty
        self.isRetaking = isRetaking
        self.isLong = isLong
        self.isShort = isShort
        self.isInBunker = isInBunker
        self.createdAt = Date()
    }
    
    // Computed property: Calculate distance traveled from previous shot
    var calculatedDistance: Int? {
        return distanceTraveled
    }
}

// Shot summary for analysis
struct ShotSummary {
    var totalShots: Int
    var totalPutts: Int
    var shotsByResult: [String: Int]
    var shotsByClub: [String: Int]
    var avgDistance: Double?
    
    init() {
        self.totalShots = 0
        self.totalPutts = 0
        self.shotsByResult = [:]
        self.shotsByClub = [:]
        self.avgDistance = nil
    }
}

