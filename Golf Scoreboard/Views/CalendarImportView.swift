//
//  CalendarImportView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData
import EventKit

struct CalendarImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calendarManager = CalendarManager()
    
    @Query private var players: [Player]
    @Query private var courses: [GolfCourse]
    
    @Binding var selectedGameIDString: String
    let games: [Game]
    
    @AppStorage("currentHole") private var currentHole: Int = 1
    @State private var selectedEvent: CalendarGolfEvent?
    @State private var showingImportConfirmation = false
    @State private var matchedPlayers: [Player] = []
    @State private var matchedCourse: GolfCourse?
    @State private var unmatchedPlayerNames: [String] = []
    @State private var unmatchedCourseName: String?
    @State private var hasSearched = false
    
    var body: some View {
        NavigationView {
            Group {
                if calendarManager.isLoading {
                    ProgressView("Searching calendar...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if calendarManager.authorizationStatus == .denied || calendarManager.authorizationStatus == .restricted {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Calendar Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please enable calendar access in Settings to import golf events.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if calendarManager.events.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "calendar")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Golf Events Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let errorMessage = calendarManager.errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("No golf events found in the next 2 days.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button("Refresh") {
                            guard !calendarManager.isLoading else { return }
                            Task {
                                await calendarManager.searchGolfEvents()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(calendarManager.isLoading)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(Array(calendarManager.events.enumerated()), id: \.element.event.eventIdentifier) { index, golfEvent in
                            EventRow(
                                golfEvent: golfEvent,
                                isSelected: selectedEvent?.event.eventIdentifier == golfEvent.event.eventIdentifier,
                                players: players,
                                courses: courses
                            ) {
                                selectedEvent = golfEvent
                                matchEventToAppData(golfEvent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import from Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if calendarManager.authorizationStatus == .notDetermined {
                        Button("Allow Access") {
                            Task {
                                await calendarManager.requestAccess()
                                await calendarManager.searchGolfEvents()
                            }
                        }
                    } else if !calendarManager.events.isEmpty {
                        Button("Refresh") {
                            guard !calendarManager.isLoading else { return }
                            Task {
                                await calendarManager.searchGolfEvents()
                            }
                        }
                        .disabled(calendarManager.isLoading)
                    }
                }
            }
            .onAppear {
                // Only search once when view first appears and we have authorization
                if !hasSearched && calendarManager.authorizationStatus == .authorized {
                    hasSearched = true
                    Task {
                        await calendarManager.searchGolfEvents()
                    }
                }
            }
            .sheet(isPresented: $showingImportConfirmation) {
                ImportConfirmationView(
                    golfEvent: selectedEvent,
                    matchedPlayers: matchedPlayers,
                    matchedCourse: matchedCourse,
                    unmatchedPlayerNames: unmatchedPlayerNames,
                    unmatchedCourseName: unmatchedCourseName,
                    players: players,
                    courses: courses,
                    onConfirm: { course, selectedPlayers in
                        createGameFromEvent(course: course, players: selectedPlayers, date: selectedEvent?.date ?? Date())
                    },
                    onCancel: {
                        showingImportConfirmation = false
                    }
                )
            }
        }
    }
    
    private func matchEventToAppData(_ golfEvent: CalendarGolfEvent) {
        // Helper function to check if first names are variations of each other
        func areFirstNameVariations(firstName1: String, firstName2: String) -> Bool {
            let variations: [String: [String]] = [
                "daniel": ["dan"],
                "dan": ["daniel"],
                "david": ["dave", "davey"],
                "dave": ["david", "davey"],
                "davey": ["david", "dave"],
                "michael": ["mike", "mikey"],
                "mike": ["michael", "mikey"],
                "mikey": ["michael", "mike"],
                "robert": ["bob", "rob", "robby"],
                "bob": ["robert", "rob", "robby"],
                "rob": ["robert", "bob", "robby"],
                "robby": ["robert", "bob", "rob"],
                "william": ["will", "bill", "billy"],
                "will": ["william", "bill", "billy"],
                "bill": ["william", "will", "billy"],
                "billy": ["william", "will", "bill"],
                "richard": ["rick", "rich", "dick"],
                "rick": ["richard", "rich", "dick"],
                "rich": ["richard", "rick", "dick"],
                "dick": ["richard", "rick", "rich"],
                "james": ["jim", "jimmy", "jamie"],
                "jim": ["james", "jimmy", "jamie"],
                "jimmy": ["james", "jim", "jamie"],
                "jamie": ["james", "jim", "jimmy"],
                "thomas": ["tom", "tommy"],
                "tom": ["thomas", "tommy"],
                "tommy": ["thomas", "tom"],
                "joseph": ["joe", "joey"],
                "joe": ["joseph", "joey"],
                "joey": ["joseph", "joe"],
                "christopher": ["chris"],
                "chris": ["christopher"],
                "matthew": ["matt"],
                "matt": ["matthew"],
                "andrew": ["andy", "drew"],
                "andy": ["andrew", "drew"],
                "drew": ["andrew", "andy"]
            ]
            
            if let var1 = variations[firstName1]?.contains(firstName2), var1 {
                return true
            }
            if let var2 = variations[firstName2]?.contains(firstName1), var2 {
                return true
            }
            return false
        }
        
        // Match players
        var matched: [Player] = []
        var unmatched: [String] = []
        
        for playerName in golfEvent.playerNames {
            var found = false
            
            // Try to match player names with improved fuzzy matching
            let nameLower = playerName.lowercased().trimmingCharacters(in: .whitespaces)
            let calendarNameParts = nameLower.components(separatedBy: " ").filter { !$0.isEmpty }
            let calendarFirstName = calendarNameParts.first ?? ""
            let calendarLastName = calendarNameParts.count > 1 ? calendarNameParts.last! : ""
            
            for player in players {
                let playerNameLower = player.name.lowercased()
                let playerNameParts = playerNameLower.components(separatedBy: " ").filter { !$0.isEmpty }
                let playerFirstName = playerNameParts.first ?? ""
                let playerLastName = playerNameParts.count > 1 ? playerNameParts.last! : ""
                
                // Exact match
                if playerNameLower == nameLower {
                    if !matched.contains(where: { $0.id == player.id }) {
                        matched.append(player)
                        found = true
                        break
                    }
                }
                
                // Match on last name (most reliable)
                if !calendarLastName.isEmpty && !playerLastName.isEmpty && calendarLastName == playerLastName {
                    // Last names match - check first name variations
                    if calendarFirstName == playerFirstName {
                        // Exact first name match
                        if !matched.contains(where: { $0.id == player.id }) {
                            matched.append(player)
                            found = true
                            break
                        }
                    } else if areFirstNameVariations(firstName1: calendarFirstName, firstName2: playerFirstName) {
                        // First names are variations (e.g., Daniel/Dan, David/Dave)
                        if !matched.contains(where: { $0.id == player.id }) {
                            matched.append(player)
                            found = true
                            break
                        }
                    } else if calendarFirstName.isEmpty || playerFirstName.isEmpty {
                        // One first name is missing, but last names match
                        if !matched.contains(where: { $0.id == player.id }) {
                            matched.append(player)
                            found = true
                            break
                        }
                    }
                }
                
                // First name match only (if last names are missing or don't match)
                if !calendarFirstName.isEmpty && !playerFirstName.isEmpty {
                    if calendarFirstName == playerFirstName {
                        // First names match - check if last names match or are missing
                        if calendarLastName.isEmpty || playerLastName.isEmpty || calendarLastName == playerLastName {
                            if !matched.contains(where: { $0.id == player.id }) {
                                matched.append(player)
                                found = true
                                break
                            }
                        }
                    } else if areFirstNameVariations(firstName1: calendarFirstName, firstName2: playerFirstName) {
                        // First names are variations
                        if calendarLastName.isEmpty || playerLastName.isEmpty || calendarLastName == playerLastName {
                            if !matched.contains(where: { $0.id == player.id }) {
                                matched.append(player)
                                found = true
                                break
                            }
                        }
                    }
                }
            }
            
            if !found {
                unmatched.append(playerName)
            }
        }
        
        matchedPlayers = matched
        unmatchedPlayerNames = unmatched
        
        // Match course
        matchedCourse = nil
        unmatchedCourseName = nil
        
        if let courseName = golfEvent.courseName {
            // Use improved matching logic that handles addresses
            let courseNameLower = courseName.lowercased()
            
            // Extract key words from location (could be an address)
            // Remove common address words and numbers
            let addressWordsToRemove = ["street", "st", "avenue", "ave", "road", "rd", "drive", "dr", "lane", "ln", "boulevard", "blvd", "way", "court", "ct", "circle", "cir", "place", "pl"]
            let searchWords = courseNameLower.components(separatedBy: CharacterSet(charactersIn: " ,\n\t"))
                .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet.decimalDigits) }
                .filter { !$0.isEmpty && $0.count > 2 && !addressWordsToRemove.contains($0) }
            
            for course in courses {
                let courseNameLower_db = course.name.lowercased()
                
                // Direct match
                if courseNameLower_db == courseNameLower {
                    matchedCourse = course
                    break
                }
                
                // Contains match (bidirectional)
                if courseNameLower_db.contains(courseNameLower) || courseNameLower.contains(courseNameLower_db) {
                    matchedCourse = course
                    break
                }
                
                // Extract key words from course name
                let courseWords = courseNameLower_db.components(separatedBy: " ").filter {
                    !["the", "at", "club", "golf", "and", "of", "on"].contains($0) && $0.count > 2
                }
                
                // Match if any significant word from location appears in course name
                var significantMatches = 0
                for searchWord in searchWords {
                    // Check if this word appears in course name
                    if courseNameLower_db.contains(searchWord) {
                        significantMatches += 1
                    } else {
                        // Check if any course word contains or is contained by the search word
                        for courseWord in courseWords {
                            if courseWord == searchWord || courseWord.contains(searchWord) || searchWord.contains(courseWord) {
                                significantMatches += 1
                                break
                            }
                        }
                    }
                }
                
                // If we found at least one significant match, consider it a match
                // This handles cases like "1 Osprey Dr" matching "The Club at Osprey Cove"
                if significantMatches > 0 {
                    matchedCourse = course
                    break
                }
                
                // Key word matching (all words must match)
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
                    matchedCourse = course
                    break
                }
            }
            
            if matchedCourse == nil {
                unmatchedCourseName = courseName
            }
        }
        
        showingImportConfirmation = true
    }
    
    private func createGameFromEvent(course: GolfCourse?, players: [Player], date: Date) {
        // Determine tee color (use default logic from GameSetupView)
        let teeColorToUse: String? = {
            if let course = course,
               let holes = course.holes,
               let firstHole = holes.first,
               let teeDistances = firstHole.teeDistances {
                let teeColors = Set(teeDistances.map { $0.teeColor })
                
                // Try player preference first
                if let currentUser = players.first(where: { $0.isCurrentUser }),
                   let preferredTee = currentUser.preferredTeeColor,
                   teeColors.contains(preferredTee) {
                    return preferredTee
                }
                
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
        
        let newGame = Game(course: course, players: players, selectedTeeColor: teeColorToUse)
        newGame.date = date
        
        modelContext.insert(newGame)
        
        do {
            try modelContext.save()
            selectedGameIDString = newGame.id.uuidString
            currentHole = 1
            dismiss()
        } catch {
            print("Error creating game from calendar: \(error)")
        }
    }
}

struct EventRow: View {
    let golfEvent: CalendarGolfEvent
    let isSelected: Bool
    let players: [Player]
    let courses: [GolfCourse]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Date and time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text(golfEvent.date, style: .date)
                        .font(.headline)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(golfEvent.date, style: .time)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Course name
                if let courseName = golfEvent.courseName {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text(courseName)
                            .font(.subheadline)
                    }
                } else {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundColor(.orange)
                        Text("No course location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Players
                if !golfEvent.playerNames.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(golfEvent.playerNames, id: \.self) { name in
                                Text(name)
                                    .font(.subheadline)
                            }
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "person.slash")
                            .foregroundColor(.orange)
                        Text("No players found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct ImportConfirmationView: View {
    let golfEvent: CalendarGolfEvent?
    let matchedPlayers: [Player]
    let matchedCourse: GolfCourse?
    let unmatchedPlayerNames: [String]
    let unmatchedCourseName: String?
    let players: [Player]
    let courses: [GolfCourse]
    let onConfirm: (GolfCourse?, [Player]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedPlayers: Set<UUID>
    @State private var selectedCourse: GolfCourse?
    
    init(
        golfEvent: CalendarGolfEvent?,
        matchedPlayers: [Player],
        matchedCourse: GolfCourse?,
        unmatchedPlayerNames: [String],
        unmatchedCourseName: String?,
        players: [Player],
        courses: [GolfCourse],
        onConfirm: @escaping (GolfCourse?, [Player]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.golfEvent = golfEvent
        self.matchedPlayers = matchedPlayers
        self.matchedCourse = matchedCourse
        self.unmatchedPlayerNames = unmatchedPlayerNames
        self.unmatchedCourseName = unmatchedCourseName
        self.players = players
        self.courses = courses
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        _selectedPlayers = State(initialValue: Set(matchedPlayers.map { $0.id }))
        _selectedCourse = State(initialValue: matchedCourse)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let event = golfEvent {
                    Section("Event Details") {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(event.date, style: .date)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(event.date, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Players") {
                    if matchedPlayers.isEmpty && unmatchedPlayerNames.isEmpty {
                        Text("No players found in calendar event")
                            .foregroundColor(.secondary)
                    } else {
                        // Show matched players (pre-selected)
                        if !matchedPlayers.isEmpty {
                            ForEach(matchedPlayers) { player in
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
                        
                        // Show unmatched player names
                        if !unmatchedPlayerNames.isEmpty {
                            ForEach(unmatchedPlayerNames, id: \.self) { name in
                                HStack {
                                    Text(name)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Not found")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                
                Section("Course") {
                    if matchedCourse != nil {
                        Picker("Course", selection: $selectedCourse) {
                            Text("None").tag(nil as GolfCourse?)
                            ForEach(courses) { course in
                                Text(course.name).tag(course as GolfCourse?)
                            }
                        }
                    } else if let unmatchedCourse = unmatchedCourseName {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Course not found:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(unmatchedCourse)
                                .foregroundColor(.orange)
                            
                            Picker("Select Course", selection: $selectedCourse) {
                                Text("None").tag(nil as GolfCourse?)
                                ForEach(courses) { course in
                                    Text(course.name).tag(course as GolfCourse?)
                                }
                            }
                        }
                    } else {
                        Text("No course location found")
                            .foregroundColor(.secondary)
                        
                        Picker("Select Course", selection: $selectedCourse) {
                            Text("None").tag(nil as GolfCourse?)
                            ForEach(courses) { course in
                                Text(course.name).tag(course as GolfCourse?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Confirm Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Game") {
                        let selectedPlayersArray = players.filter { selectedPlayers.contains($0.id) }
                        onConfirm(selectedCourse, selectedPlayersArray)
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CalendarImportView(selectedGameIDString: .constant(""), games: [])
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self], inMemory: true)
}

