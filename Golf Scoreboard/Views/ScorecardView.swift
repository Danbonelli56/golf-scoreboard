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
    @Query private var allGames: [Game]
    @Query private var players: [Player]
    @Query private var courses: [GolfCourse]
    
    @AppStorage("selectedGameID") private var selectedGameIDString: String = ""
    @AppStorage("currentHole") private var currentHole: Int = 1
    @State private var showingGameSetup = false
    @State private var inputText = ""
    @State private var listening = false
    @State private var showingCompleteGameAlert = false
    
    // Filter out completed games and games from previous days
    private var activeGames: [Game] {
        allGames.filter { game in
            // Exclude if explicitly marked as completed
            if game.isCompleted {
                return false
            }
            // Auto-archive games from previous days
            if game.isFromPreviousDay {
                // Mark as completed and save
                game.isCompleted = true
                try? modelContext.save()
                return false
            }
            return true
        }
    }
    
    // Archive expired games and clear selection if needed
    private func archiveExpiredGames() {
        var clearedSelection = false
        
        for game in allGames {
            // Check if game is from a previous day and not yet completed
            if game.isFromPreviousDay && !game.isCompleted {
                // Mark as completed (archived)
                game.isCompleted = true
                
                // Clear selection if this was the selected game
                if let selectedID = UUID(uuidString: selectedGameIDString), selectedID == game.id {
                    clearedSelection = true
                }
            }
        }
        
        // Save changes and clear selection if needed
        if clearedSelection {
            _selectedGameIDString.wrappedValue = ""
            currentHole = 1 // Reset to hole 1
        }
        
        try? modelContext.save()
    }
    
    private var games: [Game] {
        activeGames
    }
    
    private var selectedGame: Game? {
        get {
            guard !selectedGameIDString.isEmpty, let id = UUID(uuidString: selectedGameIDString) else { return nil }
            return activeGames.first { $0.id == id }
        }
        set {
            selectedGameIDString = newValue?.id.uuidString ?? ""
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content area
                if let game = selectedGame {
                    if game.gameFormat == "stableford" {
                        StablefordScorecardView(game: game)
                    } else if game.gameFormat == "bestball" || game.gameFormat == "bestball_matchplay" {
                        BestBallScorecardView(game: game)
                    } else {
                    GameScorecardView(game: game)
                    }
                } else {
                    EmptyStateView()
                }
                
                // Voice/Text Input Bar - Always at bottom
                // Pass player names for focused vocabulary (scorecard only)
                TextInputBar(
                    inputText: $inputText,
                    listening: $listening,
                    onCommit: handleInput,
                    onToggleListening: nil,
                    playerNames: selectedGame?.playersArray.map { $0.name } ?? []
                )
            }
            .navigationTitle("Scorecard")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("New Game") {
                        showingGameSetup = true
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Complete/Archive button (only show if game is selected and can be completed)
                        if let game = selectedGame, game.isGameCompleted {
                            Button {
                                showingCompleteGameAlert = true
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                        }
                        
                        Menu {
                            ForEach(games) { game in
                                Menu(game.course?.name ?? "Game") {
                                    Button {
                                        _selectedGameIDString.wrappedValue = game.id.uuidString
                                    } label: {
                                        Label("Select", systemImage: "checkmark")
                                    }
                                    
                                    Divider()
                                    
                                    if game.isGameCompleted {
                                        Button {
                                            completeGame(game)
                                        } label: {
                                            Label("Move to History", systemImage: "tray.and.arrow.down")
                                        }
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
            }
            .alert("Complete Game", isPresented: $showingCompleteGameAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Move to History") {
                    if let game = selectedGame {
                        completeGame(game)
                    }
                }
            } message: {
                Text("This will move the game to history and remove it from the active scorecard.")
            }
            .sheet(isPresented: $showingGameSetup) {
                GameSetupView(selectedGameIDString: $selectedGameIDString, games: games)
            }
            .onAppear {
                // Archive expired games when view appears
                archiveExpiredGames()
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
            let hasAtKeyword = lowerText.contains(" at ") || lowerText.contains("at")
            let hasAndKeyword = lowerText.contains(" and ")
            
            // Allow game creation if:
            // 1. Has "with" keyword
            // 2. Has "at" keyword  
            // 3. Has "and" (multiple players) - might include course name after
            // 4. Has a single word that could be a course name (will be validated in parsing)
            if hasWithKeyword || hasAtKeyword || hasAndKeyword {
                parseAndCreateGame(text: inputText)
            } else {
                // Check if we have at least one player and something that might be a course
                // This handles cases like "dan osprey cove" where there's no "at"
                let words = lowerText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if words.count >= 2 {
                    // Could be "player course" - try parsing it
                    parseAndCreateGame(text: inputText)
                } else {
                    print("ℹ️ No active game. Say '[players] at [course]' or '[players] [course]' to start")
                }
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
            print("  🔍 Looking for player: '\(name)'")
            
            var foundThisPlayer = false
            for player in players {
                let playerNameLower = player.name.lowercased()
                let nameParts = playerNameLower.components(separatedBy: " ")
                let firstName = nameParts.first ?? playerNameLower
                let lastName = nameParts.count > 1 ? nameParts.last! : ""
                
                if firstName == nameLower || lastName == nameLower || playerNameLower == nameLower {
                    if !foundPlayers.contains(where: { $0.id == player.id }) {
                        foundPlayers.append(player)
                        foundThisPlayer = true
                        print("  ✅ Matched player: '\(name)' -> \(player.name)")
                        break
                    }
                }
            }
            
            if !foundThisPlayer {
                print("  ❌ Could not match player: '\(name)'")
            }
        }
        
        print("👥 Total players matched: \(foundPlayers.count)")
        
        // Extract course name and tee color
        var selectedCourse: GolfCourse? = nil
        var selectedTeeColor: String? = nil
        
        // Common tee color patterns to remove from course name matching
        // Include common speech recognition errors: "tees" -> "tease", "tea", "teas"
        let teeColorPatterns = [
            // Full patterns with "tees" variations
            "black tees", "black tease", "black tea", "black teas",
            "gold tees", "gold tease", "gold tea", "gold teas",
            "white tees", "white tease", "white tea", "white teas",
            "blue tees", "blue tease", "blue tea", "blue teas",
            "green tees", "green tease", "green tea", "green teas",
            "gray tees", "gray tease", "gray tea", "gray teas",
            "grey tees", "grey tease", "grey tea", "grey teas",
            // Singular forms
            "black tee", "gold tee", "white tee", "blue tee", "green tee", "gray tee", "grey tee",
            // Just colors (fallback)
            "black", "gold", "white", "blue", "green", "gray", "grey"
        ]
        
        // Try to find course - look for "at" first, then try without "at"
        var courseSection: String = ""
        if let atRange = lowerText.range(of: " at ") {
            courseSection = String(lowerText[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let atRange = lowerText.range(of: "at") {
            courseSection = String(lowerText[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            // No "at" found - try to find course name anywhere in the text
            // Strategy: Try matching against known course names directly
            // First, try removing player names and "and" to see what's left
            var remainingText = lowerText
            for name in playerNames {
                let nameLower = name.lowercased()
                remainingText = remainingText.replacingOccurrences(of: nameLower, with: "", options: .caseInsensitive)
            }
            remainingText = remainingText.replacingOccurrences(of: " and ", with: " ", options: .caseInsensitive)
            remainingText = remainingText.trimmingCharacters(in: .whitespaces)
            
            // If we have remaining text, use it; otherwise try to match course names directly from the full text
            if !remainingText.isEmpty {
                courseSection = remainingText
            } else {
                // No text left after removing player names - try direct course matching on full text
                // This handles cases like "dan and dave osprey cove" where course name comes after players
                // We'll match courses by checking if any course name appears in the full text
                for course in courses {
                    let courseNameLower = course.name.lowercased()
                    let keyWords = courseNameLower.components(separatedBy: " ").filter { !["the", "at", "club", "golf"].contains($0) }
                    var foundWords = 0
                    for word in keyWords where word.count > 3 { // Only match significant words
                        if lowerText.contains(word) {
                            foundWords += 1
                        }
                    }
                    if foundWords >= 1 {
                        // Found a potential match - extract the course name part
                        // Use the first matching word to find where the course name starts
                        for word in keyWords {
                            if let wordRange = lowerText.range(of: word) {
                                courseSection = String(lowerText[wordRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                                break
                            }
                        }
                        break
                    }
                }
            }
        }
        
        print("⛳ Initial course section: '\(courseSection)'")
        
        // Extract tee color from course section if present
        let courseSectionLower = courseSection.lowercased()
        
        // Check patterns in order - longest first to catch "black tees" before just "black"
        let sortedPatterns = teeColorPatterns.sorted { $0.count > $1.count }
        
        for teePattern in sortedPatterns {
            if courseSectionLower.contains(teePattern) {
                // Map variations to standard capitalized names
                if teePattern.contains("gray") || teePattern.contains("grey") {
                    selectedTeeColor = "Gray"
                } else if teePattern.contains("black") {
                    selectedTeeColor = "Black"
                } else if teePattern.contains("gold") {
                    selectedTeeColor = "Gold"
                } else if teePattern.contains("white") {
                    selectedTeeColor = "White"
                } else if teePattern.contains("blue") {
                    selectedTeeColor = "Blue"
                } else if teePattern.contains("green") {
                    selectedTeeColor = "Green"
                }
                
                // Remove tee color pattern from course section for matching
                var cleanedSection = courseSection
                // Replace the pattern case-insensitively
                cleanedSection = cleanedSection.replacingOccurrences(of: teePattern, with: "", options: .caseInsensitive)
                // Clean up extra spaces that might result
                while cleanedSection.contains("  ") {
                    cleanedSection = cleanedSection.replacingOccurrences(of: "  ", with: " ")
                }
                courseSection = cleanedSection.trimmingCharacters(in: .whitespaces)
                
                print("🎯 Found tee color: \(selectedTeeColor ?? "unknown") from pattern: '\(teePattern)'")
                print("🎯 Course section after tee removal: '\(courseSection)'")
                break
            }
        }
        
        // Try to match course name (now with tee color removed)
        if !courseSection.isEmpty {
            courseSection = courseSection.trimmingCharacters(in: .whitespaces)
            print("🔍 Matching course with cleaned section: '\(courseSection)'")
            
            for course in courses {
                let courseNameLower = course.name.lowercased()
                print("  📍 Trying course: '\(course.name)'")
                
                // Strategy 1: Direct substring match (either direction)
                if courseNameLower.contains(courseSection) {
                    selectedCourse = course
                    print("✅ Matched course: \(course.name) (contains match)")
                    break
                }
                
                if courseSection.contains(courseNameLower) {
                    selectedCourse = course
                    print("✅ Matched course: \(course.name) (reverse contains match)")
                    break
                }
                
                // Strategy 2: Match on key words (excluding common words)
                let courseWords = courseNameLower.components(separatedBy: " ").filter { 
                    !["the", "at", "club", "golf", "and"].contains($0) && $0.count > 2
                }
                let searchWords = courseSection.components(separatedBy: " ").filter { 
                    !$0.isEmpty && $0.count > 2 
                }
                
                print("  📝 Course words: \(courseWords), Search words: \(searchWords)")
                
                // Check if all search words are found in course words (for multi-word searches like "amelia river")
                var allWordsMatched = true
                var matchCount = 0
                
                for searchWord in searchWords {
                    var wordFound = false
                    for courseWord in courseWords {
                        if courseWord == searchWord || courseWord.contains(searchWord) || searchWord.contains(courseWord) {
                            matchCount += 1
                            wordFound = true
                            print("  ✅ Matched word: '\(courseWord)' with '\(searchWord)'")
                            break
                        }
                    }
                    if !wordFound {
                        allWordsMatched = false
                        print("  ❌ Search word '\(searchWord)' not found in course")
                    }
                }
                
                // Match if all search words are found, or if at least one significant word matches
                if allWordsMatched && !searchWords.isEmpty {
                    selectedCourse = course
                    print("✅ Matched course: \(course.name) (all \(searchWords.count) words matched)")
                    break
                } else if matchCount >= 1 && searchWords.count == 1 {
                    // For single-word searches, allow partial match
                    selectedCourse = course
                    print("✅ Matched course: \(course.name) (matched \(matchCount) word)")
                    break
                } else {
                    print("  ❌ No match for '\(course.name)' (matched \(matchCount)/\(searchWords.count) words)")
                }
            }
            
            if selectedCourse == nil {
                print("⚠️ No course matched for section: '\(courseSection)'")
            }
        } else {
            print("⚠️ Course section is empty after processing")
        }
        
        // Create the game
        if !foundPlayers.isEmpty {
            // Determine tee color to use: selected > player preference > White > Green > first available
            let teeColorToUse: String? = {
                if let selectedTee = selectedTeeColor {
                    return selectedTee
                }
                
                // Try player's preferred tee if available
                if let currentUser = foundPlayers.first(where: { $0.isCurrentUser }),
                   let preferredTee = currentUser.preferredTeeColor,
                   let course = selectedCourse,
                   let holes = course.holes,
                   let firstHole = holes.first,
                   let teeDistances = firstHole.teeDistances,
                   teeDistances.contains(where: { $0.teeColor == preferredTee }) {
                    return preferredTee
                }
                
                // Use priority: White > Green > first available
                if let course = selectedCourse,
                   let holes = course.holes,
                   let firstHole = holes.first,
                   let teeDistances = firstHole.teeDistances {
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
                
                return nil
            }()
            
            // Only one game can be active at a time, so deselect any current game
            let newGame = Game(course: selectedCourse, players: foundPlayers, selectedTeeColor: teeColorToUse)
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
    
    // Helper function to convert written numbers to integers
    private func parseNumberWord(_ word: String) -> Int? {
        let numberWords: [String: Int] = [
            "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
            "sixteen": 16, "seventeen": 17, "eighteen": 18
        ]
        return numberWords[word.lowercased()]
    }
    
    // Helper function to parse a number from text (either digit or word)
    private func parseNumber(from text: String) -> Int? {
        // First try parsing as digit
        if let number = Int(text) {
            return number
        }
        // Then try parsing as written number
        return parseNumberWord(text)
    }
    
    private func parseAndUpdateScores(text: String) {
        guard let game = selectedGame else {
            print("⚠️ No game selected")
            return
        }
        
        print("🔍 Parsing: '\(text)'")
        print("🎮 Game has \(game.playersArray.count) players: \(game.playersArray.map { $0.name })")
        
        let lowerText = text.lowercased()
        
        // Extract hole number - try multiple patterns:
        // 1. "hole 10" or "hole10"
        // 2. Just a number at the start (within valid range 1-18)
        var holeNumber: Int?
        
        // Pattern 1: "hole 10" or "hole10"
        if let holePattern = try? NSRegularExpression(pattern: "hole\\s*(\\d+)", options: .caseInsensitive),
           let holeMatch = holePattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
           let holeRange = Range(holeMatch.range(at: 1), in: lowerText) {
            holeNumber = Int(String(lowerText[holeRange]))
        }
        
        // Pattern 2: Check if text starts with a number (for "10 five John four")
        if holeNumber == nil {
            let words = lowerText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if let firstWord = words.first, let firstNumber = parseNumber(from: firstWord) {
                // Check if it's a valid hole number (1-18)
                if firstNumber >= 1 && firstNumber <= 18 {
                    holeNumber = firstNumber
                    print("📍 Found hole number at start of text: \(firstNumber)")
                }
            }
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
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == targetHoleNumber }) else {
            print("❌ No course or hole found")
            return
        }
        
        let par = hole.par
        print("⛳ Hole \(targetHoleNumber) is par \(par)")
        
        // Parse each player's score
        for player in game.playersArray {
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
                        // Escape special regex characters in the name
                        let escapedName = NSRegularExpression.escapedPattern(for: nameToMatch)
                        
                        // Try direct pattern with digits: "name 5" or "name scored 5"
                        let directPattern = "\\b\(escapedName)\\s+(?:scored|got|shot|is|was)?\\s*(\\d+)\\b"
                        if let regex = try? NSRegularExpression(pattern: directPattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            if let parsedScore = Int(String(lowerText[scoreRange])) {
                                score = parsedScore
                                print("  ✅ Found absolute score (direct digit): \(score!)")
                                break
                            }
                        }
                        
                        // Try pattern with written numbers: "name five" or "name four"
                        let numberWords = "zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen"
                        let wordPattern = "\\b\(escapedName)\\s+(?:scored|got|shot|is|was)?\\s*\\b(\(numberWords))\\b"
                        if let regex = try? NSRegularExpression(pattern: wordPattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            let numberWord = String(lowerText[scoreRange])
                            if let parsedScore = parseNumberWord(numberWord) {
                                score = parsedScore
                                print("  ✅ Found absolute score (written number): \(numberWord) = \(score!)")
                                break
                            }
                        }
                        
                        // Try simple pattern with digits: "name 5"
                        let simplePattern = "\\b\(escapedName)\\s+(\\d+)\\b"
                        if let regex = try? NSRegularExpression(pattern: simplePattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            if let parsedScore = Int(String(lowerText[scoreRange])) {
                                score = parsedScore
                                print("  ✅ Found absolute score (simple digit): \(score!)")
                                break
                            }
                        }
                        
                        // Try simple pattern with written numbers: "name five"
                        let simpleWordPattern = "\\b\(escapedName)\\s+\\b(\(numberWords))\\b"
                        if let regex = try? NSRegularExpression(pattern: simpleWordPattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            let numberWord = String(lowerText[scoreRange])
                            if let parsedScore = parseNumberWord(numberWord) {
                                score = parsedScore
                                print("  ✅ Found absolute score (simple written): \(numberWord) = \(score!)")
                                break
                            }
                        }
                        
                        // Fallback to flexible pattern with digits: "name ... 5"
                        let flexiblePattern = "\\b\(escapedName)\\b.*?\\b(\\d+)\\b"
                        if let regex = try? NSRegularExpression(pattern: flexiblePattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            // Make sure the number is reasonably close to the name (within 20 characters)
                            let nameRange = match.range(at: 0)
                            let scoreStart = match.range(at: 1).location
                            let distance = scoreStart - (nameRange.location + nameRange.length)
                            
                            if distance <= 20, let parsedScore = Int(String(lowerText[scoreRange])) {
                                score = parsedScore
                                print("  ✅ Found absolute score (flexible digit): \(score!)")
                                break
                            }
                        }
                        
                        // Fallback to flexible pattern with written numbers: "name ... five"
                        let flexibleWordPattern = "\\b\(escapedName)\\b.*?\\b(\(numberWords))\\b"
                        if let regex = try? NSRegularExpression(pattern: flexibleWordPattern, options: .caseInsensitive),
                           let match = regex.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
                           let scoreRange = Range(match.range(at: 1), in: lowerText) {
                            let nameRange = match.range(at: 0)
                            let scoreStart = match.range(at: 1).location
                            let distance = scoreStart - (nameRange.location + nameRange.length)
                            
                            if distance <= 20 {
                                let numberWord = String(lowerText[scoreRange])
                                if let parsedScore = parseNumberWord(numberWord) {
                                    score = parsedScore
                                    print("  ✅ Found absolute score (flexible written): \(numberWord) = \(score!)")
                            break
                                }
                            }
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
            let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
            // If no hole score entry exists, or all players have no score for this hole
            if holeScore == nil || holeScore!.scores.isEmpty {
                return holeNumber
            }
            // Check if any player is missing a score for this hole
            var allPlayersHaveScores = true
            for player in game.playersArray {
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
    
    private func completeGame(_ game: Game) {
        game.isCompleted = true
        try? modelContext.save()
        
        if selectedGame?.id == game.id {
            _selectedGameIDString.wrappedValue = ""
        }
    }
    
    private func deleteGame(_ game: Game) {
        modelContext.delete(game)
        try? modelContext.save()
        
        if selectedGame?.id == game.id {
            _selectedGameIDString.wrappedValue = ""
        }
    }
    
    private func updateHoleScore(game: Game, holeNumber: Int, player: Player, score: Int) {
        if let existingHole = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber }) {
            print("  📝 Updating existing hole score")
            existingHole.setScore(for: player, score: score)
        } else {
            print("  📝 Creating new hole score")
            let newHoleScore = HoleScore(holeNumber: holeNumber)
            newHoleScore.setScore(for: player, score: score)
            if game.holesScores == nil { game.holesScores = [] }
            game.holesScores!.append(newHoleScore)
            modelContext.insert(newHoleScore)
        }
        
        do {
            try modelContext.save()
            print("  ✅ Score saved successfully!")
            
            // If this is the current hole, advance to next hole after all players have scores
            if holeNumber == currentHole {
                let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
                let allPlayersScored = game.playersArray.allSatisfy { player in
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


