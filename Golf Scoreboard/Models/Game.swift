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
    // Presses for Nassau format: "matchType:startingHole:initiatingTeam|..." where matchType is "front9", "back9", or "overall"
    var nassauPresses: String? // Presses stored as string for SwiftData compatibility
    // Value per skin for Skins format (deprecated - use skinsPotPerPlayer instead)
    var skinsValuePerSkin: Double? // Amount each skin is worth (stored as optional for backward compatibility)
    // Pot amount per player for Skins format
    var skinsPotPerPlayer: Double? // Amount each player contributes to the pot
    // Whether skins carry over when tied (true) or are lost (false)
    var skinsCarryoverEnabled: Bool = true // Default to true for backward compatibility
    
    init(course: GolfCourse? = nil, players: [Player] = [], selectedTeeColor: String? = nil, date: Date? = nil, trackingPlayerIDs: [UUID]? = nil, gameFormat: String = "stroke", teamAssignments: [String: [UUID]]? = nil, skinsValuePerSkin: Double? = nil, skinsPotPerPlayer: Double? = nil, skinsCarryoverEnabled: Bool = true) {
        self.id = UUID()
        self.course = course
        self.date = date ?? Date()
        self.players = players
        self.holesScores = []
        self.createdAt = nil
        self.selectedTeeColor = selectedTeeColor
        self.gameFormat = gameFormat
        self.skinsValuePerSkin = skinsValuePerSkin
        self.skinsPotPerPlayer = skinsPotPerPlayer
        self.skinsCarryoverEnabled = skinsCarryoverEnabled
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
    // Works for both bestball_matchplay and nassau formats
    func matchPlayHoleWinner(holeNumber: Int) -> String? {
        guard (gameFormat == "bestball_matchplay" || gameFormat == "nassau"), teamNames.count == 2 else {
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
    
    // Calculate match play status for a range of holes (for Nassau: front 9, back 9, or overall)
    func matchPlayStatusForHoles(_ holes: ClosedRange<Int>) -> (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard (gameFormat == "bestball_matchplay" || gameFormat == "nassau"), teamNames.count == 2 else {
            return (0, 0, holes.count, "Not a match play game")
        }
        
        let team1Name = teamNames[0]
        let team2Name = teamNames[1]
        
        var team1Wins = 0
        var team2Wins = 0
        var holesPlayed = 0
        
        for holeNumber in holes {
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
        
        let holesRemaining = holes.count - holesPlayed
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
    
    // Calculate match play status (for bestball_matchplay - uses all 18 holes)
    var matchPlayStatus: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "bestball_matchplay", teamNames.count == 2 else {
            return (0, 0, 18, "Not a match play game")
        }
        
        return matchPlayStatusForHoles(1...18)
    }
    
    // Nassau match statuses
    var nassauFront9Status: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return (0, 0, 9, "Not a Nassau game")
        }
        return matchPlayStatusForHoles(1...9)
    }
    
    var nassauBack9Status: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return (0, 0, 9, "Not a Nassau game")
        }
        return matchPlayStatusForHoles(10...18)
    }
    
    var nassauOverallStatus: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return (0, 0, 18, "Not a Nassau game")
        }
        return matchPlayStatusForHoles(1...18)
    }
    
    // Parse presses from string format
    var presses: [(matchType: String, startingHole: Int, initiatingTeam: String)] {
        guard let pressesString = nassauPresses, !pressesString.isEmpty else {
            return []
        }
        
        var result: [(matchType: String, startingHole: Int, initiatingTeam: String)] = []
        let pressStrings = pressesString.split(separator: "|")
        
        for pressString in pressStrings {
            let parts = pressString.split(separator: ":")
            if parts.count == 3,
               let startingHole = Int(parts[1]) {
                result.append((
                    matchType: String(parts[0]),
                    startingHole: startingHole,
                    initiatingTeam: String(parts[2])
                ))
            }
        }
        
        return result
    }
    
    // Add a press
    func addPress(matchType: String, startingHole: Int, initiatingTeam: String) {
        let pressString = "\(matchType):\(startingHole):\(initiatingTeam)"
        if let existing = nassauPresses, !existing.isEmpty {
            nassauPresses = "\(existing)|\(pressString)"
        } else {
            nassauPresses = pressString
        }
    }
    
    // Calculate press match status (for a specific press)
    // Note: Presses are only valid for Front 9 and Back 9 matches, not the Overall match
    // A press is complete at the end of the match in which it was initiated:
    // - Front 9 press: starts on startingHole, ends after hole 9
    // - Back 9 press: starts on startingHole, ends after hole 18
    func pressMatchStatus(press: (matchType: String, startingHole: Int, initiatingTeam: String)) -> (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String) {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return (0, 0, 0, "Not a Nassau game")
        }
        
        // Determine hole range based on match type and starting hole
        // The press ends at the end of the match (hole 9 for front9, hole 18 for back9)
        let holeRange: ClosedRange<Int>
        switch press.matchType {
        case "front9":
            // Front 9 press: from starting hole to hole 9 (end of front 9)
            holeRange = max(press.startingHole, 1)...9
        case "back9":
            // Back 9 press: from starting hole to hole 18 (end of back 9)
            holeRange = max(press.startingHole, 10)...18
        case "overall":
            // Overall presses should not be created, but handle legacy data if it exists
            holeRange = press.startingHole...18
        default:
            return (0, 0, 0, "Invalid press type")
        }
        
        return matchPlayStatusForHoles(holeRange)
    }
    
    // Calculate Nassau points for a team
    // Each match (Front 9, Back 9, Overall) is worth 1 point
    // Each press is worth 1 point
    func nassauPointsForTeam(_ teamName: String) -> Double {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return 0.0
        }
        
        var points: Double = 0.0
        
        // Front 9 match: 1 point if won, 0.5 if halved, 0 if lost
        let front9Status = nassauFront9Status
        if front9Status.team1HolesUp > 0 && teamName == teamNames[0] {
            points += 1.0
        } else if front9Status.team2HolesUp > 0 && teamName == teamNames[1] {
            points += 1.0
        } else if front9Status.team1HolesUp == 0 && front9Status.team2HolesUp == 0 && front9Status.holesRemaining == 0 {
            // Match is halved (completed and all square)
            points += 0.5
        }
        
        // Back 9 match: 1 point if won, 0.5 if halved, 0 if lost
        let back9Status = nassauBack9Status
        if back9Status.team1HolesUp > 0 && teamName == teamNames[0] {
            points += 1.0
        } else if back9Status.team2HolesUp > 0 && teamName == teamNames[1] {
            points += 1.0
        } else if back9Status.team1HolesUp == 0 && back9Status.team2HolesUp == 0 && back9Status.holesRemaining == 0 {
            // Match is halved (completed and all square)
            points += 0.5
        }
        
        // Overall match: 1 point if won, 0.5 if halved, 0 if lost
        let overallStatus = nassauOverallStatus
        if overallStatus.team1HolesUp > 0 && teamName == teamNames[0] {
            points += 1.0
        } else if overallStatus.team2HolesUp > 0 && teamName == teamNames[1] {
            points += 1.0
        } else if overallStatus.team1HolesUp == 0 && overallStatus.team2HolesUp == 0 && overallStatus.holesRemaining == 0 {
            // Match is halved (completed and all square)
            points += 0.5
        }
        
        // Presses: 1 point each if won, 0.5 if halved, 0 if lost
        for press in presses {
            let pressStatus = pressMatchStatus(press: press)
            if pressStatus.team1HolesUp > 0 && teamName == teamNames[0] {
                points += 1.0
            } else if pressStatus.team2HolesUp > 0 && teamName == teamNames[1] {
                points += 1.0
            } else if pressStatus.team1HolesUp == 0 && pressStatus.team2HolesUp == 0 && pressStatus.holesRemaining == 0 {
                // Press is halved (completed and all square)
                points += 0.5
            }
        }
        
        return points
    }
    
    // Find the next hole to be played in a given match
    func nextHoleForMatch(matchType: String) -> Int? {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return nil
        }
        
        let team1Name = teamNames[0]
        let team2Name = teamNames[1]
        
        let holeRange: ClosedRange<Int>
        switch matchType {
        case "front9":
            holeRange = 1...9
        case "back9":
            holeRange = 10...18
        case "overall":
            holeRange = 1...18
        default:
            return nil
        }
        
        // Find the first hole in the range where both teams don't have scores
        for holeNumber in holeRange {
            let team1HasScore = bestBallNetScoreForTeam(team1Name, holeNumber: holeNumber) != nil
            let team2HasScore = bestBallNetScoreForTeam(team2Name, holeNumber: holeNumber) != nil
            if !team1HasScore || !team2HasScore {
                return holeNumber
            }
        }
        
        // All holes in the match have been played
        return nil
    }
    
    // Determine which team is losing (can press) in a given match, and by how much
    func losingTeamForMatch(matchType: String) -> (teamName: String, holesDown: Int)? {
        guard gameFormat == "nassau", teamNames.count == 2 else {
            return nil
        }
        
        let status: (team1HolesUp: Int, team2HolesUp: Int, holesRemaining: Int, status: String)
        switch matchType {
        case "front9":
            status = nassauFront9Status
        case "back9":
            status = nassauBack9Status
        case "overall":
            status = nassauOverallStatus
        default:
            return nil
        }
        
        let team1Name = teamNames[0]
        let team2Name = teamNames[1]
        
        // If team2 is up, team1 is losing
        if status.team2HolesUp > 0 {
            return (teamName: team1Name, holesDown: status.team2HolesUp)
        }
        // If team1 is up, team2 is losing
        else if status.team1HolesUp > 0 {
            return (teamName: team2Name, holesDown: status.team1HolesUp)
        }
        
        // Match is all square, no one can press
        return nil
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
    
    // Calculate total Stableford points for a team (sum of all players' points)
    func totalStablefordPointsForTeam(_ teamName: String) -> Int {
        let teamPlayers = playersForTeam(teamName)
        var totalPoints = 0
        
        for player in teamPlayers {
            totalPoints += totalStablefordPoints(player: player)
        }
        
        return totalPoints
    }
    
    // Get Team Stableford standings (sorted by total points, highest first)
    var teamStablefordStandings: [(teamName: String, points: Int)] {
        return teamNames.map { teamName in
            (teamName: teamName, points: totalStablefordPointsForTeam(teamName))
        }.sorted { $0.points > $1.points } // Sort by points descending (higher is better)
    }
    
    // Calculate average handicap for a team (for scramble format)
    func averageHandicapForTeam(_ teamName: String) -> Double {
        let teamPlayers = playersForTeam(teamName)
        guard !teamPlayers.isEmpty else { return 0.0 }
        
        let totalHandicap = teamPlayers.reduce(0.0) { $0 + $1.handicap }
        return totalHandicap / Double(teamPlayers.count)
    }
    
    // Get scramble team score for a hole (one score per team)
    // In scramble, the team plays one ball, so we store the score under one player per team
    // We'll use the first player's ID as the team's score identifier
    func scrambleScoreForTeam(_ teamName: String, holeNumber: Int) -> Int? {
        let teamPlayers = playersForTeam(teamName)
        guard let firstPlayer = teamPlayers.first else { return nil }
        
        // In scramble, the score is stored under one player (typically the first player)
        // Check if any player on the team has a score for this hole
        let holeScore = holesScoresArray.first(where: { $0.holeNumber == holeNumber })
        guard let hole = holeScore else { return nil }
        
        // Return the score for the first player (representing the team's scramble score)
        return hole.scores[firstPlayer.id]
    }
    
    // Calculate net score for a scramble team on a specific hole
    func scrambleNetScoreForTeam(_ teamName: String, holeNumber: Int) -> Int? {
        guard let grossScore = scrambleScoreForTeam(teamName, holeNumber: holeNumber) else {
            return nil
        }
        
        guard let course = course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }) else {
            return nil
        }
        
        // Calculate strokes based on team's average handicap
        let teamHandicap = averageHandicapForTeam(teamName)
        let handicapInt = Int(round(teamHandicap))
        
        // Use same logic as strokesForHole(player:holeHandicap:useHalfHandicap:)
        var strokes: Int
        if handicapInt <= 18 {
            strokes = hole.mensHandicap <= handicapInt ? 1 : 0
        } else {
            // For handicap > 18: base stroke on all holes + extra on hardest holes
            let baseStrokes = 1
            let remainder = handicapInt % 18
            if remainder > 0 && hole.mensHandicap <= remainder {
                strokes = baseStrokes + 1
            } else {
                strokes = baseStrokes
            }
        }
        
        let netScore = max(0, grossScore - strokes)
        return netScore
    }
    
    // Calculate total scramble score for a team (gross)
    func totalScrambleScoreForTeam(_ teamName: String) -> Int {
        var total = 0
        for holeNumber in 1...18 {
            if let score = scrambleScoreForTeam(teamName, holeNumber: holeNumber) {
                total += score
            }
        }
        return total
    }
    
    // Calculate total scramble net score for a team
    func totalScrambleNetScoreForTeam(_ teamName: String) -> Int {
        var total = 0
        for holeNumber in 1...18 {
            if let netScore = scrambleNetScoreForTeam(teamName, holeNumber: holeNumber) {
                total += netScore
            }
        }
        return total
    }
    
    // Get Scramble standings (sorted by total net score, lowest first)
    var scrambleStandings: [(teamName: String, grossScore: Int, netScore: Int, handicap: Double)] {
        return teamNames.map { teamName in
            (teamName: teamName, 
             grossScore: totalScrambleScoreForTeam(teamName),
             netScore: totalScrambleNetScoreForTeam(teamName),
             handicap: averageHandicapForTeam(teamName))
        }.sorted { $0.netScore < $1.netScore } // Sort by net score ascending (lower is better)
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
    
    // Check if a player gets a handicap stroke on a specific hole
    func playerGetsStrokeOnHole(player: Player, holeNumber: Int, useHalfHandicap: Bool = false) -> Bool {
        guard let course = course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }) else {
            return false
        }
        return strokesForHole(player: player, holeHandicap: hole.mensHandicap, useHalfHandicap: useHalfHandicap) > 0
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
    
    // MARK: - Skins Game Calculations
    
    // Get the winner of a skin for a specific hole (based on net score)
    // Returns the player with the lowest net score, or nil if there's a tie (carryover)
    func skinsWinnerForHole(_ holeNumber: Int) -> Player? {
        guard gameFormat == "skins" else { return nil }
        
        var bestNetScore: Int?
        var winner: Player?
        var isTie = false
        
        for player in playersArray {
            guard let netScore = netScoreForHole(player: player, holeNumber: holeNumber) else {
                continue // Player doesn't have a score for this hole yet
            }
            
            if bestNetScore == nil || netScore < bestNetScore! {
                // New best score
                bestNetScore = netScore
                winner = player
                isTie = false
            } else if netScore == bestNetScore {
                // Tie for best score - no winner (carryover)
                isTie = true
                winner = nil
            }
        }
        
        // If there's a tie, return nil (carryover)
        return isTie ? nil : winner
    }
    
    // Calculate how many skins are carrying over to a specific hole
    // This counts all previous holes that were tied (carryovers)
    func skinsCarryoverForHole(_ holeNumber: Int) -> Int {
        guard gameFormat == "skins" else { return 0 }
        
        var carryover = 0
        
        // Count carryovers from previous holes (holes 1 to holeNumber-1)
        for prevHole in 1..<holeNumber {
            if skinsWinnerForHole(prevHole) == nil {
                // Previous hole was tied, so it carries over
                carryover += 1
            }
        }
        
        return carryover
    }
    
    // Get total skins won per player
    func skinsPerPlayer() -> [UUID: Int] {
        guard gameFormat == "skins" else { return [:] }
        
        var skins: [UUID: Int] = [:]
        
        // Initialize all players with 0 skins
        for player in playersArray {
            skins[player.id] = 0
        }
        
        // Track accumulated carryover skins (only if carryover is enabled)
        var accumulatedCarryover = 0
        
        // Count skins won per player
        for holeNumber in 1...18 {
            if let winner = skinsWinnerForHole(holeNumber) {
                // This hole has a winner - they get all accumulated carryover skins plus this hole's skin
                let totalSkinsForHole = accumulatedCarryover + 1
                skins[winner.id, default: 0] += totalSkinsForHole
                // Reset carryover since it was consumed
                accumulatedCarryover = 0
            } else {
                // This hole is tied
                if skinsCarryoverEnabled {
                    // Add to carryover if carryover is enabled
                    accumulatedCarryover += 1
                } else {
                    // If carryover is disabled, tied holes are lost (no skin awarded)
                    // Just reset carryover (don't accumulate)
                    accumulatedCarryover = 0
                }
            }
        }
        
        return skins
    }
    
    // Calculate net payouts per player (positive = won money, negative = lost money)
    // New system: Pot is divided by number of skins awarded, each player gets payout based on skins won
    // Old system (backward compatibility): Player-to-player differences based on value per skin
    func skinsPayouts() -> [UUID: Double] {
        guard gameFormat == "skins" else {
            return [:]
        }
        
        let skins = skinsPerPlayer()
        
        // Calculate total skins won
        let totalSkinsWon = skins.values.reduce(0, +)
        
        // Initialize payouts to zero
        var payouts: [UUID: Double] = [:]
        for player in playersArray {
            payouts[player.id] = 0.0
        }
        
        // Use new pot-based system if pot per player is set
        if let potPerPlayer = skinsPotPerPlayer, potPerPlayer > 0 {
            let totalPot = Double(playersArray.count) * potPerPlayer
            
            guard totalSkinsWon > 0 else {
                // No skins won yet, all players have paid in but no payouts
                // Each player has already contributed, so net is -potPerPlayer
                for player in playersArray {
                    payouts[player.id] = -potPerPlayer
                }
                return payouts
            }
            
            // Calculate value per skin: total pot divided by number of skins
            let valuePerSkin = totalPot / Double(totalSkinsWon)
            
            // Calculate payouts: (skins won × value per skin) - initial contribution
            for player in playersArray {
                let playerSkins = skins[player.id] ?? 0
                let winnings = Double(playerSkins) * valuePerSkin
                payouts[player.id] = winnings - potPerPlayer
            }
            
            return payouts
        }
        
        // Fallback to old system for backward compatibility
        guard let valuePerSkin = skinsValuePerSkin, valuePerSkin > 0 else {
            return payouts
        }
        
        guard totalSkinsWon > 0 else {
            return payouts
        }
        
        // Calculate player-to-player payments (old system)
        for i in 0..<playersArray.count {
            let player1 = playersArray[i]
            let player1Skins = skins[player1.id] ?? 0
            let player1Value = Double(player1Skins) * valuePerSkin
            
            for j in (i+1)..<playersArray.count {
                let player2 = playersArray[j]
                let player2Skins = skins[player2.id] ?? 0
                let player2Value = Double(player2Skins) * valuePerSkin
                
                // Calculate the difference
                let difference = player2Value - player1Value
                
                if difference > 0 {
                    // Player 1 pays Player 2
                    payouts[player1.id] = (payouts[player1.id] ?? 0.0) - difference
                    payouts[player2.id] = (payouts[player2.id] ?? 0.0) + difference
                } else if difference < 0 {
                    // Player 2 pays Player 1
                    payouts[player2.id] = (payouts[player2.id] ?? 0.0) + difference // difference is negative
                    payouts[player1.id] = (payouts[player1.id] ?? 0.0) - difference // -difference is positive
                }
                // If difference == 0, no payment needed
            }
        }
        
        return payouts
    }
    
    // Get total pot for skins game
    var skinsTotalPot: Double? {
        guard gameFormat == "skins",
              let potPerPlayer = skinsPotPerPlayer,
              potPerPlayer > 0 else {
            return nil
        }
        return Double(playersArray.count) * potPerPlayer
    }
    
    // Get value per skin (calculated from pot)
    var skinsCalculatedValuePerSkin: Double? {
        guard gameFormat == "skins",
              let totalPot = skinsTotalPot else {
            // Fallback to old system
            return skinsValuePerSkin
        }
        
        let skins = skinsPerPlayer()
        let totalSkinsWon = skins.values.reduce(0, +)
        
        guard totalSkinsWon > 0 else {
            return nil
        }
        
        return totalPot / Double(totalSkinsWon)
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

