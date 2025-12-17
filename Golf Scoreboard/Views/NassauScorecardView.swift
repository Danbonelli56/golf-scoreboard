//
//  NassauScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 12/15/25.
//

import SwiftUI
import SwiftData

struct NassauScorecardView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @State private var showingPressSheet = false
    @State private var isEditMode = false
    @State private var showingScoreEditor = false
    @State private var selectedHoleNumber: Int = 1
    
    private func findFirstEmptyHole() -> Int? {
        let players = game.playersArray
        guard !players.isEmpty else { return 1 }
        
        for holeNumber in 1...18 {
            let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
            
            guard let holeScore = holeScore else {
                return holeNumber
            }
            
            let scores = holeScore.scores
            let allPlayersHaveScores = players.allSatisfy { player in
                scores[player.id] != nil
            }
            
            if !allPlayersHaveScores {
                return holeNumber
            }
        }
        
        return nil
    }
    
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
            // Fixed header with Nassau match statuses
            VStack(spacing: 0) {
                // Course info header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(game.course?.name ?? "Unknown Course")
                            .font(.headline)
                        Spacer()
                        
                        Button {
                            isEditMode.toggle()
                        } label: {
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text(game.date, format: .dateTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(isEditMode ? "Tap any hole to edit" : "Tap to enter next score")
                            .font(.caption2)
                            .foregroundColor(isEditMode ? .blue : .secondary)
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
                        Text("Format: Nassau")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                // Nassau match status bars (fixed, always visible)
                VStack(spacing: 0) {
                    // Front 9 Match
                    let front9Status = game.nassauFront9Status
                    HStack {
                        Text("Front 9: \(front9Status.status)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(front9Status.team1HolesUp > 0 || front9Status.team2HolesUp > 0 ? Color.green : Color.blue)
                    
                    // Back 9 Match
                    let back9Status = game.nassauBack9Status
                    HStack {
                        Text("Back 9: \(back9Status.status)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(back9Status.team1HolesUp > 0 || back9Status.team2HolesUp > 0 ? Color.green : Color.blue)
                    
                    // Overall Match
                    let overallStatus = game.nassauOverallStatus
                    HStack {
                        Text("Overall: \(overallStatus.status)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(overallStatus.team1HolesUp > 0 || overallStatus.team2HolesUp > 0 ? Color.green : Color.blue)
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
                    Text("Nassau requires exactly 2 teams. Current: \(game.teamNames.count) teams.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    let team1Name = game.teamNames[0]
                    let team2Name = game.teamNames[1]
                    let team1Players = game.playersForTeam(team1Name)
                    let team2Players = game.playersForTeam(team2Name)
                    
                    // Team headers
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
                    
                    // Hole rows
                    ForEach(1...18, id: \.self) { holeNum in
                        NassauHoleRow(
                            holeNumber: holeNum,
                            game: game,
                            course: game.course,
                            team1Name: team1Name,
                            team2Name: team2Name,
                            isEditMode: isEditMode,
                            onTap: {
                                selectedHoleNumber = isEditMode ? holeNum : (findFirstEmptyHole() ?? holeNum)
                                showingScoreEditor = true
                            }
                        )
                    }
                    
                    // Match summaries
                    Divider()
                    NassauMatchSummaryRow(game: game, team1Name: team1Name, team2Name: team2Name)
                    
                    // Presses section
                    if !game.presses.isEmpty {
                        Divider()
                        NassauPressesRow(game: game, team1Name: team1Name, team2Name: team2Name)
                    }
                    
                    // Add Press button
                    Divider()
                    let availablePresses = getAvailablePresses()
                    Button(action: {
                        showingPressSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Press")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .disabled(availablePresses.isEmpty)
                    .padding()
                }
                }
            }
        }
        .sheet(isPresented: $showingPressSheet) {
            NassauPressSheet(game: game)
        }
        .sheet(isPresented: $showingScoreEditor) {
            ScoreEditorView(holeNumber: selectedHoleNumber, game: game)
        }
    }
    
    // Helper to get available presses
    // Note: Presses are only valid for Front 9 and Back 9 matches, not the Overall match
    private func getAvailablePresses() -> [(matchType: String, matchName: String, losingTeam: String, holesDown: Int, nextHole: Int)] {
        var presses: [(matchType: String, matchName: String, losingTeam: String, holesDown: Int, nextHole: Int)] = []
        
        let matchTypes = [
            ("front9", "Front 9"),
            ("back9", "Back 9")
        ]
        
        for (matchType, matchName) in matchTypes {
            if let losingTeam = game.losingTeamForMatch(matchType: matchType),
               let nextHole = game.nextHoleForMatch(matchType: matchType) {
                presses.append((
                    matchType: matchType,
                    matchName: matchName,
                    losingTeam: losingTeam.teamName,
                    holesDown: losingTeam.holesDown,
                    nextHole: nextHole
                ))
            }
        }
        
        return presses
    }
}

struct NassauHoleRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    let team1Name: String
    let team2Name: String
    let isEditMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        let holeWinner = game.matchPlayHoleWinner(holeNumber: holeNumber)
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
                        
                        if let netScore = game.netScoreForHole(player: player, holeNumber: holeNumber) {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
                
                if let bestNet = team1BestNet {
                    Text("Net: \(bestNet)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(team1Won ? .green : (holeWinner == nil ? .blue : .secondary))
                }
            }
            .frame(maxWidth: .infinity)
            .background(team1Won ? Color.green.opacity(0.2) : Color.clear)
            
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
                        
                        if let netScore = game.netScoreForHole(player: player, holeNumber: holeNumber) {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
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
                
                if let bestNet = team2BestNet {
                    Text("Net: \(bestNet)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(team2Won ? .green : (holeWinner == nil ? .blue : .secondary))
                }
            }
            .frame(maxWidth: .infinity)
            .background(team2Won ? Color.green.opacity(0.2) : Color.clear)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(holeNumber % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.3))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
}

struct NassauMatchSummaryRow: View {
    @Bindable var game: Game
    let team1Name: String
    let team2Name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match Summary")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Front 9
            let front9Status = game.nassauFront9Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Front 9")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(front9Status.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if front9Status.team1HolesUp > 0 {
                    Text("\(team1Name) +\(front9Status.team1HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else if front9Status.team2HolesUp > 0 {
                    Text("\(team2Name) +\(front9Status.team2HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text("All Square")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // Back 9
            let back9Status = game.nassauBack9Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Back 9")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(back9Status.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if back9Status.team1HolesUp > 0 {
                    Text("\(team1Name) +\(back9Status.team1HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else if back9Status.team2HolesUp > 0 {
                    Text("\(team2Name) +\(back9Status.team2HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text("All Square")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // Overall
            let overallStatus = game.nassauOverallStatus
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overall")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(overallStatus.status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if overallStatus.team1HolesUp > 0 {
                    Text("\(team1Name) +\(overallStatus.team1HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else if overallStatus.team2HolesUp > 0 {
                    Text("\(team2Name) +\(overallStatus.team2HolesUp)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text("All Square")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            // Points Summary
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Points Summary")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Each match and press is worth 1 point")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team1Name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(game.nassauPointsForTeam(team1Name), specifier: "%.1f") points")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(team2Name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(game.nassauPointsForTeam(team2Name), specifier: "%.1f") points")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
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

struct NassauPressesRow: View {
    @Bindable var game: Game
    let team1Name: String
    let team2Name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presses")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(Array(game.presses.enumerated()), id: \.offset) { index, press in
                let pressStatus = game.pressMatchStatus(press: press)
                let matchTypeName: String = {
                    switch press.matchType {
                    case "front9": return "Front 9"
                    case "back9": return "Back 9"
                    case "overall": return "Overall"
                    default: return press.matchType
                    }
                }()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(matchTypeName) Press (Hole \(press.startingHole))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Initiated by: \(press.initiatingTeam)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(pressStatus.status)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if pressStatus.team1HolesUp > 0 {
                        Text("\(team1Name) +\(pressStatus.team1HolesUp)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else if pressStatus.team2HolesUp > 0 {
                        Text("\(team2Name) +\(pressStatus.team2HolesUp)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Text("All Square")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }
}

struct NassauPressSheet: View {
    @Bindable var game: Game
    @Environment(\.dismiss) private var dismiss
    
    // Available matches where a team is losing (can press)
    // Note: Presses are only valid for Front 9 and Back 9 matches, not the Overall match
    var availablePresses: [(matchType: String, matchName: String, losingTeam: String, holesDown: Int, nextHole: Int)] {
        var presses: [(matchType: String, matchName: String, losingTeam: String, holesDown: Int, nextHole: Int)] = []
        
        let matchTypes = [
            ("front9", "Front 9"),
            ("back9", "Back 9")
        ]
        
        for (matchType, matchName) in matchTypes {
            if let losingTeam = game.losingTeamForMatch(matchType: matchType),
               let nextHole = game.nextHoleForMatch(matchType: matchType) {
                presses.append((
                    matchType: matchType,
                    matchName: matchName,
                    losingTeam: losingTeam.teamName,
                    holesDown: losingTeam.holesDown,
                    nextHole: nextHole
                ))
            }
        }
        
        return presses
    }
    
    var body: some View {
        NavigationView {
            Form {
                if availablePresses.isEmpty {
                    Section {
                        Text("No presses available. A press can only be initiated by the team that is losing in a match.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Available Presses") {
                        Text("Select a match to add a press. The losing team will automatically initiate the press on the next hole to be played.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(availablePresses, id: \.matchType) { press in
                            Button(action: {
                                game.addPress(matchType: press.matchType, startingHole: press.nextHole, initiatingTeam: press.losingTeam)
                                dismiss()
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(press.matchName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("\(press.losingTeam) is \(press.holesDown) down")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Press starts on Hole \(press.nextHole)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Press")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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
    
    let game = Game(course: course, players: [player1, player2, player3, player4], gameFormat: "nassau", teamAssignments: teams)
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(player3)
    container.mainContext.insert(player4)
    container.mainContext.insert(game)
    
    return NassauScorecardView(game: game)
        .modelContainer(container)
}

