//
//  CalendarImportView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/5/25.
//

import SwiftUI
import SwiftData
import EventKit

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var calendarManager = CalendarManager()
    @State private var golfEvents: [GolfCalendarEvent] = []
    @State private var hasSearched = false
    
    @Query private var courses: [GolfCourse]
    @Query private var players: [Player]
    
    @Binding var selectedGameIDString: String
    @AppStorage("currentHole") private var currentHole: Int = 1
    var onGameCreated: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            Group {
                switch calendarManager.authorizationStatus {
                case .notDetermined:
                    VStack(spacing: 20) {
                        Text("Calendar Access Required")
                            .font(.headline)
                        Text("This app needs access to your calendar to import golf game information.")
                        Button("Grant Access") {
                            Task {
                                await calendarManager.requestAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    
                case .denied, .restricted:
                    VStack(spacing: 20) {
                        Text("Calendar Access Denied")
                            .font(.headline)
                        Text("Please enable calendar access in Settings to import golf games.")
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    
                case .authorized, .fullAccess, .writeOnly:
                    if golfEvents.isEmpty && !calendarManager.isLoading && hasSearched {
                        VStack(spacing: 20) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No Golf Events Found")
                                .font(.headline)
                            Text("No golf events found for today or tomorrow.")
                            Button("Refresh") {
                                Task {
                                    await searchEvents()
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(calendarManager.isLoading)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(golfEvents) { event in
                                CalendarEventRow(
                                    event: event,
                                    courses: courses,
                                    players: players,
                                    onImport: { [self] course, selectedPlayers, trackingPlayerIDs in
                                        importGame(course: course, players: selectedPlayers, trackingPlayerIDs: trackingPlayerIDs, event: event)
                                    }
                                )
                            }
                        }
                        .refreshable {
                            await searchEvents()
                        }
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            .navigationTitle("Import from Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                if !hasSearched {
                    await searchEvents()
                    hasSearched = true
                }
            }
            .overlay {
                if calendarManager.isLoading {
                    ProgressView("Searching calendar...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func searchEvents() async {
        golfEvents = await calendarManager.searchGolfEvents()
    }
    
    func importGame(course: GolfCourse, players: [Player], trackingPlayerIDs: [UUID], event: GolfCalendarEvent) {
        // Use default tee color logic (same as GameSetupView)
        let defaultTeeColor: String? = {
            if let currentUser = players.first(where: { $0.isCurrentUser }),
               let preferredTee = currentUser.preferredTeeColor {
                let availableTeeColors = Set((course.holes ?? []).flatMap { ($0.teeDistances ?? []).map { $0.teeColor } })
                if availableTeeColors.contains(preferredTee) {
                    return preferredTee
                }
            }
            
            let availableTeeColors = Set((course.holes ?? []).flatMap { ($0.teeDistances ?? []).map { $0.teeColor } })
            if availableTeeColors.contains("White") {
                return "White"
            }
            if availableTeeColors.contains("Green") {
                return "Green"
            }
            return availableTeeColors.first
        }()
        
        // Default to current user if no tracking players specified
        let trackingPlayerIDsToUse: [UUID] = {
            if trackingPlayerIDs.isEmpty, let currentUser = players.first(where: { $0.isCurrentUser }) {
                return [currentUser.id]
            }
            return trackingPlayerIDs
        }()
        
        let newGame = Game(course: course, players: players, selectedTeeColor: defaultTeeColor, trackingPlayerIDs: trackingPlayerIDsToUse)
        
        modelContext.insert(newGame)
        
        do {
            try modelContext.save()
            selectedGameIDString = newGame.id.uuidString
            currentHole = 1
            // Dismiss the parent GameSetupView, which will also dismiss this view
            onGameCreated?()
        } catch {
            print("Error saving imported game: \(error)")
        }
    }
}

struct CalendarEventRow: View {
    let event: GolfCalendarEvent
    let courses: [GolfCourse]
    let players: [Player]
    let onImport: (GolfCourse, [Player], [UUID]) -> Void
    
    @State private var showingImportSheet = false
    @State private var matchedCourse: GolfCourse?
    @State private var matchedPlayers: [Player] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.courseName)
                .font(.headline)
            
            Text(event.startDate, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(event.startDate, style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !event.players.isEmpty {
                Text("Players: \(event.players.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let location = event.location {
                Text(location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button("Import Game") {
                // Match course and players before showing sheet
                matchCourseAndPlayers()
                // Small delay to ensure state is updated before sheet appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showingImportSheet = true
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingImportSheet) {
                                CalendarImportConfirmationView(
                event: event,
                matchedCourse: matchedCourse,
                matchedPlayers: matchedPlayers,
                allCourses: courses,
                allPlayers: players,
                onConfirm: { course, selectedPlayers, trackingPlayers in
                    onImport(course, selectedPlayers, trackingPlayers)
                    showingImportSheet = false
                },
                onCancel: {
                    showingImportSheet = false
                }
            )
        }
        .onChange(of: showingImportSheet) { oldValue, newValue in
            // Re-match when sheet is about to show
            if newValue && !oldValue {
                matchCourseAndPlayers()
            }
        }
    }
    
    private func matchCourseAndPlayers() {
        // Fuzzy match course
        print("🔍 Attempting to match course: '\(event.courseName)'")
        print("📋 Available courses: \(courses.map { $0.name })")
        matchedCourse = findMatchingCourse(event.courseName)
        if let matched = matchedCourse {
            print("✅ Matched calendar course '\(event.courseName)' to database course '\(matched.name)'")
        } else {
            print("❌ Could not match calendar course '\(event.courseName)' to any database course")
        }
        
        // Fuzzy match players - use the improved matching logic
        matchedPlayers = event.players.compactMap { name in
            let matched = findMatchingPlayer(name)
            if let matched = matched {
                print("✅ Matched calendar player '\(name)' to database player '\(matched.name)'")
            } else {
                print("❌ Could not match calendar player '\(name)' to any database player")
            }
            return matched
        }
    }
    
    private func findMatchingCourse(_ courseName: String) -> GolfCourse? {
        let searchName = courseName.lowercased().trimmingCharacters(in: .whitespaces)
        print("  🔍 Searching for course: '\(searchName)'")
        
        // Normalize by removing common words
        let normalizedSearch = searchName
            .replacingOccurrences(of: "golf at ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "golf ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        print("  📝 Normalized search: '\(normalizedSearch)'")
        
        // First try exact match
        if let exact = courses.first(where: { $0.name.lowercased() == searchName || $0.name.lowercased() == normalizedSearch }) {
            print("  ✅ Found exact match: '\(exact.name)'")
            return exact
        }
        
        // Try match without "The" prefix
        let searchWithoutThe = normalizedSearch.replacingOccurrences(of: "^the ", with: "", options: [.caseInsensitive, .regularExpression])
        print("  🔍 Trying without 'The': '\(searchWithoutThe)'")
        for course in courses {
            let courseNameLower = course.name.lowercased()
            let courseWithoutThe = courseNameLower.replacingOccurrences(of: "^the ", with: "", options: [.caseInsensitive, .regularExpression])
            
            if courseNameLower == normalizedSearch || courseWithoutThe == searchWithoutThe {
                print("  ✅ Found match without 'The': '\(course.name)'")
                return course
            }
        }
        
        // Try partial match (contains) - both directions
        if let partial = courses.first(where: { course in
            let courseNameLower = course.name.lowercased()
            let matches = courseNameLower.contains(normalizedSearch) || normalizedSearch.contains(courseNameLower)
            if matches {
                print("  ✅ Found partial match: '\(course.name)' contains or is contained by '\(normalizedSearch)'")
            }
            return matches
        }) {
            return partial
        }
        
        // Try partial match without "The" prefix
        if let partial = courses.first(where: { course in
            let courseNameLower = course.name.lowercased()
            let courseWithoutThe = courseNameLower.replacingOccurrences(of: "^the ", with: "", options: [.caseInsensitive, .regularExpression])
            let matches = courseWithoutThe.contains(searchWithoutThe) || searchWithoutThe.contains(courseWithoutThe)
            if matches {
                print("  ✅ Found partial match (no 'The'): '\(course.name)' matches '\(searchWithoutThe)'")
            }
            return matches
        }) {
            return partial
        }
        
        // Try keyword matching - match on significant words (ignore "the", "at", "club", "golf")
        let searchWords = normalizedSearch.components(separatedBy: .whitespaces)
            .filter { word in
                let lower = word.lowercased()
                return lower.count > 2 && !["the", "at", "club", "golf", "and"].contains(lower)
            }
        
        if !searchWords.isEmpty {
            // Find course that contains all significant words
            for course in courses {
                let courseNameLower = course.name.lowercased()
                let courseWords = courseNameLower.components(separatedBy: .whitespaces)
                    .filter { word in
                        let lower = word.lowercased()
                        return lower.count > 2 && !["the", "at", "club", "golf", "and"].contains(lower)
                    }
                
                // Check if all search words are found in course name
                let allWordsMatch = searchWords.allSatisfy { searchWord in
                    courseWords.contains { $0.contains(searchWord) || searchWord.contains($0) }
                }
                
                if allWordsMatch {
                    return course
                }
            }
        }
        
        // Try matching from location address if available
        if let location = event.location {
            let locationKeywords = location.lowercased().components(separatedBy: .whitespaces)
                .filter { $0.count > 3 && !["saint", "st", "street", "drive", "road", "avenue", "ave", "dr", "rd"].contains($0.lowercased()) }
            
            for keyword in locationKeywords {
                if let match = courses.first(where: { course in
                    let courseNameLower = course.name.lowercased()
                    return courseNameLower.contains(keyword) || (course.location?.lowercased().contains(keyword) ?? false)
                }) {
                    return match
                }
            }
        }
        
        return nil
    }
    
    private func findMatchingPlayer(_ name: String) -> Player? {
        let searchName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let nameParts = searchName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Try exact match first (case-insensitive, trimmed)
        if let exact = players.first(where: { $0.name.lowercased().trimmingCharacters(in: .whitespaces) == searchName }) {
            return exact
        }
        
        // Try matching by last name (most reliable) - check if last name matches
        if nameParts.count >= 2 {
            let lastName = nameParts.last!.lowercased()
            if let match = players.first(where: { player in
                let playerNameLower = player.name.lowercased().trimmingCharacters(in: .whitespaces)
                let playerParts = playerNameLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                // Check if last names match exactly
                if let playerLastName = playerParts.last, playerLastName == lastName {
                    return true
                }
                // Also check if any part of player name contains the last name
                return playerParts.contains(lastName)
            }) {
                return match
            }
        }
        
        // Try matching by first name with nickname variations
        if let firstName = nameParts.first {
            // Comprehensive nickname map - each key maps to all possible variations
            let nicknameMap: [String: [String]] = [
                "dave": ["david", "dave", "davey"],
                "david": ["david", "dave", "davey"],
                "dan": ["daniel", "dan", "danny"],
                "daniel": ["daniel", "dan", "danny"],
                "danny": ["daniel", "dan", "danny"],
                "bob": ["robert", "bob", "bobby", "rob"],
                "robert": ["robert", "bob", "bobby", "rob"],
                "rob": ["robert", "bob", "bobby", "rob"],
                "bill": ["william", "bill", "billy", "will"],
                "william": ["william", "bill", "billy", "will"],
                "will": ["william", "bill", "billy", "will"],
                "jim": ["james", "jim", "jimmy", "jamie"],
                "james": ["james", "jim", "jimmy", "jamie"],
                "jimmy": ["james", "jim", "jimmy", "jamie"],
                "mike": ["michael", "mike", "mikey", "mick"],
                "michael": ["michael", "mike", "mikey", "mick"],
                "mikey": ["michael", "mike", "mikey", "mick"],
                "tom": ["thomas", "tom", "tommy"],
                "thomas": ["thomas", "tom", "tommy"],
                "tommy": ["thomas", "tom", "tommy"],
                "chris": ["christopher", "chris", "christy"],
                "christopher": ["christopher", "chris", "christy"],
                "steve": ["steven", "stephen", "steve", "stevie"],
                "steven": ["steven", "stephen", "steve", "stevie"],
                "stephen": ["steven", "stephen", "steve", "stevie"],
                "rick": ["richard", "rick", "ricky", "dick"],
                "richard": ["richard", "rick", "ricky", "dick"],
                "ricky": ["richard", "rick", "ricky", "dick"],
                "john": ["john", "jon", "jonathan", "johnny"],
                "jon": ["john", "jon", "jonathan", "johnny"],
                "jonathan": ["john", "jon", "jonathan", "johnny"]
            ]
            
            let normalizedFirstName = firstName.lowercased()
            var possibleNames = Set<String>()
            possibleNames.insert(normalizedFirstName)
            
            // Find all variations for this first name
            // Check if the name itself is a key
            if let variants = nicknameMap[normalizedFirstName] {
                possibleNames.formUnion(variants)
            }
            
            // Also check if it's in any of the variant lists
            for (key, variants) in nicknameMap {
                if variants.contains(normalizedFirstName) {
                    possibleNames.formUnion(variants)
                    possibleNames.insert(key) // Also add the key itself
                }
            }
            
            // Try matching with any of the possible first name variations
            // If we have a last name, require it to match too
            if nameParts.count >= 2 {
                let lastName = nameParts.last!.lowercased()
                if let match = players.first(where: { player in
                    let playerNameLower = player.name.lowercased().trimmingCharacters(in: .whitespaces)
                    let playerParts = playerNameLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard let playerFirstName = playerParts.first, let playerLastName = playerParts.last else { return false }
                    
                    // First name must match (with nickname variations) - check both directions
                    let firstNameMatches = possibleNames.contains(playerFirstName) || {
                        // Also check if player's first name has variations that match
                        var playerPossibleNames = Set<String>()
                        playerPossibleNames.insert(playerFirstName)
                        if let playerVariants = nicknameMap[playerFirstName] {
                            playerPossibleNames.formUnion(playerVariants)
                        }
                        for (key, variants) in nicknameMap {
                            if variants.contains(playerFirstName) {
                                playerPossibleNames.formUnion(variants)
                                playerPossibleNames.insert(key)
                            }
                        }
                        return playerPossibleNames.contains(normalizedFirstName)
                    }()
                    // Last name must match
                    let lastNameMatches = playerLastName == lastName
                    
                    return firstNameMatches && lastNameMatches
                }) {
                    return match
                }
            } else {
                // Only first name provided - match on first name only
                if let match = players.first(where: { player in
                    let playerNameLower = player.name.lowercased().trimmingCharacters(in: .whitespaces)
                    let playerParts = playerNameLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if let playerFirstName = playerParts.first {
                        return possibleNames.contains(playerFirstName)
                    }
                    return false
                }) {
                    return match
                }
            }
        }
        
        // Try partial match on full name - check if search name is contained in player name or vice versa
        if let partial = players.first(where: { player in
            let playerNameLower = player.name.lowercased().trimmingCharacters(in: .whitespaces)
            return playerNameLower.contains(searchName) || searchName.contains(playerNameLower)
        }) {
            return partial
        }
        
        // Try word-by-word matching - if all words in search name appear in player name
        let searchWords = nameParts.filter { $0.count > 2 } // Ignore very short words
        if searchWords.count >= 2 {
            if let match = players.first(where: { player in
                let playerNameLower = player.name.lowercased().trimmingCharacters(in: .whitespaces)
                let playerWords = playerNameLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty && $0.count > 2 }
                
                // Check if all significant search words are found in player name
                return searchWords.allSatisfy { searchWord in
                    playerWords.contains { $0 == searchWord || $0.contains(searchWord) || searchWord.contains($0) }
                }
            }) {
                return match
            }
        }
        
        return nil
    }
}

struct CalendarImportConfirmationView: View {
    let event: GolfCalendarEvent
    let matchedCourse: GolfCourse?
    let matchedPlayers: [Player]
    let allCourses: [GolfCourse]
    let allPlayers: [Player]
    let onConfirm: (GolfCourse, [Player], [UUID]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedCourse: GolfCourse?
    @State private var selectedPlayers: Set<UUID> = []
    @State private var trackingPlayers: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section("Course") {
                    if let matched = matchedCourse {
                        HStack {
                            Text("Matched:")
                            Spacer()
                            Text(matched.name)
                                .foregroundColor(.secondary)
                        }
                        // Automatically set the matched course immediately
                        .onAppear {
                            selectedCourse = matched
                        }
                    } else {
                        Text("No course match found for: \(event.courseName)")
                            .foregroundColor(.orange)
                    }
                    
                    Picker("Select Course", selection: $selectedCourse) {
                        Text("None").tag(nil as GolfCourse?)
                        ForEach(allCourses) { course in
                            Text(course.name).tag(course as GolfCourse?)
                        }
                    }
                }
                
                Section("Players") {
                    ForEach(event.players, id: \.self) { eventPlayerName in
                        HStack {
                            Text(eventPlayerName)
                            Spacer()
                            if let matched = findMatchedPlayer(for: eventPlayerName) {
                                Text("→ \(matched.name)")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .onAppear {
                                        selectedPlayers.insert(matched.id)
                                    }
                            } else {
                                Text("No match")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Text("Select players for this game:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(allPlayers) { player in
                        Button {
                            if selectedPlayers.contains(player.id) {
                                selectedPlayers.remove(player.id)
                                // Also remove from tracking if deselected
                                trackingPlayers.remove(player.id)
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
                
                // Shot Tracking section (only show when players are selected)
                if !selectedPlayers.isEmpty {
                    Section("Shot Tracking") {
                        Text("Select which players will track their shots. Other players' scores can be entered manually on the scorecard.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(allPlayers.filter { selectedPlayers.contains($0.id) }) { player in
                            Button {
                                if trackingPlayers.contains(player.id) {
                                    trackingPlayers.remove(player.id)
                                } else {
                                    trackingPlayers.insert(player.id)
                                }
                            } label: {
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    if trackingPlayers.contains(player.id) {
                                        Image(systemName: "target")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "target")
                                            .foregroundColor(.gray.opacity(0.3))
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                
                Section("Event Details") {
                    HStack {
                        Text("Date:")
                        Spacer()
                        Text(event.startDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Time:")
                        Spacer()
                        Text(event.startDate, style: .time)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Confirm Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Create Game") {
                    if let course = selectedCourse {
                        let playersArray = allPlayers.filter { selectedPlayers.contains($0.id) }
                        let trackingPlayerIDsArray = Array(trackingPlayers)
                        onConfirm(course, playersArray, trackingPlayerIDsArray)
                    }
                }
                .disabled(selectedCourse == nil || selectedPlayers.isEmpty)
            )
            .onAppear {
                // Set matched course if available - do this immediately
                if let matched = matchedCourse {
                    selectedCourse = matched
                }
                
                // Pre-select matched players
                for player in matchedPlayers {
                    selectedPlayers.insert(player.id)
                }
                
                // Also try to match any players that weren't automatically matched
                for eventPlayerName in event.players {
                    if let matched = findMatchedPlayer(for: eventPlayerName), !selectedPlayers.contains(matched.id) {
                        selectedPlayers.insert(matched.id)
                    }
                }
                
                // Default tracking players to current user if available
                if trackingPlayers.isEmpty, let currentUser = allPlayers.first(where: { $0.isCurrentUser }), selectedPlayers.contains(currentUser.id) {
                    trackingPlayers.insert(currentUser.id)
                }
            }
            .onChange(of: matchedCourse) { oldValue, newValue in
                // Update selected course when matched course changes
                if let matched = newValue, selectedCourse == nil {
                    selectedCourse = matched
                }
            }
            .onChange(of: matchedPlayers) { oldValue, newValue in
                // Update selected players when matched players change
                for player in newValue {
                    selectedPlayers.insert(player.id)
                }
            }
            .onChange(of: selectedPlayers) { oldValue, newValue in
                // When players are selected, default tracking to current user if available
                if trackingPlayers.isEmpty, let currentUser = allPlayers.first(where: { $0.isCurrentUser }), newValue.contains(currentUser.id) {
                    trackingPlayers.insert(currentUser.id)
                }
                // Remove tracking for players who are no longer selected
                trackingPlayers = trackingPlayers.filter { newValue.contains($0) }
            }
        }
    }
    
    // Helper function to find matched player using the same logic as CalendarEventRow
    func findMatchedPlayer(for eventPlayerName: String) -> Player? {
        // First check if it's in the matchedPlayers array
        if let matched = matchedPlayers.first(where: { player in
            // Use the same matching logic
            let searchName = eventPlayerName.lowercased().trimmingCharacters(in: .whitespaces)
            let playerName = player.name.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Exact match
            if playerName == searchName {
                return true
            }
            
            // Check if names contain each other
            if playerName.contains(searchName) || searchName.contains(playerName) {
                return true
            }
            
            // Check word-by-word
            let searchParts = searchName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let playerParts = playerName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if searchParts.count >= 2 && playerParts.count >= 2 {
                // Check if last names match
                if searchParts.last == playerParts.last {
                    // Check first name with nickname variations
                    let nicknameMap: [String: [String]] = [
                        "dan": ["daniel", "dan", "danny"],
                        "daniel": ["daniel", "dan", "danny"],
                        "danny": ["daniel", "dan", "danny"],
                        "dave": ["david", "dave", "davey"],
                        "david": ["david", "dave", "davey"],
                        "mike": ["michael", "mike", "mikey"],
                        "michael": ["michael", "mike", "mikey"]
                    ]
                    
                    let searchFirstName = searchParts.first!.lowercased()
                    let playerFirstName = playerParts.first!.lowercased()
                    
                    var searchVariants = Set<String>([searchFirstName])
                    if let variants = nicknameMap[searchFirstName] {
                        searchVariants.formUnion(variants)
                    }
                    for (key, variants) in nicknameMap {
                        if variants.contains(searchFirstName) {
                            searchVariants.formUnion(variants)
                            searchVariants.insert(key)
                        }
                    }
                    
                    return searchVariants.contains(playerFirstName)
                }
            }
            
            return false
        }) {
            return matched
        }
        
        // If not in matchedPlayers, try to find it using the same logic
        return findMatchingPlayerInList(eventPlayerName)
    }
    
    func findMatchingPlayerInList(_ name: String) -> Player? {
        let searchName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let nameParts = searchName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Exact match
        if let exact = allPlayers.first(where: { $0.name.lowercased().trimmingCharacters(in: .whitespaces) == searchName }) {
            return exact
        }
        
        // Last name match
        if nameParts.count >= 2 {
            let lastName = nameParts.last!.lowercased()
            if let match = allPlayers.first(where: { player in
                let playerParts = player.name.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                return playerParts.last == lastName
            }) {
                return match
            }
        }
        
        // First name + last name with nicknames
        if nameParts.count >= 2, let firstName = nameParts.first {
            let lastName = nameParts.last!.lowercased()
            let nicknameMap: [String: [String]] = [
                "dan": ["daniel", "dan", "danny"],
                "daniel": ["daniel", "dan", "danny"],
                "danny": ["daniel", "dan", "danny"],
                "dave": ["david", "dave", "davey"],
                "david": ["david", "dave", "davey"],
                "mike": ["michael", "mike", "mikey"],
                "michael": ["michael", "mike", "mikey"]
            ]
            
            let normalizedFirstName = firstName.lowercased()
            var possibleNames = Set<String>([normalizedFirstName])
            if let variants = nicknameMap[normalizedFirstName] {
                possibleNames.formUnion(variants)
            }
            for (key, variants) in nicknameMap {
                if variants.contains(normalizedFirstName) {
                    possibleNames.formUnion(variants)
                    possibleNames.insert(key)
                }
            }
            
            if let match = allPlayers.first(where: { player in
                let playerParts = player.name.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard let playerFirstName = playerParts.first, let playerLastName = playerParts.last else { return false }
                
                let firstNameMatches = possibleNames.contains(playerFirstName) || {
                    var playerPossibleNames = Set<String>([playerFirstName])
                    if let playerVariants = nicknameMap[playerFirstName] {
                        playerPossibleNames.formUnion(playerVariants)
                    }
                    for (key, variants) in nicknameMap {
                        if variants.contains(playerFirstName) {
                            playerPossibleNames.formUnion(variants)
                            playerPossibleNames.insert(key)
                        }
                    }
                    return playerPossibleNames.contains(normalizedFirstName)
                }()
                
                return firstNameMatches && playerLastName == lastName
            }) {
                return match
            }
        }
        
        return nil
    }
}

