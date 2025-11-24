//
//  TeamStablefordScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 12/19/25.
//

import SwiftUI
import SwiftData

struct TeamStablefordScorecardView: View {
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
    
    // Point system text for header
    private var pointSystemText: String {
        let settings = StablefordSettings.shared
        return "Points: DE(\(settings.pointsForDoubleEagle)) E(\(settings.pointsForEagle)) B(\(settings.pointsForBirdie)) P(\(settings.pointsForPar)) Bo(\(settings.pointsForBogey)) DB+(\(settings.pointsForDoubleBogey))"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
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
                        Text("Format: Team Stableford")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    // Point system reference
                    HStack {
                        Text(pointSystemText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Team columns
                if game.teamNames.count != 2 {
                    Text("Team Stableford requires exactly 2 teams")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    let team1Name = game.teamNames[0]
                    let team2Name = game.teamNames[1]
                    let team1Players = game.playersForTeam(team1Name)
                    let team2Players = game.playersForTeam(team2Name)
                    
                    // Header row with Par/HCP and team/player names
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
                                .foregroundColor(.blue)
                            ForEach(team1Players.sortedWithCurrentUserFirst()) { player in
                                Text(displayName(for: player))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Team 2 column
                        VStack(spacing: 2) {
                            Text(team2Name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            ForEach(team2Players.sortedWithCurrentUserFirst()) { player in
                                Text(displayName(for: player))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.tertiarySystemBackground))
                    
                    // Hole rows
                    ForEach(1...18, id: \.self) { holeNum in
                        TeamStablefordHoleRow(holeNumber: holeNum, game: game, course: game.course, team1Name: team1Name, team2Name: team2Name)
                    }
                    
                    // Total rows
                    Divider()
                    TeamStablefordTotalRow(label: "Front 9", game: game, holes: 1...9, team1Name: team1Name, team2Name: team2Name)
                    TeamStablefordTotalRow(label: "Back 9", game: game, holes: 10...18, team1Name: team1Name, team2Name: team2Name)
                    TeamStablefordTotalRow(label: "Total", game: game, holes: 1...18, team1Name: team1Name, team2Name: team2Name)
                        .fontWeight(.bold)
                        .background(Color(.quaternarySystemFill))
                    
                    // Standings
                    Divider()
                    TeamStablefordStandingsRow(game: game)
                }
            }
        }
    }
}

struct TeamStablefordHoleRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    let team1Name: String
    let team2Name: String
    @State private var showingScoreEditor = false
    
    var body: some View {
        HStack(spacing: 0) {
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
            
            // Team 1 scores and points
            let team1Players = game.playersForTeam(team1Name)
            VStack(spacing: 2) {
                ForEach(team1Players.sortedWithCurrentUserFirst()) { player in
                    let gross = getScore(for: player)
                    let net = gross != nil ? game.netScoreForHole(player: player, holeNumber: holeNumber) : nil
                    let points = gross != nil ? game.stablefordPointsForHole(player: player, holeNumber: holeNumber) : nil
                    
                    if let grossScore = gross {
                        Text("\(grossScore)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        if let netScore = net {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let pointsValue = points {
                            Text("\(pointsValue) pts")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(pointsColor(for: pointsValue))
                        }
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                // Team total points for this hole
                let team1Total = team1Players.reduce(0) { total, player in
                    total + (game.stablefordPointsForHole(player: player, holeNumber: holeNumber) ?? 0)
                }
                if team1Total > 0 {
                    Text("Team: \(team1Total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .onTapGesture {
                showingScoreEditor = true
            }
            
            // Team 2 scores and points
            let team2Players = game.playersForTeam(team2Name)
            VStack(spacing: 2) {
                ForEach(team2Players.sortedWithCurrentUserFirst()) { player in
                    let gross = getScore(for: player)
                    let net = gross != nil ? game.netScoreForHole(player: player, holeNumber: holeNumber) : nil
                    let points = gross != nil ? game.stablefordPointsForHole(player: player, holeNumber: holeNumber) : nil
                    
                    if let grossScore = gross {
                        Text("\(grossScore)")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        if let netScore = net {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let pointsValue = points {
                            Text("\(pointsValue) pts")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(pointsColor(for: pointsValue))
                        }
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                // Team total points for this hole
                let team2Total = team2Players.reduce(0) { total, player in
                    total + (game.stablefordPointsForHole(player: player, holeNumber: holeNumber) ?? 0)
                }
                if team2Total > 0 {
                    Text("Team: \(team2Total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
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
    
    private func pointsColor(for points: Int) -> Color {
        let settings = StablefordSettings.shared
        
        // Compare against configured point values
        if points >= settings.pointsForDoubleEagle {
            return .green // Double Eagle or better
        } else if points == settings.pointsForEagle {
            return .green // Eagle
        } else if points == settings.pointsForBirdie {
            return .blue // Birdie
        } else if points == settings.pointsForPar {
            return .primary // Par
        } else if points == settings.pointsForBogey {
            return .orange // Bogey
        } else {
            return .red // Double Bogey or worse
        }
    }
}

struct TeamStablefordTotalRow: View {
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
            
            // Team 1 total
            let team1Players = game.playersForTeam(team1Name)
            let team1Total = holes.reduce(0) { total, holeNum in
                total + game.playersForTeam(team1Name).reduce(0) { playerTotal, player in
                    playerTotal + (game.stablefordPointsForHole(player: player, holeNumber: holeNum) ?? 0)
                }
            }
            
            VStack(spacing: 2) {
                // Individual player totals
                ForEach(team1Players.sortedWithCurrentUserFirst()) { player in
                    let playerTotal = holes.reduce(0) { total, holeNum in
                        total + (game.stablefordPointsForHole(player: player, holeNumber: holeNum) ?? 0)
                    }
                    if playerTotal > 0 {
                        Text("\(playerTotal)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                // Team total
                if team1Total > 0 {
                    Text("\(team1Total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Team 2 total
            let team2Players = game.playersForTeam(team2Name)
            let team2Total = holes.reduce(0) { total, holeNum in
                total + game.playersForTeam(team2Name).reduce(0) { playerTotal, player in
                    playerTotal + (game.stablefordPointsForHole(player: player, holeNumber: holeNum) ?? 0)
                }
            }
            
            VStack(spacing: 2) {
                // Individual player totals
                ForEach(team2Players.sortedWithCurrentUserFirst()) { player in
                    let playerTotal = holes.reduce(0) { total, holeNum in
                        total + (game.stablefordPointsForHole(player: player, holeNumber: holeNum) ?? 0)
                    }
                    if playerTotal > 0 {
                        Text("\(playerTotal)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                // Team total
                if team2Total > 0 {
                    Text("\(team2Total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.top, 2)
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

struct TeamStablefordStandingsRow: View {
    @Bindable var game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team Standings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(Array(game.teamStablefordStandings.enumerated()), id: \.element.teamName) { index, standing in
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
                    
                    // Total points
                    Text("\(standing.points) points")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(index == 0 ? .blue : .primary)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(index == 0 ? Color(.secondarySystemBackground) : Color.clear)
            }
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
    let game = Game(course: course, players: [player1, player2, player3, player4], gameFormat: "team_stableford", teamAssignments: ["Team 1": [player1.id, player2.id], "Team 2": [player3.id, player4.id]])
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(player3)
    container.mainContext.insert(player4)
    container.mainContext.insert(game)
    
    return TeamStablefordScorecardView(game: game)
        .modelContainer(container)
}

