//
//  ScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct ScorecardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]
    @Query private var players: [Player]
    @Query private var courses: [GolfCourse]
    
    @AppStorage("selectedGameID") private var selectedGameIDString: String = ""
    @AppStorage("currentHole") private var currentHole: Int = 1
    @State private var showingGameSetup = false
    @State private var inputText = ""
    @State private var listening = false
    
    private var selectedGame: Game? {
        get {
            guard !selectedGameIDString.isEmpty, let id = UUID(uuidString: selectedGameIDString) else { return nil }
            return games.first { $0.id == id }
        }
        set {
            selectedGameIDString = newValue?.id.uuidString ?? ""
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main content area
                if let game = selectedGame {
                    GameScorecardView(game: game)
                } else {
                    EmptyStateView()
                }
                
                // Voice/Text Input Bar - Always at bottom
                TextInputBar(inputText: $inputText, listening: $listening, onCommit: handleInput, onToggleListening: nil)
            }
            .navigationTitle("Scorecard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("New Game") {
                        showingGameSetup = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(games) { game in
                            Menu(game.course?.name ?? "Game") {
                                Button {
                                    _selectedGameIDString.wrappedValue = game.id.uuidString
                                } label: {
                                    Label("Select", systemImage: "checkmark")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteGame(game)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } label: {
                        Label("Games", systemImage: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showingGameSetup) {
                GameSetupView(selectedGameIDString: $selectedGameIDString, games: games)
            }
        }
    }
    
    private func handleInput() {
        guard !inputText.isEmpty else { return }
        
        let lowerText = inputText.lowercased()
        
        // If no game selected, try to create one from the input
        if selectedGame == nil {
            // Check if input has patterns that indicate game creation
            let hasWithKeyword = lowerText.contains(" with ")
            let hasAtKeyword = lowerText.contains(" at ")
            let hasAndAtPattern = lowerText.range(of: " and ") != nil && hasAtKeyword
            
            if hasWithKeyword || hasAtKeyword || hasAndAtPattern {
                parseAndCreateGame(text: inputText)
            } else {
                print("ℹ️ No active game. Say '[players] at [course]' to start")
            }
        } else {
            // We have an active game, parse as score input
            parseAndUpdateScores(text: inputText)
        }
        
        inputText = ""
    }
    
    private func parseAndCreateGame(text: String) {
        let lowerText = text.lowercased()
        print("🎮 Parsing game creation: '\(text)'")
        print("📝 Available players: \(players.map { $0.name })")
        print("📝 Available courses: \(courses.map { $0.name })")
        
        // Extract player names
        var foundPlayers: [Player] = []
        
        // Look for "with", "at", or just "and...at" pattern
        let withRange = lowerText.range(of: " with ")
        let atRange = lowerText.range(of: " at ")
        
        let playerSection: String
        if let withRange = withRange, let atRange = atRange, withRange.upperBound < atRange.lowerBound {
            // Pattern: "something with players at course"
            playerSection = String(lowerText[withRange.upperBound..<atRange.lowerBound])
        } else if let withRange = withRange {
            // Pattern: "something with players"
            playerSection = String(lowerText[withRange.upperBound...])
        } else if let atRange = atRange {
            // Pattern: "players at course" (no "with")
            playerSection = String(lowerText[..<atRange.lowerBound])
        } else {
            // Just players, no course specified
            playerSection = lowerText
        }
        
        print("👥 Extracted player section: '\(playerSection)'")
        
        // Parse player names (split by commas and "and")
        var playerNames = playerSection.components(separatedBy: CharacterSet(charactersIn: ",")).flatMap { $0.components(separatedBy: " and ") }
        playerNames = playerNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        print("👥 Found player names: \(playerNames)")
        
        // Match to actual players
        for name in playerNames {
            let nameLower = name.lowercased()
            
            for player in players {
                let playerNameLower = player.name.lowercased()
                let nameParts = playerNameLower.components(separatedBy: " ")
                let firstName = nameParts.first ?? playerNameLower
                let lastName = nameParts.count > 1 ? nameParts.last! : ""
                
                if firstName == nameLower || lastName == nameLower || playerNameLower == nameLower {
                    if !foundPlayers.contains(where: { $0.id == player.id }) {
                        foundPlayers.append(player)
                        print("✅ Matched player: \(player.name)")
                    }
                }
            }
        }
        
        // Extract course name
        var selectedCourse: GolfCourse? = nil
        if let atRange = lowerText.range(of: "at") {
            let courseSection = String(lowerText[atRange.upperBound...])
            let courseName = courseSection.trimmingCharacters(in: .whitespaces)
            
            print("⛳ Looking for course: '\(courseName)'")
            
            for course in courses {
                let courseNameLower = course.name.lowercased()
                // Match if any part of the course name matches
                if courseNameLower.contains(courseName) || courseName.contains(courseNameLower) {
                    selectedCourse = course
                    print("✅ Matched course: \(course.name)")
                    break
                }
            }
        }
        
        // Create the game
        if !foundPlayers.isEmpty {
            // Only one game can be active at a time, so deselect any current game
            let newGame = Game(course: selectedCourse, players: foundPlayers)
            modelContext.insert(newGame)
            
            do {
                try modelContext.save()
                _selectedGameIDString.wrappedValue = newGame.id.uuidString
                currentHole = 1 // Reset to hole 1 for new game
                print("✅ Game created successfully with \(foundPlayers.count) players!")
            } catch {
                print("❌ Error creating game: \(error)")
            }
        } else {
            print("⚠️ No players found in: '\(text)'")
        }
    }
    
    private func parseAndUpdateScores(text: String) {
        guard let game = selectedGame else {
            print("⚠️ No game selected")
            return
        }
        
        print("🔍 Parsing: '\(text)'")
        print("🎮 Game has \(game.players.count) players: \(game.players.map { $0.name })")
        
        let lowerText = text.lowercased()
        
        // Extract hole number
        var holeNumber: Int?
        if let holePattern = try? NSRegularExpression(pattern: "hole\\s+(\\d+)", options: .caseInsensitive),
           let holeMatch = holePattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
           let holeRange = Range(holeMatch.range(at: 1), in: lowerText) {
            holeNumber = Int(String(lowerText[holeRange]))
        }
        
        // If no hole number provided, find the first empty hole
        if holeNumber == nil {
            holeNumber = findFirstEmptyHole(game: game)
            if let hole = holeNumber {
                print("📍 No hole number specified, using first empty hole: \(hole)")
            } else {
                print("❌ No empty hole found on scorecard")
                return
            }
        }
        
        print("✅ Hole number: \(holeNumber!)")
        
        // Parse player scores - look for patterns like:
        // "dan got a par" or "dave got bogey" or "john 5" or "jane scored 6"
        let scorePatterns = [
            (name: "double eagle|albatross", value: -3),
            (name: "eagle", value: -2),
            (name: "birdie", value: -1),
            (name: "par|parr", value: 0),
            (name: "bogey|bogie", value: 1),
            (name: "double bogey", value: 2),
            (name: "triple bogey", value: 3)
        ]
        
        // Find the par for this hole
        guard let targetHoleNumber = holeNumber,
              let course = game.course,
              let hole = course.holes.first(where: { $0.holeNumber == targetHoleNumber }) else {
            print("❌ No course or hole found")
            return
        }
        
        let par = hole.par
        print("⛳ Hole \(targetHoleNumber) is par \(par)")
        
        // Parse each player's score
        for player in game.players {
            let playerNameLower = player.name.lowercased()
            
            // Extract first and last name from full name
            let nameParts = playerNameLower.components(separatedBy: " ")
            let firstName = nameParts.first ?? playerNameLower
            let lastName = nameParts.count > 1 ? nameParts.last! : ""
            
            print("👤 Checking player: '\(player.name)' (first: '\(firstName)', last: '\(lastName)')")
            
            // Check if this player is mentioned in the text (by first name, last name, or full name)
            var playerMentioned = lowerText.contains(playerNameLower) || lowerText.contains(firstName)
            
            // Also check for last name if it exists
            if !lastName.isEmpty {
                playerMentioned = playerMentioned || lowerText.contains(lastName)
            }
            
            if playerMentioned {
                print("  ✅ Found player '\(player.name)' in text")
                var score: Int?
                
                // First, try to find relative scores (par, birdie, etc.)
                // Check first name, last name (if exists), and full name patterns
                var namePatterns = [firstName, playerNameLower]
                if !lastName.isEmpty {
                    namePatterns.append(lastName)
                }
                
                for nameToMatch in namePatterns {
                    for pattern in scorePatterns {
                        let regexPattern = "\(nameToMatch).*?\\b\(pattern.name)\\b"
                        if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive),
                           regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)) != nil {
                            score = par + pattern.value
                            print("  ✅ Found relative score: \(pattern.name) = \(score!)")
                            break
                        }
                    }
                    if score != nil { break }
                }
                
                // If no relative score found, try to find absolute score
                // Check both first name and full name patterns
                if score == nil {
                    for nameToMatch in namePatterns {
                        let absolutePattern = "\(nameToMatch).*?\\b(\\d+)\\b"
                        if let regex = try? NSRegularExpression(pattern: absolutePattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            score = Int(String(lowerText[scoreRange]))
                            print("  ✅ Found absolute score: \(score!)")
                            break
                        }
                    }
                }
                
                // Update score if found
                if let score = score {
                    print("  💾 Saving score: \(player.name) -> \(score)")
                    updateHoleScore(game: game, holeNumber: targetHoleNumber, player: player, score: score)
                } else {
                    print("  ❌ No score found for player '\(player.name)'")
                }
            } else {
                print("  ❌ Player '\(player.name)' not found in text")
            }
        }
    }
    
    private func findFirstEmptyHole(game: Game) -> Int? {
        // Check holes 1-18 to find the first one with no scores entered
        for holeNumber in 1...18 {
            let holeScore = game.holesScores.first(where: { $0.holeNumber == holeNumber })
            // If no hole score entry exists, or all players have no score for this hole
            if holeScore == nil || holeScore!.scores.isEmpty {
                return holeNumber
            }
            // Check if any player is missing a score for this hole
            var allPlayersHaveScores = true
            for player in game.players {
                if holeScore!.scores[player.id] == nil {
                    allPlayersHaveScores = false
                    break
                }
            }
            if !allPlayersHaveScores {
                return holeNumber
            }
        }
        return nil
    }
    
    private func deleteGame(_ game: Game) {
        modelContext.delete(game)
        try? modelContext.save()
        
        if selectedGame?.id == game.id {
            _selectedGameIDString.wrappedValue = ""
        }
    }
    
    private func updateHoleScore(game: Game, holeNumber: Int, player: Player, score: Int) {
        if let existingHole = game.holesScores.first(where: { $0.holeNumber == holeNumber }) {
            print("  📝 Updating existing hole score")
            existingHole.setScore(for: player, score: score)
        } else {
            print("  📝 Creating new hole score")
            let newHoleScore = HoleScore(holeNumber: holeNumber)
            newHoleScore.setScore(for: player, score: score)
            game.holesScores.append(newHoleScore)
            modelContext.insert(newHoleScore)
        }
        
        do {
            try modelContext.save()
            print("  ✅ Score saved successfully!")
            
            // If this is the current hole, advance to next hole after all players have scores
            if holeNumber == currentHole {
                let holeScore = game.holesScores.first(where: { $0.holeNumber == holeNumber })
                let allPlayersScored = game.players.allSatisfy { player in
                    holeScore?.scores[player.id] != nil
                }
                
                if allPlayersScored && currentHole < 18 {
                    currentHole += 1
                    print("📍 All players scored on hole \(holeNumber). Advancing to hole \(currentHole)")
                }
            }
        } catch {
            print("  ❌ Error saving score: \(error)")
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.golf")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("No Active Game")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a new game to track scores")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("💡 Try saying: 'Dan, Dave, John and Van at Amelia River'")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ScorecardView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self], inMemory: true)
}

