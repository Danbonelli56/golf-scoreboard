//
//  BestBallScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import SwiftUI
import SwiftData

struct BestBallScorecardView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    
    // Helper to extract first name
    func firstName(from fullName: String) -> String {
        fullName.components(separatedBy: " ").first ?? fullName
    }
    
    // Helper to extract last initial
    func lastInitial(from fullName: String) -> String? {
        let parts = fullName.components(separatedBy: " ")
        if parts.count > 1, let lastPart = parts.last, !lastPart.isEmpty {
            return String(lastPart.prefix(1)).uppercased()
        }
        return nil
    }
    
    // Display name for player - first name, or first name + last initial if duplicate first names
    func displayName(for player: Player) -> String {
        let players = game.playersArray
        let playerFirstName = firstName(from: player.name)
        
        // Check if there are multiple players with the same first name
        let duplicateFirstNames = players.filter { firstName(from: $0.name) == playerFirstName }.count > 1
        
        if duplicateFirstNames {
            // Show first name + last initial
            if let lastInitial = lastInitial(from: player.name) {
                return "\(playerFirstName) \(lastInitial)."
            }
        }
        
        // Just show first name
        return playerFirstName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header with match play status
            VStack(spacing: 0) {
                // Course info header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(game.course?.name ?? "Unknown Course")
                            .font(.headline)
                        Spacer()
                        Text(game.date, format: .dateTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tee color display
                    if let teeColor = game.effectiveTeeColor {
                        HStack {
                            Text("Tees: \(teeColor)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Game format indicator
                    HStack {
                        if game.gameFormat == "bestball_matchplay" {
                            Text("Format: Best Ball Match Play")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        } else {
                            Text("Format: Best Ball")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Match play status bar (fixed, always visible)
                if game.gameFormat == "bestball_matchplay" {
                    let matchStatus = game.matchPlayStatus
                    HStack {
                        Spacer()
                        Text(matchStatus.status)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.green)
                }
                
                Divider()
            }
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                
                // Check if teams are set up
                if game.teamNames.isEmpty {
                    Text("Teams not configured. Please set up teams in game settings.")
                        .foregroundColor(.secondary)
                        .padding()
                } else if game.teamNames.count != 2 {
                    Text("Best Ball requires exactly 2 teams. Current: \(game.teamNames.count) teams.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Team headers
                    let team1Name = game.teamNames[0]
                    let team2Name = game.teamNames[1]
                    let team1Players = game.playersForTeam(team1Name)
                    let team2Players = game.playersForTeam(team2Name)
                    
                    // Header row with Par/HCP and team columns
                    HStack(spacing: 0) {
                        Text("Hole")
                            .frame(width: 60)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Par")
                            .frame(width: 50)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("HCP")
                            .frame(width: 50)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        // Team 1 column
                        VStack(spacing: 2) {
                            Text(team1Name)
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(team1Players) { player in
                                Text(displayName(for: player))
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Team 2 column
                        VStack(spacing: 2) {
                            Text(team2Name)
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(team2Players) { player in
                                Text(displayName(for: player))
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.tertiarySystemBackground))
                    
                    // Match play running score header (if match play)
                    if game.gameFormat == "bestball_matchplay" {
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 60)
                            Text("")
                                .frame(width: 50)
                            Text("")
                                .frame(width: 50)
                            
                            // Running match score
                            VStack(spacing: 2) {
                                let matchStatus = game.matchPlayStatus
                                if matchStatus.team1HolesUp > 0 {
                                    Text("\(matchStatus.team1HolesUp) up")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                } else if matchStatus.team2HolesUp > 0 {
                                    Text("\(matchStatus.team2HolesUp) down")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                } else {
                                    Text("AS")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(spacing: 2) {
                                let matchStatus = game.matchPlayStatus
                                if matchStatus.team2HolesUp > 0 {
                                    Text("\(matchStatus.team2HolesUp) up")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                } else if matchStatus.team1HolesUp > 0 {
                                    Text("\(matchStatus.team1HolesUp) down")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                } else {
                                    Text("AS")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .background(Color(.tertiarySystemBackground))
                    }
                    
                    // Hole rows
                    ForEach(1...18, id: \.self) { holeNum in
                        BestBallHoleRow(
                            holeNumber: holeNum,
                            game: game,
                            course: game.course,
                            team1Name: team1Name,
                            team2Name: team2Name
                        )
                    }
                    
                    // Total rows (only for stroke play - match play doesn't use totals)
                    if game.gameFormat == "bestball" {
                        Divider()
                        BestBallTotalRow(label: "Front 9", game: game, holes: 1...9, team1Name: team1Name, team2Name: team2Name)
                        BestBallTotalRow(label: "Back 9", game: game, holes: 10...18, team1Name: team1Name, team2Name: team2Name)
                        BestBallTotalRow(label: "Total", game: game, holes: 1...18, team1Name: team1Name, team2Name: team2Name)
                            .fontWeight(.bold)
                            .background(Color(.quaternarySystemFill))
                    }
                    
                    // Standings (only for stroke play)
                    if game.gameFormat != "bestball_matchplay" {
                        Divider()
                        BestBallStandingsRow(game: game)
                    } else {
                        // Match play summary
                        Divider()
                        BestBallMatchPlaySummaryRow(game: game, team1Name: team1Name, team2Name: team2Name)
                    }
                }
                }
            }
        }
    }
}

struct BestBallHoleRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    let team1Name: String
    let team2Name: String
    @State private var showingScoreEditor = false
    
    var body: some View {
        let isMatchPlay = game.gameFormat == "bestball_matchplay"
        let holeWinner = isMatchPlay ? game.matchPlayHoleWinner(holeNumber: holeNumber) : nil
        let team1Won = holeWinner == team1Name
        let team2Won = holeWinner == team2Name
        
        return HStack(spacing: 0) {
            // Hole number
            Text("\(holeNumber)")
                .frame(width: 60)
                .font(.caption)
                .fontWeight(.medium)
            
            // Par
            Text(parText)
                .frame(width: 50)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Handicap
            Text(hcpText)
                .frame(width: 50)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Team 1 scores
            VStack(spacing: 2) {
                let team1Players = game.playersForTeam(team1Name)
                let team1Best = game.bestBallScoreForTeam(team1Name, holeNumber: holeNumber)
                let team1BestNet = game.bestBallNetScoreForTeam(team1Name, holeNumber: holeNumber)
                
                ForEach(team1Players) { player in
                    let score = getScore(for: player)
                    let getsStroke = game.playerGetsStrokeOnHole(player: player, holeNumber: holeNumber)
                    if let scoreValue = score {
                        let isBest = scoreValue == team1Best
                        Text("\(scoreValue)")
                            .font(.caption2)
                            .foregroundColor(isBest ? .green : .primary)
                            .fontWeight(isBest ? .semibold : .regular)
                        
                        // Show net score for both Best Ball formats (stroke play and match play)
                        if isMatchPlay || game.gameFormat == "bestball" {
                            if let netScore = game.netScoreForHole(player: player, holeNumber: holeNumber) {
                                Text("(\(netScore))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Show "*" if player gets a stroke
                        if getsStroke {
                            Text("*")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Show "*" instead of "-" if player gets a stroke (even without a score yet)
                        Text(getsStroke ? "*" : "-")
                            .font(.caption2)
                            .foregroundColor(getsStroke ? .blue : .secondary)
                    }
                }
                
                // Show best ball net score for both formats
                if let bestNet = team1BestNet {
                    if isMatchPlay {
                        Text("Net: \(bestNet)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(team1Won ? .green : (holeWinner == nil ? .blue : .secondary))
                    } else if game.gameFormat == "bestball" {
                        Text("Net: \(bestNet)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(team1Won ? Color.green.opacity(0.2) : Color.clear)
            .onTapGesture {
                showingScoreEditor = true
            }
            
            // Team 2 scores
            VStack(spacing: 2) {
                let team2Players = game.playersForTeam(team2Name)
                let team2Best = game.bestBallScoreForTeam(team2Name, holeNumber: holeNumber)
                let team2BestNet = game.bestBallNetScoreForTeam(team2Name, holeNumber: holeNumber)
                
                ForEach(team2Players) { player in
                    let score = getScore(for: player)
                    let getsStroke = game.playerGetsStrokeOnHole(player: player, holeNumber: holeNumber)
                    if let scoreValue = score {
                        let isBest = scoreValue == team2Best
                        Text("\(scoreValue)")
                            .font(.caption2)
                            .foregroundColor(isBest ? .green : .primary)
                            .fontWeight(isBest ? .semibold : .regular)
                        
                        // Show net score for both Best Ball formats (stroke play and match play)
                        if isMatchPlay || game.gameFormat == "bestball" {
                            if let netScore = game.netScoreForHole(player: player, holeNumber: holeNumber) {
                                Text("(\(netScore))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Show "*" if player gets a stroke
                        if getsStroke {
                            Text("*")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Show "*" instead of "-" if player gets a stroke (even without a score yet)
                        Text(getsStroke ? "*" : "-")
                            .font(.caption2)
                            .foregroundColor(getsStroke ? .blue : .secondary)
                    }
                }
                
                // Show best ball net score for both formats
                if let bestNet = team2BestNet {
                    if isMatchPlay {
                        Text("Net: \(bestNet)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(team2Won ? .green : (holeWinner == nil ? .blue : .secondary))
                    } else if game.gameFormat == "bestball" {
                        Text("Net: \(bestNet)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(team2Won ? Color.green.opacity(0.2) : Color.clear)
            .onTapGesture {
                showingScoreEditor = true
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(holeNumber % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.3))
        .sheet(isPresented: $showingScoreEditor) {
            ScoreEditorView(holeNumber: holeNumber, game: game)
        }
    }
    
    private var parText: String {
        if let holes = course?.holes, let hole = holes.first(where: { $0.holeNumber == holeNumber }) {
            return "\(hole.par)"
        }
        return "-"
    }
    
    private var hcpText: String {
        if let holes = course?.holes, let hole = holes.first(where: { $0.holeNumber == holeNumber }) {
            return "\(hole.mensHandicap)"
        }
        return "-"
    }
    
    private func getScore(for player: Player) -> Int? {
        game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })?.scores[player.id]
    }
    
    // Helper to access strokesForHole (needs to be public or accessible)
    // Actually, we can access it through game since it's in the Game model
}

struct BestBallTotalRow: View {
    let label: String
    @Bindable var game: Game
    let holes: ClosedRange<Int>
    let team1Name: String
    let team2Name: String
    
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 60)
                .font(.caption)
                .fontWeight(.semibold)
            
            // Empty cells for Par and HCP columns
            Text("")
                .frame(width: 50)
            
            Text("")
                .frame(width: 50)
            
            // Team 1 total (using net scores)
            VStack(spacing: 2) {
                let team1Total = holes.reduce(0) { total, holeNum in
                    total + (game.bestBallNetScoreForTeam(team1Name, holeNumber: holeNum) ?? 0)
                }
                
                if team1Total > 0 {
                    Text("\(team1Total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Team 2 total (using net scores)
            VStack(spacing: 2) {
                let team2Total = holes.reduce(0) { total, holeNum in
                    total + (game.bestBallNetScoreForTeam(team2Name, holeNumber: holeNum) ?? 0)
                }
                
                if team2Total > 0 {
                    Text("\(team2Total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct BestBallStandingsRow: View {
    @Bindable var game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(Array(game.bestBallStandings.enumerated()), id: \.element.teamName) { index, standing in
                HStack {
                    // Position indicator
                    if index == 0 {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                    } else {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 24)
                    }
                    
                    // Team name
                    Text(standing.teamName)
                        .font(.subheadline)
                        .fontWeight(index == 0 ? .semibold : .regular)
                    
                    Spacer()
                    
                    // Total score
                    Text("\(standing.score)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(index == 0 ? .blue : .primary)
                    
                    // Show players on team
                    let teamPlayers = game.playersForTeam(standing.teamName)
                    if !teamPlayers.isEmpty {
                        Text("(\(teamPlayers.map { $0.name }.joined(separator: ", ")))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(index == 0 ? Color(.secondarySystemBackground) : Color.clear)
            }
        }
        .padding(.bottom, 8)
    }
}

struct BestBallMatchPlaySummaryRow: View {
    @Bindable var game: Game
    let team1Name: String
    let team2Name: String
    
    private var matchStats: (team1Wins: Int, team2Wins: Int, ties: Int) {
        var team1Wins = 0
        var team2Wins = 0
        var ties = 0
        
        for holeNumber in 1...18 {
            if let winner = game.matchPlayHoleWinner(holeNumber: holeNumber) {
                if winner == team1Name {
                    team1Wins += 1
                } else if winner == team2Name {
                    team2Wins += 1
                }
            } else {
                // Check if hole was played (has scores)
                let team1HasScore = game.bestBallNetScoreForTeam(team1Name, holeNumber: holeNumber) != nil
                let team2HasScore = game.bestBallNetScoreForTeam(team2Name, holeNumber: holeNumber) != nil
                if team1HasScore && team2HasScore {
                    ties += 1
                }
            }
        }
        
        return (team1Wins, team2Wins, ties)
    }
    
    var body: some View {
        let matchStatus = game.matchPlayStatus
        let stats = matchStats
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Match Summary")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team1Name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Holes Won: \(stats.team1Wins)")
                        .font(.caption)
                    Text("Holes Tied: \(stats.ties)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(team2Name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Holes Won: \(stats.team2Wins)")
                        .font(.caption)
                    Text("Holes Tied: \(stats.ties)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // Match status
            HStack {
                Spacer()
                Text(matchStatus.status)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    
    let course = GolfCourse(name: "Test Course")
    let player1 = Player(name: "John", handicap: 5.0)
    let player2 = Player(name: "Jane", handicap: 10.0)
    let player3 = Player(name: "Bob", handicap: 8.0)
    let player4 = Player(name: "Alice", handicap: 12.0)
    
    let teams = [
        "Team 1": [player1.id, player2.id],
        "Team 2": [player3.id, player4.id]
    ]
    
    let game = Game(course: course, players: [player1, player2, player3, player4], gameFormat: "bestball", teamAssignments: teams)
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(player3)
    container.mainContext.insert(player4)
    container.mainContext.insert(game)
    
    return BestBallScorecardView(game: game)
        .modelContainer(container)
}

