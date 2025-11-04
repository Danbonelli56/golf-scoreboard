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
    
    // Computed properties for front 9, back 9, and total
    var front9Scores: [(player: Player, gross: Int, net: Int)] {
        let front9 = holesScoresArray.filter { $0.holeNumber <= 9 }
        return calculateScores(holesScores: front9, useHalfHandicap: true)
    }
    
    var back9Scores: [(player: Player, gross: Int, net: Int)] {
        let back9 = holesScoresArray.filter { $0.holeNumber > 9 }
        return calculateScores(holesScores: back9, useHalfHandicap: true)
    }
    
    var totalScores: [(player: Player, gross: Int, net: Int)] {
        return calculateScores(holesScores: holesScoresArray, useHalfHandicap: false)
    }
    
    private func calculateScores(holesScores: [HoleScore], useHalfHandicap: Bool = false) -> [(player: Player, gross: Int, net: Int)] {
        var playerTotals: [UUID: Int] = [:]
        
        for holeScore in holesScores {
            for player in playersArray {
                if let score = holeScore.scores[player.id] {
                    playerTotals[player.id, default: 0] += score
                }
            }
        }
        
        return playersArray.map { player in
            let gross = playerTotals[player.id] ?? 0
            let effectiveHandicap = useHalfHandicap ? player.handicap / 2.0 : player.handicap
            let net = max(0, gross - Int(round(effectiveHandicap)))
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

