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
    @Attribute(.unique) var id: UUID
    var course: GolfCourse?
    var date: Date
    @Relationship(deleteRule: .nullify) var players: [Player]
    @Relationship(deleteRule: .cascade) var holesScores: [HoleScore]
    var createdAt: Date?
    
    init(course: GolfCourse? = nil, players: [Player] = []) {
        self.id = UUID()
        self.course = course
        self.date = Date()
        self.players = players
        self.holesScores = []
        self.createdAt = nil
    }
    
    // Computed properties for front 9, back 9, and total
    var front9Scores: [(player: Player, gross: Int, net: Int)] {
        let front9 = holesScores.filter { $0.holeNumber <= 9 }
        return calculateScores(holesScores: front9, useHalfHandicap: true)
    }
    
    var back9Scores: [(player: Player, gross: Int, net: Int)] {
        let back9 = holesScores.filter { $0.holeNumber > 9 }
        return calculateScores(holesScores: back9, useHalfHandicap: true)
    }
    
    var totalScores: [(player: Player, gross: Int, net: Int)] {
        return calculateScores(holesScores: holesScores, useHalfHandicap: false)
    }
    
    private func calculateScores(holesScores: [HoleScore], useHalfHandicap: Bool = false) -> [(player: Player, gross: Int, net: Int)] {
        var playerTotals: [UUID: Int] = [:]
        
        for holeScore in holesScores {
            for player in players {
                if let score = holeScore.scores[player.id] {
                    playerTotals[player.id, default: 0] += score
                }
            }
        }
        
        return players.map { player in
            let gross = playerTotals[player.id] ?? 0
            let effectiveHandicap = useHalfHandicap ? player.handicap / 2.0 : player.handicap
            let net = max(0, gross - Int(round(effectiveHandicap)))
            return (player: player, gross: gross, net: net)
        }
    }
}

@Model
final class HoleScore {
    var game: Game?
    var holeNumber: Int
    var scores: [UUID: Int] // Player ID to Score
    var createdAt: Date
    
    init(holeNumber: Int, scores: [UUID: Int] = [:]) {
        self.holeNumber = holeNumber
        self.scores = scores
        self.createdAt = Date()
    }
}

