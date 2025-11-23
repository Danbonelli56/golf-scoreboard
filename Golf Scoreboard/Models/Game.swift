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
    var isCompleted: Bool = false // Whether the game is completed and archived
    var gameFormat: String = "stroke" // Game format: "stroke", "stableford", "bestball", "skins"
    // Team assignments for Best Ball format: "team1:uuid1,uuid2|team2:uuid3,uuid4"
    // Format: "team1:uuid1,uuid2|team2:uuid3,uuid4" where team1 and team2 are the two teams
    var teamAssignments_v2: String? // Team assignments stored as string for SwiftData compatibility
    // Use new property name to avoid CloudKit conflict with old binary data
    // Old CloudKit records have "trackingPlayerIDs" as binary data, so we use a new name
    var trackingPlayerIDs_v2: String? // IDs of players who are tracking shots (stored as comma-separated UUID strings)
    
    init(course: GolfCourse? = nil, players: [Player] = [], selectedTeeColor: String? = nil, date: Date? = nil, trackingPlayerIDs: [UUID]? = nil, gameFormat: String = "stroke", teamAssignments: [String: [UUID]]? = nil) {
        self.id = UUID()
        self.course = course
        self.date = date ?? Date()
        self.players = players
        self.holesScores = []
        self.createdAt = nil
        self.selectedTeeColor = selectedTeeColor
        self.gameFormat = gameFormat
        // Convert UUID array to comma-separated string for SwiftData compatibility
        self.trackingPlayerIDs_v2 = trackingPlayerIDs?.map { $0.uuidString }.joined(separator: ",")
        // Convert team assignments to string format: "team1:uuid1,uuid2|team2:uuid3,uuid4"
        if let teams = teamAssignments {
            self.teamAssignments_v2 = teams.map { teamName, playerIDs in
                let idsString = playerIDs.map { $0.uuidString }.joined(separator: ",")
                return "\(teamName):\(idsString)"
            }.joined(separator: "|")
        }
    }
    
    // Computed properties for safe access to optional arrays
    var playersArray: [Player] { players ?? [] }
    var holesScoresArray: [HoleScore] { holesScores ?? [] }
    var shotsArray: [Shot] { shots ?? [] }
    
    // Convenience property for backward compatibility - wraps trackingPlayerIDs_v2
    // This allows existing code to continue working while CloudKit syncs the new property name
    var trackingPlayerIDs: String? {
        get { trackingPlayerIDs_v2 }
        set { trackingPlayerIDs_v2 = newValue }
    }
    
    // Convert comma-separated string back to UUID Set for use in code
    var trackingPlayerIDsSet: Set<UUID> {
        guard let idsString = trackingPlayerIDs_v2, !idsString.isEmpty else { return [] }
        return Set(idsString.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }
    
    // Get players who are tracking shots
    var trackingPlayers: [Player] {
        let trackingIDs = trackingPlayerIDsSet
        return playersArray.filter { trackingIDs.contains($0.id) }
    }
    
    // Parse team assignments from string format
    var teamAssignments: [String: [UUID]] {
        guard let assignmentsString = teamAssignments_v2, !assignmentsString.isEmpty else {
            return [:]
        }
        
        var teams: [String: [UUID]] = [:]
        let teamStrings = assignmentsString.split(separator: "|")
        
        for teamString in teamStrings {
            let parts = teamString.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let teamName = String(parts[0])
                let playerIDs = parts[1].split(separator: ",").compactMap { UUID(uuidString: String($0)) }
                teams[teamName] = playerIDs
            }
        }
        
        return teams
    }
    
    // Get players for a specific team
    func playersForTeam(_ teamName: String) -> [Player] {
        guard let teamPlayerIDs = teamAssignments[teamName] else {
            return []
        }
        return playersArray.filter { teamPlayerIDs.contains($0.id) }
    }
    
    // Get team names
    var teamNames: [String] {
        Array(teamAssignments.keys).sorted()
    }
    
    // Calculate best ball score for a team on a specific hole (gross score)
    func bestBallScoreForTeam(_ teamName: String, holeNumber: Int) -> Int? {
        let teamPlayers = playersForTeam(teamName)
        guard !teamPlayers.isEmpty else { return nil }
        
        let holeScore = holesScoresArray.first(where: { $0.holeNumber == holeNumber })
        guard let hole = holeScore else { return nil }
        
        var bestScore: Int? = nil
        for player in teamPlayers {
            if let score = hole.scores[player.id] {
                if bestScore == nil || score < bestScore! {
                    bestScore = score
                }
            }
        }
        
        return bestScore
    }
    
    // Calculate best ball NET score for a team on a specific hole (for match play)
    func bestBallNetScoreForTeam(_ teamName: String, holeNumber: Int) -> Int? {
        let teamPlayers = playersForTeam(teamName)
        guard !teamPlayers.isEmpty else { return nil }
        
        guard let course = course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }) else {
            return nil
        }
        
        let holeScore = holesScoresArray.first(where: { $0.holeNumber == holeNumber })
        guard let holeScoreData = holeScore else { return nil }
        
        var bestNetScore: Int? = nil
        for player in teamPlayers {
            if let grossScore = holeScoreData.scores[player.id] {
                // Calculate net score using handicap strokes
                let strokes = strokesForHole(player: player, holeHandicap: hole.mensHandicap, useHalfHandicap: false)
                let netScore = max(0, grossScore - strokes)
                
                if bestNetScore == nil || netScore < bestNetScore! {
                    bestNetScore = netScore
                }
            }
        }
        
        return bestNetScore
    }
    
    // Determine which team wins a hole in match play (returns team name or nil if tied)
    func matchPlayHoleWinner(holeNumber: Int) -> String? {
        guard gameFormat == "bestball_matchplay", teamNames.count == 2 else {
            return nil
        }
        
        let team1Name = teamNames[0]
        let team2Name = teamNames[1]
        
        guard let team1Net = bestBallNetScoreForTeam(team1Name, holeNumber: holeNumber),
              let team2Net = bestBallNetScoreForTeam(team2Name, holeNumber: holeNumber) else {
            return nil
        }
        
        if team1Net < team2Net {
            return team1Name
        } else if team2Net < team1Net {
            return team2Name
        } else {
            return nil // Tied hole
        }
    }
    
    // Calculate match play status
    var matchPlayStatus: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "bestball_matchplay", teamNames.count == 2 else {
            return (0, 0, 18, "Not a match play game")
        }
        
        let team1Name = teamNames[0]
        let team2Name = teamNames[1]
        
        var team1Wins = 0
        var team2Wins = 0
        var holesPlayed = 0
        
        for holeNumber in 1...18 {
            // Check if both teams have scores for this hole (hole is played)
            let team1HasScore = bestBallNetScoreForTeam(team1Name, holeNumber: holeNumber) != nil
            let team2HasScore = bestBallNetScoreForTeam(team2Name, holeNumber: holeNumber) != nil
            
            if team1HasScore && team2HasScore {
                // Hole has been played
                holesPlayed += 1
                
                // Determine winner (if any)
                if let winner = matchPlayHoleWinner(holeNumber: holeNumber) {
                    if winner == team1Name {
                        team1Wins += 1
                    } else if winner == team2Name {
                        team2Wins += 1
                    }
                    // Tied holes don't count as wins for either team
                }
            }
        }
        
        let holesRemaining = 18 - holesPlayed
        let team1Up = team1Wins - team2Wins
        let team2Up = team2Wins - team1Wins
        
        var status: String
        if team1Up > 0 {
            if holesRemaining > 0 && team1Up > holesRemaining {
                status = "\(team1Name) wins \(team1Up) up"
            } else if holesRemaining > 0 {
                status = "\(team1Name) \(team1Up) up with \(holesRemaining) to play"
            } else {
                status = "\(team1Name) wins \(team1Up) up"
            }
        } else if team2Up > 0 {
            if holesRemaining > 0 && team2Up > holesRemaining {
                status = "\(team2Name) wins \(team2Up) up"
            } else if holesRemaining > 0 {
                status = "\(team2Name) \(team2Up) up with \(holesRemaining) to play"
            } else {
                status = "\(team2Name) wins \(team2Up) up"
            }
        } else {
            if holesRemaining > 0 {
                status = "All square with \(holesRemaining) to play"
            } else {
                status = "Match halved"
            }
        }
        
        return (team1Up, team2Up, holesRemaining, status)
    }
    
    // Calculate total best ball score for a team
    func totalBestBallScoreForTeam(_ teamName: String) -> Int {
        var total = 0
        for holeNumber in 1...18 {
            if let score = bestBallScoreForTeam(teamName, holeNumber: holeNumber) {
                total += score
            }
        }
        return total
    }
    
    // Calculate total best ball NET score for a team (for stroke play)
    func totalBestBallNetScoreForTeam(_ teamName: String) -> Int {
        var total = 0
        for holeNumber in 1...18 {
            if let score = bestBallNetScoreForTeam(teamName, holeNumber: holeNumber) {
                total += score
            }
        }
        return total
    }
    
    // Get Best Ball standings (sorted by total NET score, lowest first)
    var bestBallStandings: [(teamName: String, score: Int)] {
        return teamNames.map { teamName in
            (teamName: teamName, score: totalBestBallNetScoreForTeam(teamName))
        }.sorted { $0.score < $1.score } // Sort by score ascending (lower is better)
    }
    
    // Check if game is completed (all 18 holes have scores for all players)
    var isGameCompleted: Bool {
        guard !playersArray.isEmpty else { return false }
        
        for holeNum in 1...18 {
            guard let holeScore = holesScoresArray.first(where: { $0.holeNumber == holeNum }) else {
                return false
            }
            for player in playersArray {
                if holeScore.scores[player.id] == nil {
                    return false
                }
            }
        }
        return true
    }
    
    // Check if game is from a previous day
    var isFromPreviousDay: Bool {
        let calendar = Calendar.current
        return !calendar.isDateInToday(date) && date < Date()
    }
    
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
    
    // Calculate Stableford points for a specific hole
    // Uses configurable point values from StablefordSettings
    func stablefordPointsForHole(player: Player, holeNumber: Int) -> Int? {
        guard let course = course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }),
              let gross = holesScoresArray.first(where: { $0.holeNumber == holeNumber })?.scores[player.id] else {
            return nil
        }
        
        // Calculate net score
        let strokes = strokesForHole(player: player, holeHandicap: hole.mensHandicap, useHalfHandicap: false)
        let netScore = gross - strokes
        
        // Calculate points based on net score relative to par
        let scoreRelativeToPar = netScore - hole.par
        
        // Use configurable point values from settings
        return StablefordSettings.shared.pointsForScore(scoreRelativeToPar: scoreRelativeToPar)
    }
    
    // Calculate total Stableford points for a player
    func totalStablefordPoints(player: Player) -> Int {
        var totalPoints = 0
        for holeNumber in 1...18 {
            if let points = stablefordPointsForHole(player: player, holeNumber: holeNumber) {
                totalPoints += points
            }
        }
        return totalPoints
    }
    
    // Get Stableford standings (sorted by total points, highest first)
    var stablefordStandings: [(player: Player, points: Int)] {
        return playersArray.sortedWithCurrentUserFirst().map { player in
            (player: player, points: totalStablefordPoints(player: player))
        }.sorted { $0.points > $1.points } // Sort by points descending
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
            // Return in sorted order (current user first) to match display order
            return playersArray.sortedWithCurrentUserFirst().map { player in
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
        
        // Return in sorted order (current user first) to match display order
        return playersArray.sortedWithCurrentUserFirst().map { player in
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

