//
//  GameSetupView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct GameSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedGameIDString: String
    @AppStorage("currentHole") private var currentHole: Int = 1
    let games: [Game]
    
    @Query private var courses: [GolfCourse]
    @Query private var players: [Player]
    
    @State private var selectedCourse: GolfCourse?
    @State private var selectedPlayers: Set<UUID> = []
    @State private var selectedTeeColor: String? = nil
    @StateObject private var calendarManager = CalendarEventManager()
    @State private var isLoadingCalendar = false
    @State private var calendarError: String?
    @State private var calendarStatusMessage: String?
    @State private var calendarEventDate: Date?
    
    private var availableTeeColors: [String] {
        guard let course = selectedCourse else { return [] }
        let teeColors = Set((course.holes ?? []).flatMap { ($0.teeDistances ?? []).map { $0.teeColor } })
        return teeColors.sorted()
    }
    
    private var defaultTeeColor: String? {
        // Priority: 1) Current user's preferred tee (if available), 2) White, 3) Green, 4) First available
        if let currentUser = players.first(where: { $0.isCurrentUser }),
           let preferredTee = currentUser.preferredTeeColor,
           availableTeeColors.contains(preferredTee) {
            return preferredTee
        }
        
        // Default to White if available
        if availableTeeColors.contains("White") {
            return "White"
        }
        
        // Fallback to Green if available
        if availableTeeColors.contains("Green") {
            return "Green"
        }
        
        // Otherwise, use first available
        return availableTeeColors.first
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Calendar import section
                if isLoadingCalendar {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Loading calendar events...")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let error = calendarError {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                            Button("Try Again") {
                                Task {
                                    await loadCalendarEvents()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                } else if let statusMessage = calendarStatusMessage {
                    Section {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text(statusMessage)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                            Button("Reload") {
                                Task {
                                    await loadCalendarEvents()
                                }
                            }
                            .font(.caption)
                        }
                    }
                } else if selectedCourse != nil || !selectedPlayers.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Imported from calendar event")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Reload") {
                                Task {
                                    await loadCalendarEvents()
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                
                Section("Course") {
                    if courses.isEmpty {
                        Text("No courses available. Add courses first.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Course", selection: $selectedCourse) {
                            Text("None").tag(nil as GolfCourse?)
                            ForEach(courses) { course in
                                Text(course.name).tag(course as GolfCourse?)
                            }
                        }
                        .onChange(of: selectedCourse) { _, _ in
                            // Reset tee selection when course changes
                            selectedTeeColor = defaultTeeColor
                        }
                    }
                    
                    NavigationLink("Add Course") {
                        AddCourseView()
                    }
                }
                
                // Tee selection section (only show when course is selected and has tees)
                if let course = selectedCourse, !availableTeeColors.isEmpty {
                    Section("Tee Selection") {
                        Picker("Tee Color", selection: $selectedTeeColor) {
                            Text("Default (Player Preference)").tag(nil as String?)
                            ForEach(availableTeeColors, id: \.self) { teeColor in
                                Text(teeColor).tag(teeColor as String?)
                            }
                        }
                        
                        if let defaultTee = defaultTeeColor {
                            Text("Default: \(defaultTee)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Players") {
                    if players.isEmpty {
                        Text("No players available. Add players first.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(players) { player in
                            Button {
                                if selectedPlayers.contains(player.id) {
                                    selectedPlayers.remove(player.id)
                                } else {
                                    selectedPlayers.insert(player.id)
                                }
                            } label: {
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    if selectedPlayers.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    NavigationLink("Add Player") {
                        AddPlayerView()
                    }
                }
            }
            .onAppear {
                // Initialize tee selection if course is already selected
                if selectedCourse != nil && selectedTeeColor == nil && !availableTeeColors.isEmpty {
                    selectedTeeColor = defaultTeeColor
                }
                
                // Load calendar events if no course/players are already selected
                if selectedCourse == nil && selectedPlayers.isEmpty {
                    Task {
                        await loadCalendarEvents()
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start") {
                        startGame()
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }
    
    private func loadCalendarEvents() async {
        isLoadingCalendar = true
        calendarError = nil
        calendarStatusMessage = nil
        calendarEventDate = nil
        
        print("📅 Starting calendar event loading...")
        
        // Check authorization status
        calendarManager.checkAuthorizationStatus()
        
        // Request access if needed
        if calendarManager.authorizationStatus == .notDetermined {
            print("📅 Requesting calendar access...")
            do {
                try await calendarManager.requestAccess()
                print("📅 Calendar access request completed")
            } catch {
                print("❌ Failed to request calendar access: \(error)")
                await MainActor.run {
                    calendarError = "Failed to request calendar access: \(error.localizedDescription)"
                    isLoadingCalendar = false
                }
                return
            }
        }
        
        // Check authorization status (handle iOS 17+ separately)
        if #available(iOS 17.0, *) {
            // For iOS 17+, check actual access status
            calendarManager.checkAuthorizationStatus()
            if calendarManager.authorizationStatus != .authorized {
                print("❌ Calendar access not authorized (iOS 17+)")
                await MainActor.run {
                    calendarError = "Calendar access is required to import events"
                    isLoadingCalendar = false
                }
                return
            }
        } else {
            // For iOS 16 and earlier
            if calendarManager.authorizationStatus != .authorized {
                print("❌ Calendar access not authorized")
                await MainActor.run {
                    calendarError = "Calendar access is required to import events"
                    isLoadingCalendar = false
                }
                return
            }
        }
        
        print("✅ Calendar access granted, fetching events...")
        
        // Fetch events for today and next few days (to catch upcoming games)
        do {
            let calendar = Calendar.current
            let today = Date()
            var golfEvents: [GolfEvent] = []
            
            // Check today and next 7 days
            for dayOffset in 0..<7 {
                let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
                let dayName = dayOffset == 0 ? "today" : (dayOffset == 1 ? "tomorrow" : "in \(dayOffset) days")
                
                print("📅 Checking events for \(dayName) (\(checkDate))")
                let events = try await calendarManager.fetchGolfEvents(for: checkDate)
                
                if !events.isEmpty {
                    print("📅 Found \(events.count) golf event(s) for \(dayName)")
                    golfEvents.append(contentsOf: events)
                    
                    // If we found events for today or tomorrow, prefer those
                    // Otherwise, use the earliest found event
                    if dayOffset <= 1 {
                        break // Use today or tomorrow's events
                    }
                }
            }
            
            print("📅 Total found: \(golfEvents.count) golf event(s)")
            
            if golfEvents.isEmpty {
                print("⚠️ No golf events found in the next 7 days")
                await MainActor.run {
                    calendarStatusMessage = "No golf events found in the next 7 days"
                    isLoadingCalendar = false
                }
                return
            }
            
            // Sort events by date and use the earliest one
            let sortedEvents = golfEvents.sorted { $0.eventDate < $1.eventDate }
            if let firstEvent = sortedEvents.first {
                let eventDateFormatter = DateFormatter()
                eventDateFormatter.dateStyle = .medium
                eventDateFormatter.timeStyle = .none
                let eventDateString = eventDateFormatter.string(from: firstEvent.eventDate)
                
                print("📅 Processing event for \(eventDateString): course='\(firstEvent.course)', players=\(firstEvent.players)")
                
                // Store the calendar event date
                await MainActor.run {
                    calendarEventDate = firstEvent.eventDate
                }
                
                // Match course
                var matchedCourse: GolfCourse? = nil
                if let course = matchCourse(from: firstEvent.course) {
                    print("✅ Matched course: \(course.name)")
                    matchedCourse = course
                    await MainActor.run {
                        selectedCourse = course
                        // Initialize tee selection
                        if selectedTeeColor == nil && !availableTeeColors.isEmpty {
                            selectedTeeColor = defaultTeeColor
                        }
                    }
                } else {
                    print("⚠️ Could not match course: '\(firstEvent.course)'")
                    await MainActor.run {
                        calendarStatusMessage = "Found event but couldn't match course: \(firstEvent.course)"
                    }
                }
                
                // Match players
                let matchedPlayers = matchPlayers(from: firstEvent.players)
                print("📅 Matched \(matchedPlayers.count) out of \(firstEvent.players.count) players")
                
                if !matchedPlayers.isEmpty {
                    print("✅ Matched players: \(matchedPlayers.map { $0.name })")
                    await MainActor.run {
                        selectedPlayers = Set(matchedPlayers.map { $0.id })
                    }
                } else {
                    print("⚠️ Could not match any players from: \(firstEvent.players)")
                    if calendarStatusMessage == nil {
                        await MainActor.run {
                            calendarStatusMessage = "Found event but couldn't match players"
                        }
                    }
                }
                
                // Update status message if we successfully matched something
                if matchedCourse != nil || !matchedPlayers.isEmpty {
                    await MainActor.run {
                        calendarStatusMessage = nil // Clear status if we successfully imported
                    }
                }
            }
        } catch {
            print("❌ Error fetching calendar events: \(error)")
            await MainActor.run {
                calendarError = error.localizedDescription
            }
        }
        
        await MainActor.run {
            isLoadingCalendar = false
        }
        print("📅 Calendar event loading completed")
    }
    
    private func matchCourse(from courseName: String) -> GolfCourse? {
        let lowerCourseName = courseName.lowercased()
        
        // Try exact match first
        if let exactMatch = courses.first(where: { $0.name.lowercased() == lowerCourseName }) {
            return exactMatch
        }
        
        // Try substring match (course name contains event name or vice versa)
        for course in courses {
            let courseNameLower = course.name.lowercased()
            
            if courseNameLower.contains(lowerCourseName) || lowerCourseName.contains(courseNameLower) {
                return course
            }
            
            // Try matching on key words (excluding common words)
            let courseWords = courseNameLower.components(separatedBy: " ").filter {
                !["the", "at", "club", "golf", "and"].contains($0) && $0.count > 2
            }
            let searchWords = lowerCourseName.components(separatedBy: " ").filter {
                !$0.isEmpty && $0.count > 2
            }
            
            // Check if all search words are found in course words
            var allWordsMatched = true
            for searchWord in searchWords {
                var wordFound = false
                for courseWord in courseWords {
                    if courseWord == searchWord || courseWord.contains(searchWord) || searchWord.contains(courseWord) {
                        wordFound = true
                        break
                    }
                }
                if !wordFound {
                    allWordsMatched = false
                    break
                }
            }
            
            if allWordsMatched && !searchWords.isEmpty {
                return course
            }
        }
        
        return nil
    }
    
    private func matchPlayers(from playerNames: [String]) -> [Player] {
        var matchedPlayers: [Player] = []
        
        // Common nickname mappings
        let nicknameMap: [String: [String]] = [
            "daniel": ["dan", "danny", "daniel"],
            "dave": ["david", "dave", "davey"],
            "mike": ["michael", "mike", "mikey"],
            "chris": ["christopher", "chris", "christian"],
            "bob": ["robert", "bob", "rob", "robby"],
            "bill": ["william", "bill", "billy", "will"],
            "jim": ["james", "jim", "jimmy"],
            "tom": ["thomas", "tom", "tommy"],
            "rich": ["richard", "rich", "rick", "dick"],
            "joe": ["joseph", "joe", "joey"],
            "ed": ["edward", "ed", "eddie", "ted"],
            "john": ["john", "jon", "johnny"],
            "steve": ["steven", "stephen", "steve", "stevie"],
            "matt": ["matthew", "matt", "matty"],
            "pat": ["patrick", "pat", "patty"],
        ]
        
        for name in playerNames {
            let nameLower = name.lowercased().trimmingCharacters(in: .whitespaces)
            let nameParts = nameLower.components(separatedBy: " ").filter { !$0.isEmpty }
            let calendarFirstName = nameParts.first ?? ""
            let calendarLastName = nameParts.count > 1 ? nameParts.last! : ""
            
            print("  🔍 Trying to match: '\(nameLower)' (first: '\(calendarFirstName)', last: '\(calendarLastName)')")
            
            // Try to match player by first name, last name, or full name
            for player in players {
                let playerNameLower = player.name.lowercased()
                let playerNameParts = playerNameLower.components(separatedBy: " ").filter { !$0.isEmpty }
                let playerFirstName = playerNameParts.first ?? playerNameLower
                let playerLastName = playerNameParts.count > 1 ? playerNameParts.last! : ""
                
                // Check exact match
                if playerNameLower == nameLower {
                    print("    ✅ Exact match: '\(player.name)'")
                    if !matchedPlayers.contains(where: { $0.id == player.id }) {
                        matchedPlayers.append(player)
                        break
                    }
                }
                
                // Check if last names match (with first name variations)
                if !calendarLastName.isEmpty && !playerLastName.isEmpty {
                    // Try exact last name match first
                    if calendarLastName == playerLastName {
                        // Last names match, check if first names match or are nicknames
                        if calendarFirstName == playerFirstName {
                            print("    ✅ Last name + first name match: '\(player.name)'")
                            if !matchedPlayers.contains(where: { $0.id == player.id }) {
                                matchedPlayers.append(player)
                                break
                            }
                        } else {
                            // Check nickname variations
                            var matched = false
                            
                            // Check if calendar first name is a nickname of player first name
                            if let nicknames = nicknameMap[playerFirstName] {
                                if nicknames.contains(calendarFirstName) {
                                    print("    ✅ Last name + nickname match: '\(calendarFirstName)' -> '\(player.name)'")
                                    matched = true
                                }
                            }
                            
                            // Check if player first name is a nickname of calendar first name
                            if let calendarNicknames = nicknameMap[calendarFirstName] {
                                if calendarNicknames.contains(playerFirstName) {
                                    print("    ✅ Last name + reverse nickname match: '\(player.name)' -> '\(calendarFirstName)'")
                                    matched = true
                                }
                            }
                            
                            if matched && !matchedPlayers.contains(where: { $0.id == player.id }) {
                                matchedPlayers.append(player)
                                break
                            }
                        }
                    } else {
                        // Try fuzzy last name matching for common spelling variations
                        // Check if last names are similar (e.g., "Schultz" vs "Shultz")
                        if areNamesSimilar(calendarLastName, playerLastName) {
                            // Last names are similar, check first names
                            if calendarFirstName == playerFirstName {
                                print("    ✅ Similar last name + first name match: '\(player.name)'")
                                if !matchedPlayers.contains(where: { $0.id == player.id }) {
                                    matchedPlayers.append(player)
                                    break
                                }
                            } else {
                                // Check nickname variations with similar last names
                                var matched = false
                                
                                if let nicknames = nicknameMap[playerFirstName] {
                                    if nicknames.contains(calendarFirstName) {
                                        print("    ✅ Similar last name + nickname match: '\(calendarFirstName)' -> '\(player.name)'")
                                        matched = true
                                    }
                                }
                                
                                if let calendarNicknames = nicknameMap[calendarFirstName] {
                                    if calendarNicknames.contains(playerFirstName) {
                                        print("    ✅ Similar last name + reverse nickname match: '\(player.name)' -> '\(calendarFirstName)'")
                                        matched = true
                                    }
                                }
                                
                                if matched && !matchedPlayers.contains(where: { $0.id == player.id }) {
                                    matchedPlayers.append(player)
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Check first name only (if no last name in calendar)
                if calendarLastName.isEmpty && calendarFirstName == playerFirstName {
                    print("    ✅ First name match: '\(player.name)'")
                    if !matchedPlayers.contains(where: { $0.id == player.id }) {
                        matchedPlayers.append(player)
                        break
                    }
                }
                
                // Check last name only
                if !calendarLastName.isEmpty && calendarLastName == playerLastName {
                    // If last name matches and calendar has both names, prefer full match
                    // But if calendar only has last name, this is a match
                    if calendarFirstName.isEmpty {
                        print("    ✅ Last name only match: '\(player.name)'")
                        if !matchedPlayers.contains(where: { $0.id == player.id }) {
                            matchedPlayers.append(player)
                            break
                        }
                    }
                }
            }
        }
        
        return matchedPlayers
    }
    
    /// Checks if two names are similar (handles common spelling variations)
    private func areNamesSimilar(_ name1: String, _ name2: String) -> Bool {
        let n1 = name1.lowercased()
        let n2 = name2.lowercased()
        
        // Exact match
        if n1 == n2 {
            return true
        }
        
        // Common spelling variations
        let variations: [(String, String)] = [
            ("schultz", "shultz"),
            ("smith", "smyth"),
            ("johnson", "johansen"),
            ("brown", "braun"),
            ("white", "whyte"),
            ("miller", "müller"),
        ]
        
        for (var1, var2) in variations {
            if (n1 == var1 && n2 == var2) || (n1 == var2 && n2 == var1) {
                return true
            }
        }
        
        // Check if names are very similar (one character difference, etc.)
        // Simple Levenshtein-like check for single character differences
        if abs(n1.count - n2.count) <= 1 {
            // Check if one string contains most of the other
            let longer = n1.count > n2.count ? n1 : n2
            let shorter = n1.count > n2.count ? n2 : n1
            
            // If the longer name starts with the shorter name, they're likely the same
            if longer.hasPrefix(shorter) || shorter.hasPrefix(longer) {
                return true
            }
            
            // Check for single character substitutions (common typos)
            var differences = 0
            let minLength = min(n1.count, n2.count)
            for i in 0..<minLength {
                let idx1 = n1.index(n1.startIndex, offsetBy: i)
                let idx2 = n2.index(n2.startIndex, offsetBy: i)
                if n1[idx1] != n2[idx2] {
                    differences += 1
                }
            }
            
            // Allow one character difference
            if differences <= 1 {
                return true
            }
        }
        
        return false
    }
    
    private func startGame() {
        let selectedPlayersArray = players.filter { selectedPlayers.contains($0.id) }
        
        // Use selected tee color, or default using priority: player preference > White > Green > first available
        let teeColorToUse: String? = {
            if let selectedTee = selectedTeeColor {
                return selectedTee
            }
            // Use computed default (already handles player preference > White > Green > first available)
            if let defaultTee = defaultTeeColor {
                return defaultTee
            }
            // Fallback: get tee using priority if defaultTeeColor is nil (shouldn't happen, but safe)
            if let course = selectedCourse,
               let holes = course.holes,
               let firstHole = holes.first,
               let teeDistances = firstHole.teeDistances {
                let teeColors = Set(teeDistances.map { $0.teeColor })
                if teeColors.contains("White") {
                    return "White"
                }
                if teeColors.contains("Green") {
                    return "Green"
                }
                return teeDistances.first?.teeColor
            }
            return nil
        }()
        
        // Use calendar event date if available, otherwise use current date/time
        let gameDate = calendarEventDate ?? Date()
        let newGame = Game(course: selectedCourse, players: selectedPlayersArray, selectedTeeColor: teeColorToUse, date: gameDate)
        
        // Only one game can be active at a time
        modelContext.insert(newGame)
        
        // Save the new game and update the selected game
        do {
            try modelContext.save()
            selectedGameIDString = newGame.id.uuidString
            currentHole = 1 // Reset to hole 1 for new game
            dismiss()
        } catch {
            print("Error saving game: \(error)")
        }
    }
}

#Preview {
    GameSetupView(selectedGameIDString: .constant(""), games: [])
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self], inMemory: true)
}

