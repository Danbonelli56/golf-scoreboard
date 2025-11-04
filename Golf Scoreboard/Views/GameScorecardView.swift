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
    
    // Helper to extract first name
    func firstName(from fullName: String) -> String {
        fullName.components(separatedBy: " ").first ?? fullName
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
                    if let teeColor = game.selectedTeeColor {
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
                        .frame(width: 40)
                        .font(.caption)
                        .fontWeight(.semibold)
                        
                        Text("Par")
                        .frame(width: 35)
                        .font(.caption)
                        .fontWeight(.semibold)
                        
                        Text("HCP")
                        .frame(width: 30)
                        .font(.caption)
                        .fontWeight(.semibold)
                        
                        ForEach(game.playersArray) { player in
                            Text(firstName(from: player.name))
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
                        HoleScoreRow(holeNumber: holeNum, game: game, course: game.course)
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
    }
}

struct HoleScoreRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    @State private var showingScoreEditor = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Hole number
            Text("\(holeNumber)")
                .frame(width: 40)
                .font(.caption)
                .fontWeight(.medium)
            
            // Par
            Text(parText)
                .frame(width: 35)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Handicap
            Text(hcpText)
                .frame(width: 30)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Player scores
            ForEach(game.playersArray) { player in
                let score = getScore(for: player)
                Text(score.map { "\($0)" } ?? "-")
                    .frame(maxWidth: .infinity)
                    .font(.caption)
                    .foregroundColor(scoreColor(for: score))
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
                .frame(width: 40)
                .font(.caption)
                .fontWeight(.semibold)
            
            // Empty cells for Par and HCP columns
            Text("")
                .frame(width: 35)
            
            Text("")
                .frame(width: 30)
            
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

