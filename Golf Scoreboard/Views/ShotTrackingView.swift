//
//  ShotTrackingView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct ShotTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]
    @Query private var allShots: [Shot]
    
    @AppStorage("selectedGameID") private var selectedGameIDString: String = ""
    @AppStorage("currentHole") private var currentHole: Int = 1
    @State private var selectedPlayer: Player?
    @State private var lastShotPlayer: Player?
    @State private var showingShotEntry = false
    @State private var inputText = ""
    @State private var listening = false
    @State private var needsCleanup = false
    @State private var nextShotIsPutt = false // Flag to mark next shot as putt
    
    // Shot builder to accumulate information across multiple voice inputs
    struct PendingShot {
        var player: Player?
        var holeNumber: Int?
        var club: String?
        var result: ShotResult?
        var distance: Int? // yards
        var distanceFeet: Int? // feet (for putts)
        var isPutt: Bool = false
        var isLong: Bool = false
        var isShort: Bool = false
        var isPenalty: Bool = false
        var isRetaking: Bool = false // true if retaking from tee (vs taking a drop)
        
        var hasEssentialInfo: Bool { player != nil && (club != nil || result != nil) }
    }
    @State private var pendingShot: PendingShot?
    
    // Filter shots - use simple filtering without accessing potentially invalid game references
    private var shots: [Shot] {
        // Just return all shots and let SwiftData handle the relationships
        // The view will only display shots for the currently selected game
        return allShots
    }
    
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
                // Main content
                if let game = selectedGame {
                    GameShotsView(game: game, selectedHole: $currentHole, course: game.course, shots: shots, onAddShot: {
                        selectedPlayer = game.players.first
                        showingShotEntry = true
                    })
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "target")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("No Game Selected")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select a game from Scorecard tab to track shots")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                // Voice/Text Input Bar
                TextInputBar(inputText: $inputText, listening: $listening, onCommit: handleInput)
                    .background(Color(.systemBackground))
            }
            .navigationTitle("Shot Tracking")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(games) { game in
                            Button(game.course?.name ?? "Game") {
                                _selectedGameIDString.wrappedValue = game.id.uuidString
                            }
                        }
                    } label: {
                        Label("Games", systemImage: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showingShotEntry) {
                AddShotView(game: selectedGame, holeNumber: currentHole, player: selectedPlayer)
            }
            .onAppear {
                // Automatically select the most recent game when the view appears
                if selectedGame == nil, let recentGame = games.sorted(by: { $0.date > $1.date }).first {
                    _selectedGameIDString.wrappedValue = recentGame.id.uuidString
                }
                // Validate and clamp currentHole to valid range (1-18)
                if currentHole < 1 || currentHole > 18 {
                    currentHole = 1
                    print("⚠️ Invalid currentHole detected, resetting to 1")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shotsUpdated)) { _ in
                // Trigger a lightweight refresh by toggling state
                currentHole = currentHole
            }
        }
    }
    
    private func handleInput() {
        guard !inputText.isEmpty else { return }
        parseAndBuildOrSaveShot(text: inputText)
        inputText = ""
    }
    
    private func parseAndBuildOrSaveShot(text: String) {
        guard let game = selectedGame else {
            print("⚠️ No game selected for shot tracking")
            return
        }
        print("🎯 Parsing input: '\(text)'")
        
        // Check for special 'sunk putt' command first
        let lowerText = text.lowercased()
        let isSunkPuttCommand = lowerText.contains("sunk putt") || lowerText.contains("made putt") || lowerText.contains("holed") || lowerText.contains("in the hole")
        if isSunkPuttCommand {
            handleSunkPuttCommand(text: text)
            return
        }
        
        // Start with existing pending shot or create new one
        var currentShot = pendingShot ?? PendingShot()
        if pendingShot != nil {
            print("📝 Continuing to build pending shot...")
        } else {
            print("📝 Starting new shot")
        }
        
        // Apply nextShotIsPutt flag if it was set from previous shot
        if nextShotIsPutt {
            currentShot.isPutt = true
            if currentShot.club == nil {
                currentShot.club = "Putter"
                print("✅ Setting club to Putter (next shot is putt)")
            }
            nextShotIsPutt = false // Clear the flag after using it
        }
        
        // Parse this input and accumulate info
        parseIntoPendingShot(text: text, into: &currentShot, game: game)
        
        // Check if "on green" was mentioned - next shot should be a putt
        if lowerText.contains("on the green") || lowerText.contains("on green") {
            nextShotIsPutt = true
            print("⛳ Flagged next shot as putt (on green)")
        }
        
        // Update pending shot
        pendingShot = currentShot
        
        // If we have enough info to save, do so
        if shouldSaveShot(currentShot) {
            print("💾 Shot is complete, saving...")
            savePendingShot(&currentShot, game: game)
            pendingShot = nil // Reset for next shot
        } else {
            print("⏳ Waiting for more info (club: \(currentShot.club != nil), result: \(currentShot.result != nil), distance: \(currentShot.distance != nil))")
        }
    }
    
    private func shouldSaveShot(_ shot: PendingShot) -> Bool {
        guard shot.player != nil else { return false }
        
        // Check if we have enough information to save:
        // Need club OR (isPutt and distance) - putts are special case (club auto-assigned)
        // For non-putts: must have club AND (result OR distance)
        // For putts: can have just distance (club auto-assigned to Putter)
        if shot.isPutt {
            return shot.distance != nil || shot.distanceFeet != nil || shot.result != nil
        } else {
            return shot.club != nil && (shot.result != nil || shot.distance != nil)
        }
    }
    
    private func parseIntoPendingShot(text: String, into shot: inout PendingShot, game: Game) {
        
        // Normalize numbers words/homophones to digits for more robust parsing
        func normalizeNumbers(_ s: String) -> String {
            var t = s
            let map: [(pattern: String, replacement: String)] = [
                ("\\bone\\b", "1"),
                ("\\btwo\\b", "2"),
                ("\\bthree\\b|\\bthre+e\\b|\\btree\\b", "3"),
                ("\\bfour\\b|\\bfor\\b|\\bfore\\b", "4"),
                ("\\bfive\\b|\\bfibe\\b", "5"),
                ("\\bsix\\b", "6"),
                ("\\bseven\\b", "7"),
                ("\\beight\\b|\\bate\\b", "8"),
                ("\\bnine\\b|\\bnien\\b", "9"),
                ("\\bten\\b", "10")
            ]
            for (pattern, repl) in map {
                if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    t = re.stringByReplacingMatches(in: t, options: [], range: NSRange(t.startIndex..., in: t), withTemplate: repl)
                }
            }
            return t
        }
        
        let lowerText = normalizeNumbers(text.lowercased())
        
        // Extract player name
        var targetPlayer: Player?
        for player in game.players {
            let playerNameLower = player.name.lowercased()
            let nameParts = playerNameLower.components(separatedBy: " ")
            let firstName = nameParts.first ?? playerNameLower
            let lastName = nameParts.count > 1 ? nameParts.last! : ""
            
            if lowerText.contains(playerNameLower) || lowerText.contains(firstName) || lowerText.contains(lastName) {
                targetPlayer = player
                print("✅ Found player: \(player.name)")
                break
            }
        }
        
        // Fallbacks: last used player -> current user -> first player
        if targetPlayer == nil {
            if let last = lastShotPlayer, game.players.contains(where: { $0.id == last.id }) {
                targetPlayer = last
                print("👤 Using last player: \(last.name)")
            } else if let current = game.players.first(where: { $0.isCurrentUser }) {
                targetPlayer = current
                print("👤 Using current user: \(current.name)")
            } else {
                targetPlayer = game.players.first
                if let first = targetPlayer { print("👤 Defaulting to first player: \(first.name)") }
            }
        }
        
        // Extract distance BEFORE hole number to avoid conflicts
        var distance: Int? = nil // remaining distance to hole in yards
        var distanceFeet: Int? = nil // remaining distance in feet (for putts)
        // Pattern 1: "228 yards"
        if let distancePattern = try? NSRegularExpression(pattern: "(\\d+)\\s*yards?", options: .caseInsensitive),
           let match = distancePattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
           let distRange = Range(match.range(at: 1), in: lowerText) {
            distance = Int(String(lowerText[distRange]))
            print("✅ Found distance: \(distance!)")
        }
        // Pattern 2: feet for putts ("10 feet", "12 ft")
        if distance == nil, let feetPattern = try? NSRegularExpression(pattern: "(\\d+)\\s*(feet|foot|ft)", options: .caseInsensitive),
           let match = feetPattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
           let feetRange = Range(match.range(at: 1), in: lowerText),
           let feet = Int(String(lowerText[feetRange])) {
            distanceFeet = feet
            // Store internally as yards (rounded)
            let yards = Int(round(Double(feet) / 3.0))
            distance = yards
            print("✅ Found distance (feet): \(feet)ft -> ~\(yards)yds")
        }
        // Pattern 3: "228 to hole" or "to hole 228" - distance to hole
        if distance == nil, let toHolePattern = try? NSRegularExpression(pattern: "(\\d+)\\s+to\\s+(?:the\\s+)?hole|to\\s+(?:the\\s+)?hole\\s+(\\d+)\\s*(?:yards?|yds?)?", options: .caseInsensitive),
           let match = toHolePattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)) {
            // Check if first capture group matched
            if match.numberOfRanges > 1, let distRange1 = Range(match.range(at: 1), in: lowerText), !distRange1.isEmpty {
                distance = Int(String(lowerText[distRange1]))
                print("✅ Found distance (to hole): \(distance!)")
            } else if match.numberOfRanges > 2, let distRange2 = Range(match.range(at: 2), in: lowerText), !distRange2.isEmpty {
                distance = Int(String(lowerText[distRange2]))
                print("✅ Found distance (to hole): \(distance!)")
            }
        }
        
        // Extract hole number (optional - defaults to current hole)
        // Match "hole 7" but not "7 iron" - require word boundary after number
        // Also check that hole number is in valid range (1-18)
        // IMPORTANT: Don't match if this appears to be part of a "to hole X" distance phrase
        var holeNum = currentHole
        if let holePattern = try? NSRegularExpression(pattern: "\\bhole\\s+(\\d+)\\b", options: .caseInsensitive),
           let holeMatch = holePattern.firstMatch(in: lowerText, range: NSRange(lowerText.startIndex..., in: lowerText)),
           let holeRange = Range(holeMatch.range(at: 1), in: lowerText),
           let extractedHole = Int(String(lowerText[holeRange])),
           extractedHole >= 1 && extractedHole <= 18 {
            // Check if this is part of "to hole X" pattern - if so, ignore it
            let matchRange = holeMatch.range
            let startIndex = lowerText.index(lowerText.startIndex, offsetBy: max(0, matchRange.location - 20))
            let endIndex = lowerText.index(lowerText.startIndex, offsetBy: min(lowerText.count, matchRange.location + matchRange.length + 20))
            let context = String(lowerText[startIndex..<endIndex])
            
            // If we see "to hole" nearby, this is likely a distance phrase, not a hole number
            if !context.contains("to hole") && !context.contains("hole to") {
                holeNum = extractedHole
                print("✅ Found hole: \(holeNum)")
                // Update the current hole to match
                currentHole = holeNum
            } else {
                print("📍 Ignoring 'hole X' as it appears to be part of a distance phrase")
            }
        } else {
            print("📍 No hole specified, using current hole: \(holeNum)")
        }
        
        // Extract club with synonyms
        var club: String? = nil
        let clubSynonyms: [(pattern: String, label: String)] = [
            ("driver", "Driver"),
            ("(?:3|three|thre+e|tree)\\s*wood|3w", "3 Wood"),
            ("(?:5|five)\\s*wood|5w", "5 Wood"),
            ("(?:3|three|thre+e|tree)\\s*hybrid|3h", "3 Hybrid"),
            ("(?:4|four)\\s*hybrid|4h", "4 Hybrid"),
            ("(?:5|five)\\s*hybrid|5h", "5 Hybrid"),
            ("(?:3|three|thre+e|tree)\\s*iron", "3 Iron"), ("(?:4|four)\\s*iron", "4 Iron"), ("(?:5|five)\\s*iron", "5 Iron"),
            ("6\\s*iron", "6 Iron"), ("7\\s*iron", "7 Iron"), ("8\\s*iron", "8 Iron"), ("9\\s*iron", "9 Iron"),
            ("pitching\\s*wedge|pw", "PW"),
            ("gap\\s*wedge|gw|50\\s*degree|50\\s*deg|50°|52\\s*degree|52\\s*deg|52°", "GW"),
            ("sand\\s*wedge|sw|54\\s*degree|54\\s*deg|54°|56\\s*degree|56\\s*deg|56°", "SW"),
            ("lob\\s*wedge|lw|58\\s*degree|58\\s*deg|58°|60\\s*degree|60\\s*deg|60°", "LW"),
            ("putter|putt|putting|put ", "Putter")
        ]
        for (pattern, label) in clubSynonyms {
            if lowerText.range(of: pattern, options: [.regularExpression]) != nil {
                club = label
                print("✅ Found club: \(label)")
                break
            }
        }
        
        // Extract result with enhanced natural language parsing
        var result: ShotResult = .straight
        var hasExplicitResult = false
        if lowerText.contains("straight") || lowerText.contains("center") || lowerText.contains("on the green") || lowerText.contains("on green") {
            result = .straight
            hasExplicitResult = true
        } else if lowerText.contains("right") || lowerText.contains("down the right") || lowerText.contains("to the right") {
            result = .right
            hasExplicitResult = true
        } else if lowerText.contains("left") || lowerText.contains("down the left") || lowerText.contains("to the left") {
            result = .left
            hasExplicitResult = true
        } else if lowerText.contains("out of bounds") || lowerText.contains("o b") || lowerText.contains("ob ") {
            result = .outOfBounds
            hasExplicitResult = true
        } else if lowerText.contains("hazard") || lowerText.contains("water") {
            result = .hazard
            hasExplicitResult = true
        } else if lowerText.contains("trap") || lowerText.contains("sand") || lowerText.contains("bunker") {
            result = .trap
            hasExplicitResult = true
        } else if lowerText.contains("fairway") || lowerText.contains("rough") {
            // Fairway/rough generally means straight
            result = .straight
            hasExplicitResult = true
        }
        
        // Determine if it's a putt with enhanced detection
        // Also if distance is in feet, it's likely a putt
        var isPutt = lowerText.contains("putt") || lowerText.contains("putting") || lowerText.contains(" put ") || club?.lowercased() == "putter"
        
        // Putt modifiers
        let isLong = lowerText.contains("long") || lowerText.contains("over the pin") || lowerText.contains("over the green") || lowerText.contains("back of the green")
        let isShort = lowerText.contains("short") || lowerText.contains("short of the pin") || lowerText.contains("short of the green")
        
        // Detect penalties and retaking
        var isPenalty = result == .outOfBounds || result == .hazard
        var isRetaking = false
        
        // Check if this is a retaking from tee (driver or tee mentioned, "hit again", or "here again")
        if lowerText.contains("retee") || lowerText.contains("re tee") || lowerText.contains("hitting from") || lowerText.contains("tee off") || 
           lowerText.contains("driver") || club?.lowercased() == "driver" || lowerText.contains("from the tee") || lowerText.contains("hit again") || lowerText.contains("here again") {
            isRetaking = true
            print("⛳ Detected RETAKING from tee after penalty")
        } else if isPenalty {
            // Taking a drop - shot number increments normally
            print("⛳ Detected DROP after penalty")
        }
        
        // If distance was specified in feet (not yards), it's a putt
        if distanceFeet != nil && !isPutt {
            isPutt = true
            print("✅ Detected PUTT (distance in feet)")
        }
        
        if isLong { print("⛳ Detected LONG putt modifier") }
        if isShort { print("⛳ Detected SHORT putt modifier") }
        if isPutt { print("⛳ Detected PUTT") }
        if isPenalty { print("⛳ Detected PENALTY shot") }
        
        // If we detected a putt, default to Putter
        if isPutt && club == nil {
            club = "Putter"
            print("✅ Setting club to Putter (putt detected)")
        }
        
        // Update shot with extracted information (only set if we found values)
        if let player = targetPlayer {
            shot.player = player
        }
        if club != nil {
            shot.club = club
        }
        if hasExplicitResult {
            shot.result = result
        }
        if distance != nil {
            shot.distance = distance
        }
        if distanceFeet != nil {
            shot.distanceFeet = distanceFeet
        }
        if isPutt {
            shot.isPutt = isPutt
        }
        if isLong {
            shot.isLong = true
        }
        if isShort {
            shot.isShort = true
        }
        // Note: isPenalty is NOT set here - it's set in savePendingShot based on the previous shot
        if isRetaking {
            shot.isRetaking = true
        }
        if holeNum != currentHole {
            shot.holeNumber = holeNum
        }
    }
    
    private func savePendingShot(_ pending: inout PendingShot, game: Game) {
        guard let player = pending.player else {
            print("❌ Cannot save shot without player")
            return
        }
        
        let holeNum = pending.holeNumber ?? currentHole
        
        // Calculate shot number automatically
        let previousShots = shots.filter { 
            $0.player?.id == player.id && 
            $0.holeNumber == holeNum 
        }.sorted { $0.shotNumber < $1.shotNumber }
        
        var shotNum = (previousShots.last?.shotNumber ?? 0) + 1
        
        // Check if previous shot resulted in a penalty and adjust shot number
        if shotNum > 1, let prev = previousShots.last {
            var penaltyStrokes = 0
            
            if prev.result == "In a Hazard" && !prev.isPenalty {
                // Hazard: 1 stroke penalty
                penaltyStrokes = 1
                prev.isPenalty = true
                print("🏌️ Previous shot went into HAZARD - adding 1 stroke penalty")
            } else if prev.result == "Out of Bounds" && !prev.isPenalty {
                // Out of bounds: Check if re-teeing or taking a drop
                if pending.isRetaking {
                    // Re-tee option: 1 stroke penalty (next shot is #3)
                    penaltyStrokes = 1
                    print("🏌️ Previous shot went OUT OF BOUNDS - re-teeing with 1 stroke penalty")
                } else {
                    // Take a drop option: 2 stroke penalty (next shot is #4)
                    penaltyStrokes = 2
                    print("🏌️ Previous shot went OUT OF BOUNDS - taking a drop with 2 stroke penalty")
                }
                prev.isPenalty = true
            }
            
            // Adjust shot number based on penalty
            if penaltyStrokes > 0 {
                shotNum += penaltyStrokes
                // Mark this as a penalty stroke
                pending.isPenalty = true
                print("🏌️ Adjusted shot number to \(shotNum) due to penalty")
            }
        }
        
        // If this is shot #1 and no distance provided, use hole length
        var shotDistance = pending.distance
        if shotNum == 1 && shotDistance == nil {
            // Get hole distance from course
            if let course = game.course,
               let hole = course.holes.first(where: { $0.holeNumber == holeNum }) {
                if let white = hole.teeDistances.first(where: { $0.teeColor.lowercased() == "white" }) {
                    shotDistance = white.distanceYards
                } else if let first = hole.teeDistances.first {
                    shotDistance = first.distanceYards
                }
                print("📍 Using hole distance: \(shotDistance!) yards")
            }
        }
        
        // If this is a re-tee shot and no distance provided, use previous shot's distance
        // (If player provides a distance for a drop area, that will be used instead)
        if pending.isRetaking && shotDistance == nil, shotNum > 1, let prev = previousShots.last, let prevDistance = prev.distanceToHole {
            shotDistance = prevDistance
            print("⛳ Re-tee shot: using previous shot distance: \(shotDistance!) yards")
        }
        
        // Handle putt modifiers: update previous putt's distance if this is a short/long putt
        // Note: Use previousShots before penalty adjustment for getting the actual previous shot
        if shotNum > 1, let prev = previousShots.last, prev.isPutt, pending.isPutt {
            if pending.isShort || pending.isLong {
                // This is a follow-up putt with a modifier - update the previous putt's distance
                if let prevFeet = prev.originalDistanceFeet, let currentFeet = pending.distanceFeet {
                    var newPrevFeet = prevFeet
                    if pending.isShort {
                        // Ball stopped short: previous putt was current feet SHORTER than it landed
                        // Example: "10 feet" then "1 foot short" means previous was actually 9 feet
                        newPrevFeet = prevFeet - currentFeet
                        print("⛳ Putt was \(currentFeet)ft short. Updating previous putt from \(prevFeet)ft to \(newPrevFeet)ft")
                    } else if pending.isLong {
                        // Ball went long: previous putt was current feet LONGER than it landed
                        // Example: "10 feet" then "2 feet long" means previous was actually 12 feet
                        newPrevFeet = prevFeet + currentFeet
                        print("⛳ Putt was \(currentFeet)ft long. Updating previous putt from \(prevFeet)ft to \(newPrevFeet)ft")
                    }
                    
                    // Update previous putt's distance
                    if newPrevFeet > 0 {
                        prev.originalDistanceFeet = newPrevFeet
                        prev.distanceToHole = Int(round(Double(newPrevFeet) / 3.0))
                    }
                }
            }
        }
        
        // Calculate previous non-putt shot's distance traveled if applicable
        if shotNum > 1, let prev = previousShots.last, let prevRemaining = prev.distanceToHole, let currRemaining = shotDistance, !prev.isPutt {
            var effectiveCurrent = Double(currRemaining)
            
            // Adjust for putt long/short modifiers
            if pending.isPutt, let feet = pending.distanceFeet {
                let yardsFromFeet = Double(feet) / 3.0
                if pending.isLong {
                    // Ball went past the hole - previous shot traveled MORE (went yardsFromFeet beyond hole)
                    // If went 10ft past hole, ball ended 0yds (at hole) minus the overshoot
                    effectiveCurrent = -yardsFromFeet
                    print("⛳ Putt was \(feet)ft long, previous shot was \(String(format: "%.1f", yardsFromFeet))yds beyond the hole.")
                } else if pending.isShort {
                    // Ball stopped short - previous shot traveled LESS (stopped yardsFromFeet short of hole)
                    // If stopped 10ft short of hole, add that distance
                    effectiveCurrent = yardsFromFeet
                    print("⛳ Putt was \(feet)ft short, previous shot was \(String(format: "%.1f", yardsFromFeet))yds short of the hole.")
                } else {
                    print("⛳ No long/short modifier for \(feet)ft putt")
                }
            }
            
            // Adjust for non-putt long/short modifiers (e.g., "7 iron left and long")
            if !pending.isPutt && (pending.isLong || pending.isShort) {
                // For non-putt shots with long/short, use the distance provided in the current shot
                // This handles cases like "7 iron left and long to hole 50 yards"
                // The adjustment is implicit in the distance to hole measurement
                if pending.isLong {
                    print("⏫ Shot went long: previous shot traveled beyond initial estimate")
                } else if pending.isShort {
                    print("⏬ Shot came short: previous shot didn't travel as far as estimated")
                }
            }
            
            let traveled = Int(round(Double(prevRemaining) - effectiveCurrent))
            prev.distanceTraveled = traveled
            print("📏 Updated previous Shot #\(prev.shotNumber): \(prevRemaining)yds - \(effectiveCurrent)yds = \(traveled)yds")
        }
        
        // Create and save the shot
        let newShot = Shot(
            player: player,
            holeNumber: holeNum,
            shotNumber: shotNum,
            distanceToHole: shotDistance,
            originalDistanceFeet: pending.distanceFeet,
            club: pending.club,
            result: pending.result ?? .straight,
            isPutt: pending.isPutt,
            distanceTraveled: nil, // Will be calculated after next shot
            isPenalty: pending.isPenalty,
            isRetaking: pending.isRetaking
        )
        
        newShot.game = game
        
        modelContext.insert(newShot)
        do {
            try modelContext.save()
            print("✅ Shot #\(shotNum) saved successfully!")
            lastShotPlayer = player
            
            if shotNum > 1, let dist = shotDistance {
                recalculateShotDistances(for: player, on: holeNum, newShotDistance: dist, context: modelContext)
            }
            
            NotificationCenter.default.post(name: .shotsUpdated, object: nil)
        } catch {
            print("❌ Error saving shot: \(error)")
        }
    }
    
    // Legacy handler for sunk putt commands (kept for compatibility)
    private func handleSunkPuttCommand(text: String) {
        guard let game = selectedGame else { return }
        
        let lowerText = text.lowercased()
        let isSunkPuttCommand = lowerText.contains("sunk putt") || lowerText.contains("made putt") || lowerText.contains("holed") || lowerText.contains("in the hole")
        
        if isSunkPuttCommand {
            // Determine player from pending shot or fallback
            let targetPlayer = pendingShot?.player ?? lastShotPlayer ?? game.players.first(where: { $0.isCurrentUser }) ?? game.players.first
            
            if let player = targetPlayer {
                let playerShotsThisHole = shots.filter { $0.player?.id == player.id && $0.holeNumber == currentHole }
                // Use max shot number instead of count to account for penalty strokes
                let totalShots = playerShotsThisHole.map { $0.shotNumber }.max() ?? 0
                finalizeHoleScore(for: player, on: currentHole, shotsCount: totalShots)
                pendingShot = nil // Clear pending shot
            }
        }
    }
    
    private func recalculateShotDistances(for player: Player, on holeNumber: Int, newShotDistance: Int, context: ModelContext) {
        // Get all shots for this player on this hole, sorted by shot number
        let shots = allShots.filter { 
            $0.player?.id == player.id && 
            $0.holeNumber == holeNumber 
        }.sorted { $0.shotNumber < $1.shotNumber }
        
        // Recalculate distanceTraveled for all shots up to the current one
        for (index, shot) in shots.enumerated() {
            if index < shots.count - 1 {
                // This is not the last shot, calculate distance to next shot
                let nextShot = shots[index + 1]
                if let currentDistance = shot.distanceToHole, let nextDistance = nextShot.distanceToHole {
                    let traveled = currentDistance - nextDistance
                    // Only update if distanceTraveled is nil (hasn't been set with putt adjustments)
                    if shot.distanceTraveled == nil {
                        shot.distanceTraveled = traveled
                        print("📏 Recalculated Shot #\(shot.shotNumber): \(currentDistance)yds - \(nextDistance)yds = \(traveled)yds")
                    } else {
                        print("📏 Skipping recalculation for Shot #\(shot.shotNumber) (already set with putt adjustment)")
                    }
                }
            }
            // Last shot doesn't have a distance traveled yet (needs next shot)
        }
        
        do {
            try context.save()
            print("✅ Distances recalculated")
        } catch {
            print("❌ Error recalculating distances: \(error)")
        }
    }
    
    private func finalizeHoleScore(for player: Player, on holeNumber: Int, shotsCount: Int) {
        guard let game = selectedGame else { return }
        
        // Find the last shot for this hole and set distanceTraveled to 0 if it's a putt
        let playerShots = allShots.filter { 
            $0.player?.id == player.id && 
            $0.holeNumber == holeNumber 
        }.sorted { $0.shotNumber < $1.shotNumber }
        
        if let lastShot = playerShots.last, lastShot.isPutt, lastShot.distanceTraveled == nil {
            lastShot.distanceTraveled = 0
            print("✅ Set final putt distanceTraveled to 0 (holed)")
        }
        
        // Update or create HoleScore for this hole
        if let existingHole = game.holesScores.first(where: { $0.holeNumber == holeNumber }) {
            existingHole.scores[player.id] = shotsCount
        } else {
            let newHoleScore = HoleScore(holeNumber: holeNumber, scores: [player.id: shotsCount])
            game.holesScores.append(newHoleScore)
            modelContext.insert(newHoleScore)
        }
        
        do {
            try modelContext.save()
            print("✅ Finalized score for \(player.name) on hole \(holeNumber): \(shotsCount)")
            
            // Advance current hole if all players have scores on this hole
            let holeScore = game.holesScores.first(where: { $0.holeNumber == holeNumber })
            let allPlayersScored = game.players.allSatisfy { p in
                holeScore?.scores[p.id] != nil
            }
            if allPlayersScored && currentHole == holeNumber && currentHole < 18 {
                currentHole += 1
                print("📍 All players scored. Advancing to hole \(currentHole)")
            }
        } catch {
            print("❌ Error finalizing hole score: \(error)")
        }
    }
}

struct GameShotsView: View {
    let game: Game
    @Binding var selectedHole: Int
    let course: GolfCourse?
    let shots: [Shot]
    var onAddShot: () -> Void
    
    // Hole yardage from the scorecard
    private var holeYardage: Int? {
        guard let course = course,
              let hole = course.holes.first(where: { $0.holeNumber == selectedHole }) else { return nil }
        if let white = hole.teeDistances.first(where: { $0.teeColor.lowercased() == "white" }) {
            return white.distanceYards
        }
        return hole.teeDistances.first?.distanceYards
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Hole selector with visual indicator
            VStack(spacing: 8) {
                HStack {
                    Text("Current Hole")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("\(selectedHole)/18")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let yards = holeYardage {
                            Text("• \(yards) yds")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                Picker("Hole", selection: $selectedHole) {
                    ForEach(1...18, id: \.self) { hole in
                        Text("\(hole)").tag(hole)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            // Shot list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(game.players) { player in
                        ShotGroupCard(player: player, holeNumber: selectedHole, allShots: shots, currentGame: game)
                    }
                }
                .padding()
            }
            
            // Add shot button
            Button(action: onAddShot) {
                Label("Add Shot", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct ShotGroupCard: View {
    @Environment(\.modelContext) private var modelContext
    let player: Player
    let holeNumber: Int
    let allShots: [Shot]
    let currentGame: Game?
    
    var playerShots: [Shot] {
        // Filter strictly by player and hole to avoid touching possibly invalidated game references
        allShots.filter { shot in
            shot.player?.id == player.id && shot.holeNumber == holeNumber
        }
        .sorted { $0.shotNumber < $1.shotNumber }
    }
    
    // Whether this player has a finalized score on this hole (e.g., via 'sunk putt')
    private var isHoled: Bool {
        guard let game = currentGame,
              let holeScore = game.holesScores.first(where: { $0.holeNumber == holeNumber }) else { return false }
        return holeScore.scores[player.id] != nil
    }
    
    var summary: ShotSummary {
        var summary = ShotSummary()
        // Use max shot number instead of count to account for penalty strokes
        summary.totalShots = playerShots.map { $0.shotNumber }.max() ?? 0
        summary.totalPutts = playerShots.filter { $0.isPutt }.count
        
        for shot in playerShots {
            summary.shotsByResult[shot.result, default: 0] += 1
            if let club = shot.club {
                summary.shotsByClub[club, default: 0] += 1
            }
        }
        
        let distances = playerShots.compactMap { $0.distanceToHole }
        if !distances.isEmpty {
            summary.avgDistance = Double(distances.reduce(0, +)) / Double(distances.count)
        }
        
        return summary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(player.name)
                    .font(.headline)
                if isHoled {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Holed")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                }
            }
            
            if playerShots.isEmpty {
                Text("No shots recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(playerShots, id: \.id) { shot in
                    ShotRow(shot: shot) {
                        // Delete callback
                        modelContext.delete(shot)
                        try? modelContext.save()
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total: \(summary.totalShots)")
                        Text("Putts: \(summary.totalPutts)")
                    }
                    .font(.caption)
                    
                    Spacer()
                    
                    if let avgDist = summary.avgDistance {
                        Text("Avg Dist: \(Int(avgDist))yds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ShotRow: View {
    @State private var showingEditShot = false
    let shot: Shot
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text("\(shot.shotNumber)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 30)
            
            if let club = shot.club {
                Text(club)
                    .font(.caption)
            }
            
            // Show shot distance traveled for non-putts; for putts, show remaining in feet
            if let traveled = shot.distanceTraveled, shot.isPutt == false {
                Text("\(traveled)yds")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            } else if let remaining = shot.distanceToHole, shot.isPutt == false {
                Text("to hole \(remaining)yds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else if shot.isPutt {
                if let traveled = shot.distanceTraveled, traveled == 0 {
                    // Holed putt - no "to hole" prefix
                    if let originalFeet = shot.originalDistanceFeet {
                        Text("\(originalFeet)ft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else if let remaining = shot.distanceToHole {
                        let feet = remaining * 3
                        Text("\(feet)ft")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else if let originalFeet = shot.originalDistanceFeet {
                    Text("to hole \(originalFeet)ft")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else if let remaining = shot.distanceToHole {
                    let feet = remaining * 3
                    Text("to hole \(feet)ft")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text("...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            } else {
                Text("...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            Spacer()
            
            Text(shot.result)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if shot.isPutt {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Menu {
                Button(action: { showingEditShot = true }) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEditShot) {
            EditShotView(shot: shot)
        }
    }
}

#Preview {
    ShotTrackingView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self, Shot.self], inMemory: true)
}

