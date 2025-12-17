//
//  GameScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct GameScorecardView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @State private var isEditMode = false
    @State private var showingScoreEditor = false
    @State private var selectedHoleNumber: Int = 1
    
    // Find the first hole that doesn't have scores for all players
    private func findFirstEmptyHole() -> Int? {
        let players = game.playersArray
        guard !players.isEmpty else { return 1 }
        
        for holeNumber in 1...18 {
            let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
            
            // If no hole score record exists at all, this is an empty hole
            guard let holeScore = holeScore else {
                return holeNumber
            }
            
            // Get the scores dictionary for this hole
            let scores = holeScore.scores
            
            // Check if ALL players have scores for this hole
            let allPlayersHaveScores = players.allSatisfy { player in
                scores[player.id] != nil
            }
            
            // If not all players have scores, this hole needs scores
            if !allPlayersHaveScores {
                return holeNumber
            }
        }
        
        // All holes complete - return nil (will default to the tapped hole)
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
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(game.course?.name ?? "Unknown Course")
                            .font(.headline)
                        Spacer()
                        
                        // Edit mode toggle
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
                        if !isEditMode {
                            Text("Tap to enter next score")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Tap any hole to edit")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Tee color display (always show if available)
                    if let teeColor = game.effectiveTeeColor {
                        HStack {
                            Text("Tees: \(teeColor)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
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
                        HoleScoreRow(
                            holeNumber: holeNum,
                            game: game,
                            course: game.course,
                            isEditMode: isEditMode,
                            onTap: {
                                if isEditMode {
                                    // In edit mode, open the specific hole tapped
                                    selectedHoleNumber = holeNum
                                } else {
                                    // In normal mode, open the next empty hole
                                    selectedHoleNumber = findFirstEmptyHole() ?? holeNum
                                }
                                showingScoreEditor = true
                            }
                        )
                    }
                    
                    // Total rows
                    Divider()
                    TotalScoreRow(label: "Front 9", scores: game.front9Scores)
                    TotalScoreRow(label: "Back 9", scores: game.back9Scores)
                    TotalScoreRow(label: "Total", scores: game.totalScores)
                        .fontWeight(.bold)
                        .background(Color(.quaternarySystemFill))
                }
            }
        }
        .sheet(isPresented: $showingScoreEditor) {
            ScoreEditorView(holeNumber: selectedHoleNumber, game: game)
        }
    }
}

struct HoleScoreRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    let isEditMode: Bool
    let onTap: () -> Void
    
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
            
            // Player scores (gross and net)
            ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                let gross = getScore(for: player)
                let net = gross != nil ? game.netScoreForHole(player: player, holeNumber: holeNumber) : nil
                let getsStroke = game.playerGetsStrokeOnHole(player: player, holeNumber: holeNumber)
                
                VStack(spacing: 2) {
                    if let grossScore = gross {
                        Text("\(grossScore)")
                            .font(.caption)
                            .foregroundColor(scoreColor(for: grossScore))
                        if let netScore = net {
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
                            .font(.caption)
                            .foregroundColor(getsStroke ? .blue : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(holeNumber % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.3))
        .contentShape(Rectangle()) // Make entire row tappable
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
    
    private func scoreColor(for score: Int?) -> Color {
        guard score != nil else { return .secondary }
        // Color coding: par = black, birdie = blue, eagle = green, bogey+ = red
        // This would need actual par data from the course
        return .primary
    }
}

struct TotalScoreRow: View {
    let label: String
    let scores: [(player: Player, gross: Int, net: Int)]
    
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
            
            ForEach(scores, id: \.player.id) { score in
                VStack(spacing: 2) {
                    Text("\(score.gross)")
                        .font(.caption)
                    Text("(\(score.net))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct ScoreEditorView: View {
    @AppStorage("currentHole") private var currentHole: Int = 1
    let holeNumber: Int
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(game.playersArray) { player in
                    ScoreEditorRow(holeNumber: holeNumber, game: game, player: player)
                }
            }
            .navigationTitle("Hole \(holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ScoreEditorRow: View {
    @AppStorage("currentHole") private var currentHole: Int = 1
    let holeNumber: Int
    @Bindable var game: Game
    let player: Player
    @Environment(\.modelContext) private var modelContext
    @State private var scoreText: String
    
    init(holeNumber: Int, game: Game, player: Player) {
        self.holeNumber = holeNumber
        self.game = game
        self.player = player
        if let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }),
           let score = holeScore.scores[player.id] {
            _scoreText = State(initialValue: "\(score)")
        } else {
            _scoreText = State(initialValue: "")
        }
    }
    
    var body: some View {
        HStack {
            Text(player.name)
            Spacer()
            TextField("Score", text: $scoreText)
                .keyboardType(.numberPad)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    saveScore()
                }
        }
        .onChange(of: scoreText) { _, newValue in
            saveScore()
        }
    }
    
    private func saveScore() {
        guard let score = Int(scoreText) else { return }
        
        if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
            existingHole.setScore(for: player, score: score)
        } else {
            let newHoleScore = HoleScore(holeNumber: holeNumber)
            newHoleScore.setScore(for: player, score: score)
            if game.holesScores == nil { game.holesScores = [] }
            game.holesScores!.append(newHoleScore)
            modelContext.insert(newHoleScore)
        }
        
        try? modelContext.save()
        
        // If this is the current hole, advance to next hole after all players have scores
        if holeNumber == currentHole {
            let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
            let allPlayersScored = game.playersArray.allSatisfy { player in
                holeScore?.scores[player.id] != nil
            }
            
            if allPlayersScored && currentHole < 18 {
                currentHole += 1
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
    let game = Game(course: course, players: [player1, player2])
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(game)
    
    return GameScorecardView(game: game)
        .modelContainer(container)
}

