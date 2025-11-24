//
//  ScrambleScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 12/19/25.
//

import SwiftUI
import SwiftData

struct ScrambleScorecardView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    
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
                        Text("Format: Two-Man Scramble")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Team columns
                if game.teamNames.count != 2 {
                    Text("Two-Man Scramble requires exactly 2 teams")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    let team1Name = game.teamNames[0]
                    let team2Name = game.teamNames[1]
                    let team1Players = game.playersForTeam(team1Name)
                    let team2Players = game.playersForTeam(team2Name)
                    let team1Handicap = game.averageHandicapForTeam(team1Name)
                    let team2Handicap = game.averageHandicapForTeam(team2Name)
                    
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
                            Text("HCP: \(String(format: "%.1f", team1Handicap))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(team1Players.sortedWithCurrentUserFirst()) { player in
                                Text(player.name)
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
                            Text("HCP: \(String(format: "%.1f", team2Handicap))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(team2Players.sortedWithCurrentUserFirst()) { player in
                                Text(player.name)
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
                        ScrambleHoleRow(holeNumber: holeNum, game: game, course: game.course, team1Name: team1Name, team2Name: team2Name)
                    }
                    
                    // Total rows
                    Divider()
                    ScrambleTotalRow(label: "Front 9", game: game, holes: 1...9, team1Name: team1Name, team2Name: team2Name)
                    ScrambleTotalRow(label: "Back 9", game: game, holes: 10...18, team1Name: team1Name, team2Name: team2Name)
                    ScrambleTotalRow(label: "Total", game: game, holes: 1...18, team1Name: team1Name, team2Name: team2Name)
                        .fontWeight(.bold)
                        .background(Color(.quaternarySystemFill))
                    
                    // Standings
                    Divider()
                    ScrambleStandingsRow(game: game)
                }
            }
        }
    }
}

struct ScrambleHoleRow: View {
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
            
            // Team 1 score
            VStack(spacing: 2) {
                let gross = game.scrambleScoreForTeam(team1Name, holeNumber: holeNumber)
                let net = game.scrambleNetScoreForTeam(team1Name, holeNumber: holeNumber)
                
                if let grossScore = gross {
                    Text("\(grossScore)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let netScore = net {
                        Text("(\(netScore))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
            
            // Team 2 score
            VStack(spacing: 2) {
                let gross = game.scrambleScoreForTeam(team2Name, holeNumber: holeNumber)
                let net = game.scrambleNetScoreForTeam(team2Name, holeNumber: holeNumber)
                
                if let grossScore = gross {
                    Text("\(grossScore)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if let netScore = net {
                        Text("(\(netScore))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(holeNumber % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.3))
        .sheet(isPresented: $showingScoreEditor) {
            ScrambleScoreEditorView(holeNumber: holeNumber, game: game, team1Name: team1Name, team2Name: team2Name)
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
}

struct ScrambleTotalRow: View {
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
            VStack(spacing: 2) {
                let grossTotal = holes.reduce(0) { total, holeNum in
                    total + (game.scrambleScoreForTeam(team1Name, holeNumber: holeNum) ?? 0)
                }
                let netTotal = holes.reduce(0) { total, holeNum in
                    total + (game.scrambleNetScoreForTeam(team1Name, holeNumber: holeNum) ?? 0)
                }
                
                if grossTotal > 0 {
                    Text("\(grossTotal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("(\(netTotal))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Team 2 total
            VStack(spacing: 2) {
                let grossTotal = holes.reduce(0) { total, holeNum in
                    total + (game.scrambleScoreForTeam(team2Name, holeNumber: holeNum) ?? 0)
                }
                let netTotal = holes.reduce(0) { total, holeNum in
                    total + (game.scrambleNetScoreForTeam(team2Name, holeNumber: holeNum) ?? 0)
                }
                
                if grossTotal > 0 {
                    Text("\(grossTotal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("(\(netTotal))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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

struct ScrambleStandingsRow: View {
    @Bindable var game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Team Standings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(Array(game.scrambleStandings.enumerated()), id: \.element.teamName) { index, standing in
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(standing.teamName)
                            .font(.subheadline)
                            .fontWeight(index == 0 ? .semibold : .regular)
                        Text("HCP: \(String(format: "%.1f", standing.handicap))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Scores
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Gross: \(standing.grossScore)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Net: \(standing.netScore)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(index == 0 ? .blue : .primary)
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

// Score editor for scramble - allows entering one score per team
struct ScrambleScoreEditorView: View {
    let holeNumber: Int
    @Bindable var game: Game
    let team1Name: String
    let team2Name: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var team1Score: String = ""
    @State private var team2Score: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Hole \(holeNumber)") {
                    if let course = game.course,
                       let holes = course.holes,
                       let hole = holes.first(where: { $0.holeNumber == holeNumber }) {
                        Text("Par: \(hole.par)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(team1Name) {
                    TextField("Score", text: $team1Score)
                        .keyboardType(.numberPad)
                    
                    if let currentScore = game.scrambleScoreForTeam(team1Name, holeNumber: holeNumber) {
                        Text("Current: \(currentScore)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(team2Name) {
                    TextField("Score", text: $team2Score)
                        .keyboardType(.numberPad)
                    
                    if let currentScore = game.scrambleScoreForTeam(team2Name, holeNumber: holeNumber) {
                        Text("Current: \(currentScore)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveScores()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load current scores
                if let score1 = game.scrambleScoreForTeam(team1Name, holeNumber: holeNumber) {
                    team1Score = "\(score1)"
                }
                if let score2 = game.scrambleScoreForTeam(team2Name, holeNumber: holeNumber) {
                    team2Score = "\(score2)"
                }
            }
        }
    }
    
    private func saveScores() {
        // Get first player from each team (we store the team score under the first player)
        let team1Players = game.playersForTeam(team1Name)
        let team2Players = game.playersForTeam(team2Name)
        
        guard let player1 = team1Players.first, let player2 = team2Players.first else { return }
        
        // Save team 1 score
        if let score1 = Int(team1Score), score1 > 0 {
            if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
                existingHole.setScore(for: player1, score: score1)
            } else {
                let newHoleScore = HoleScore(holeNumber: holeNumber)
                newHoleScore.setScore(for: player1, score: score1)
                if game.holesScores == nil { game.holesScores = [] }
                game.holesScores!.append(newHoleScore)
                modelContext.insert(newHoleScore)
            }
        } else if team1Score.isEmpty || team1Score == "0" {
            // Remove score if cleared - set to 0 or remove
            if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
                existingHole.setScore(for: player1, score: 0) // Setting to 0 effectively removes it
            }
        }
        
        // Save team 2 score
        if let score2 = Int(team2Score), score2 > 0 {
            if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
                existingHole.setScore(for: player2, score: score2)
            } else {
                let newHoleScore = HoleScore(holeNumber: holeNumber)
                newHoleScore.setScore(for: player2, score: score2)
                if game.holesScores == nil { game.holesScores = [] }
                game.holesScores!.append(newHoleScore)
                modelContext.insert(newHoleScore)
            }
        } else if team2Score.isEmpty || team2Score == "0" {
            // Remove score if cleared
            if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
                existingHole.setScore(for: player2, score: 0) // Setting to 0 effectively removes it
            }
        }
        
        // Save to model context
        try? modelContext.save()
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
    let game = Game(course: course, players: [player1, player2, player3, player4], gameFormat: "scramble", teamAssignments: ["Team 1": [player1.id, player2.id], "Team 2": [player3.id, player4.id]])
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(player3)
    container.mainContext.insert(player4)
    container.mainContext.insert(game)
    
    return ScrambleScorecardView(game: game)
        .modelContainer(container)
}

