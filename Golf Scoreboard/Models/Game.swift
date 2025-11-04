//
//  Game.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID = UUID()
    var course: GolfCourse?
    var players: [Player]?
    var holesScores: [HoleScore]?
    var shots: [Shot]?
    var date: Date = Date()
    var createdAt: Date?
    var selectedTeeColor: String? // Override tee color for this game
    
    init(course: GolfCourse? = nil, players: [Player] = [], selectedTeeColor: String? = nil) {
        self.id = UUID()
        self.course = course
        self.date = Date()
        self.players = players
        self.holesScores = []
        self.createdAt = nil
        self.selectedTeeColor = selectedTeeColor
    }
    
    // Computed properties for safe access to optional arrays
    var playersArray: [Player] { players ?? [] }
    var holesScoresArray: [HoleScore] { holesScores ?? [] }
    var shotsArray: [Shot] { shots ?? [] }
    
    // Computed property for effective tee color (selected or default from course)
    var effectiveTeeColor: String? {
        // Return selected tee color if set
        if let selected = selectedTeeColor {
            return selected
        }
        
        // Otherwise, use priority: White > Green > first available
        guard let course = course,
              let holes = course.holes,
              let firstHole = holes.first,
              let teeDistances = firstHole.teeDistances else {
            return nil
        }
        
        let teeColors = Set(teeDistances.map { $0.teeColor })
        
        // Default to White if available
        if teeColors.contains("White") {
            return "White"
        }
        
        // Fallback to Green if available
        if teeColors.contains("Green") {
            return "Green"
        }
        
        // Otherwise, use first available
        return teeDistances.first?.teeColor
    }
    
    // Computed properties for front 9, back 9, and total
    // These should sum the net scores from individual holes, not recalculate with different handicap
    var front9Scores: [(player: Player, gross: Int, net: Int)] {
        let front9 = holesScoresArray.filter { $0.holeNumber <= 9 }
        return calculateScores(holesScores: front9, useHalfHandicap: false)
    }
    
    var back9Scores: [(player: Player, gross: Int, net: Int)] {
        let back9 = holesScoresArray.filter { $0.holeNumber > 9 }
        return calculateScores(holesScores: back9, useHalfHandicap: false)
    }
    
    var totalScores: [(player: Player, gross: Int, net: Int)] {
        return calculateScores(holesScores: holesScoresArray, useHalfHandicap: false)
    }
    
    // Calculate how many strokes a player gets on a specific hole based on their handicap
    // Examples:
    // - Handicap 13: 1 stroke on holes with HCP 1-13
    // - Handicap 20: 1 stroke on all holes (HCP 1-18), plus 1 extra stroke on holes with HCP 1-2
    private func strokesForHole(player: Player, holeHandicap: Int, useHalfHandicap: Bool = false) -> Int {
        let handicap = useHalfHandicap ? player.handicap / 2.0 : player.handicap
        let handicapInt = Int(round(handicap))
        
        // For handicap <= 18: get 1 stroke on holes with HCP 1 through handicap
        // Example: Handicap 13 gets 1 stroke on HCP holes 1-13
        if handicapInt <= 18 {
            return holeHandicap <= handicapInt ? 1 : 0
        }
        
        // For handicap > 18: 
        // - Base: 1 stroke on all 18 holes (HCP 1-18)
        // - Extra: Additional strokes on hardest holes based on remainder
        // Example: Handicap 20 = 18 base + 2 remainder, so 1 stroke on all holes + 1 extra on HCP 1-2
        let baseStrokes = 1 // All holes get at least 1 stroke
        let remainder = handicapInt % 18 // Extra strokes on hardest holes
        
        if remainder > 0 && holeHandicap <= remainder {
            return baseStrokes + 1 // Extra stroke on hardest holes
        }
        
        return baseStrokes // Standard stroke on all other holes
    }
    
    // Calculate net score for a specific hole
    func netScoreForHole(player: Player, holeNumber: Int, useHalfHandicap: Bool = false) -> Int? {
        guard let course = course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }),
              let gross = holesScoresArray.first(where: { $0.holeNumber == holeNumber })?.scores[player.id] else {
            return nil
        }
        
        let strokes = strokesForHole(player: player, holeHandicap: hole.mensHandicap, useHalfHandicap: useHalfHandicap)
        return max(0, gross - strokes)
    }
    
    private func calculateScores(holesScores: [HoleScore], useHalfHandicap: Bool = false) -> [(player: Player, gross: Int, net: Int)] {
        var playerGrossTotals: [UUID: Int] = [:]
        var playerNetTotals: [UUID: Int] = [:]
        
        guard let course = course, let holes = course.holes else {
            // Fallback to old calculation if no course data
            for holeScore in holesScores {
                for player in playersArray {
                    if let score = holeScore.scores[player.id] {
                        playerGrossTotals[player.id, default: 0] += score
                    }
                }
            }
            return playersArray.map { player in
                let gross = playerGrossTotals[player.id] ?? 0
                let effectiveHandicap = useHalfHandicap ? player.handicap / 2.0 : player.handicap
                let net = max(0, gross - Int(round(effectiveHandicap)))
                return (player: player, gross: gross, net: net)
            }
        }
        
        // Calculate gross and net scores per hole
        for holeScore in holesScores {
            guard let hole = holes.first(where: { $0.holeNumber == holeScore.holeNumber }) else { continue }
            
            for player in playersArray {
                if let gross = holeScore.scores[player.id] {
                    playerGrossTotals[player.id, default: 0] += gross
                    
                    // Calculate net score for this hole
                    let strokes = strokesForHole(player: player, holeHandicap: hole.mensHandicap, useHalfHandicap: useHalfHandicap)
                    let net = max(0, gross - strokes)
                    playerNetTotals[player.id, default: 0] += net
                }
            }
        }
        
        return playersArray.map { player in
            let gross = playerGrossTotals[player.id] ?? 0
            let net = playerNetTotals[player.id] ?? 0
            return (player: player, gross: gross, net: net)
        }
    }
}

@Model
final class HoleScore {
    @Relationship(inverse: \Game.holesScores) var game: Game?
    var holeNumber: Int = 1
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \PlayerScore.holeScore) var playerScores: [PlayerScore]?
    
    init(holeNumber: Int) {
        self.holeNumber = holeNumber
        self.playerScores = []
        self.createdAt = Date()
    }
    
    // Computed property for backward compatibility
    var scores: [UUID: Int] {
        var result: [UUID: Int] = [:]
        for playerScore in playerScores ?? [] {
            if let playerId = playerScore.player?.id {
                result[playerId] = playerScore.score
            }
        }
        return result
    }
    
    // Subscript for backward compatibility
    subscript(playerId: UUID) -> Int? {
        get {
            return scores[playerId]
        }
        set {
            if let newValue = newValue {
                // Find or create PlayerScore for this player
                if let existingPlayerScore = playerScores?.first(where: { $0.player?.id == playerId }) {
                    existingPlayerScore.score = newValue
                } else {
                    // Need to find the player to create the relationship
                    // This will be handled by the caller providing the context
                }
            } else {
                // Remove the player score
                if let index = playerScores?.firstIndex(where: { $0.player?.id == playerId }) {
                    playerScores?.remove(at: index)
                }
            }
        }
    }
    
    // Helper method to set score with player reference
    func setScore(for player: Player, score: Int) {
        if playerScores == nil { playerScores = [] }
        if let existingPlayerScore = playerScores!.first(where: { $0.player?.id == player.id }) {
            existingPlayerScore.score = score
        } else {
            let playerScore = PlayerScore(player: player, score: score)
            playerScore.holeScore = self
            playerScores!.append(playerScore)
        }
    }
}

@Model
final class PlayerScore {
    var holeScore: HoleScore?
    var player: Player?
    var score: Int = 0
    
    init(player: Player? = nil, score: Int = 0) {
        self.player = player
        self.score = score
    }
}

