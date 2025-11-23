//
//  StablefordScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import SwiftUI
import SwiftData

struct StablefordScorecardView: View {
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
                        Text("Format: Stableford")
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
                
                // Player columns
                if game.playersArray.isEmpty {
                    Text("No players in this game")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Header row with Par/HCP and player names
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
                        
                        ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                            Text(displayName(for: player))
                                .frame(maxWidth: .infinity)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.tertiarySystemBackground))
                    
                    // Hole rows
                    ForEach(1...18, id: \.self) { holeNum in
                        StablefordHoleRow(holeNumber: holeNum, game: game, course: game.course)
                    }
                    
                    // Total rows
                    Divider()
                    StablefordTotalRow(label: "Front 9", game: game, holes: 1...9)
                    StablefordTotalRow(label: "Back 9", game: game, holes: 10...18)
                    StablefordTotalRow(label: "Total", game: game, holes: 1...18)
                        .fontWeight(.bold)
                        .background(Color(.quaternarySystemFill))
                    
                    // Standings
                    Divider()
                    StablefordStandingsRow(game: game)
                }
            }
        }
    }
}

struct StablefordHoleRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
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
            
            // Player scores and points
            ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                let gross = getScore(for: player)
                let net = gross != nil ? game.netScoreForHole(player: player, holeNumber: holeNumber) : nil
                let points = gross != nil ? game.stablefordPointsForHole(player: player, holeNumber: holeNumber) : nil
                
                VStack(spacing: 2) {
                    if let grossScore = gross {
                        // Show gross score
                        Text("\(grossScore)")
                            .font(.caption)
                            .foregroundColor(scoreColor(for: grossScore))
                        
                        // Show net score in parentheses
                        if let netScore = net {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show points prominently
                        if let pointsValue = points {
                            Text("\(pointsValue) pts")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(pointsColor(for: pointsValue))
                        }
                    } else {
                        Text("-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .onTapGesture {
                    showingScoreEditor = true
                }
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
    
    private func scoreColor(for score: Int?) -> Color {
        guard score != nil else { return .secondary }
        return .primary
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

struct StablefordTotalRow: View {
    let label: String
    @Bindable var game: Game
    let holes: ClosedRange<Int>
    
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
            
            ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                VStack(spacing: 2) {
                    // Calculate total points for these holes
                    let totalPoints = holes.reduce(0) { total, holeNum in
                        total + (game.stablefordPointsForHole(player: player, holeNumber: holeNum) ?? 0)
                    }
                    
                    // Calculate gross total
                    let grossTotal = holes.reduce(0) { total, holeNum in
                        total + (game.holesScoresArray.first(where: { $0.holeNumber == holeNum })?.scores[player.id] ?? 0)
                    }
                    
                    // Show gross total
                    if grossTotal > 0 {
                        Text("\(grossTotal)")
                            .font(.caption)
                    } else {
                        Text("-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Show total points prominently
                    if totalPoints > 0 {
                        Text("\(totalPoints) pts")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct StablefordStandingsRow: View {
    @Bindable var game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(Array(game.stablefordStandings.enumerated()), id: \.element.player.id) { index, standing in
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
                    
                    // Player name
                    Text(standing.player.name)
                        .font(.subheadline)
                        .fontWeight(index == 0 ? .semibold : .regular)
                    
                    Spacer()
                    
                    // Total points
                    Text("\(standing.points) points")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(index == 0 ? .blue : .primary)
                    
                    // Handicap
                    Text("HCP: \(String(format: "%.1f", standing.player.handicap))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
    let game = Game(course: course, players: [player1, player2], gameFormat: "stableford")
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(game)
    
    return StablefordScorecardView(game: game)
        .modelContainer(container)
}

