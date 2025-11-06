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
                    
                case .authorized:
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
                                    onImport: { [self] course, selectedPlayers in
                                        importGame(course: course, players: selectedPlayers, event: event)
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
    
    func importGame(course: GolfCourse, players: [Player], event: GolfCalendarEvent) {
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
        
        let newGame = Game(course: course, players: players, selectedTeeColor: defaultTeeColor)
        
        modelContext.insert(newGame)
        
        do {
            try modelContext.save()
            selectedGameIDString = newGame.id.uuidString
            currentHole = 1
            dismiss()
        } catch {
            print("Error saving imported game: \(error)")
        }
    }
}

struct CalendarEventRow: View {
    let event: GolfCalendarEvent
    let courses: [GolfCourse]
    let players: [Player]
    let onImport: (GolfCourse, [Player]) -> Void
    
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
                matchCourseAndPlayers()
                showingImportSheet = true
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
                onConfirm: { course, selectedPlayers in
                    onImport(course, selectedPlayers)
                    showingImportSheet = false
                },
                onCancel: {
                    showingImportSheet = false
                }
            )
        }
    }
    
    private func matchCourseAndPlayers() {
        // Fuzzy match course
        matchedCourse = findMatchingCourse(event.courseName)
        
        // Fuzzy match players
        matchedPlayers = event.players.compactMap { name in
            findMatchingPlayer(name)
        }
    }
    
    private func findMatchingCourse(_ courseName: String) -> GolfCourse? {
        let searchName = courseName.lowercased()
        
        // First try exact match
        if let exact = courses.first(where: { $0.name.lowercased() == searchName }) {
            return exact
        }
        
        // Try partial match (contains)
        if let partial = courses.first(where: { $0.name.lowercased().contains(searchName) || searchName.contains($0.name.lowercased()) }) {
            return partial
        }
        
        // Try keyword matching (e.g., "Amelia River Club" matches "The Amelia River Club")
        let keywords = searchName.components(separatedBy: .whitespaces).filter { $0.count > 3 }
        for keyword in keywords {
            if let match = courses.first(where: { $0.name.lowercased().contains(keyword) }) {
                return match
            }
        }
        
        // Try matching from location address if available
        if let location = event.location {
            let locationKeywords = location.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 }
            for keyword in locationKeywords {
                if let match = courses.first(where: { $0.name.lowercased().contains(keyword) }) {
                    return match
                }
            }
        }
        
        return nil
    }
    
    private func findMatchingPlayer(_ name: String) -> Player? {
        let searchName = name.lowercased().trimmingCharacters(in: .whitespaces)
        let nameParts = searchName.components(separatedBy: .whitespaces)
        
        // Try exact match first
        if let exact = players.first(where: { $0.name.lowercased() == searchName }) {
            return exact
        }
        
        // Try matching by last name (most reliable)
        if nameParts.count >= 2 {
            let lastName = nameParts.last!
            if let match = players.first(where: { player in
                let playerParts = player.name.lowercased().components(separatedBy: .whitespaces)
                return playerParts.contains(lastName)
            }) {
                return match
            }
        }
        
        // Try fuzzy first name matching (Dave/David, Dan/Daniel, etc.)
        if let firstName = nameParts.first {
            let nicknameMap: [String: [String]] = [
                "dave": ["david", "dave"],
                "dan": ["daniel", "dan", "danny"],
                "bob": ["robert", "bob"],
                "bill": ["william", "bill"],
                "jim": ["james", "jim", "jimmy"],
                "mike": ["michael", "mike"],
                "tom": ["thomas", "tom"],
                "chris": ["christopher", "chris"],
                "steve": ["steven", "stephen", "steve"],
                "rick": ["richard", "rick", "ricky"]
            ]
            
            let normalizedFirstName = firstName.lowercased()
            var possibleNames = [normalizedFirstName]
            
            // Add nickname variations
            for (nickname, variants) in nicknameMap {
                if variants.contains(normalizedFirstName) {
                    possibleNames.append(contentsOf: variants)
                }
            }
            
            // Try matching with any of the possible first name variations
            if let match = players.first(where: { player in
                let playerParts = player.name.lowercased().components(separatedBy: .whitespaces)
                if let playerFirstName = playerParts.first {
                    return possibleNames.contains(playerFirstName)
                }
                return false
            }) {
                return match
            }
        }
        
        // Try partial match on full name
        if let partial = players.first(where: { $0.name.lowercased().contains(searchName) || searchName.contains($0.name.lowercased()) }) {
            return partial
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
    let onConfirm: (GolfCourse, [Player]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedCourse: GolfCourse?
    @State private var selectedPlayers: Set<UUID> = []
    
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
                            if let matched = matchedPlayers.first(where: { player in
                                let playerName = player.name.lowercased()
                                let eventName = eventPlayerName.lowercased()
                                return playerName.contains(eventName) || eventName.contains(playerName)
                            }) {
                                Text("→ \(matched.name)")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .onAppear {
                                        if !selectedPlayers.contains(matched.id) {
                                            selectedPlayers.insert(matched.id)
                                        }
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
                        onConfirm(course, playersArray)
                    }
                }
                .disabled(selectedCourse == nil || selectedPlayers.isEmpty)
            )
            .onAppear {
                // Set matched course if available
                if let matched = matchedCourse {
                    selectedCourse = matched
                }
                // Pre-select matched players
                for player in matchedPlayers {
                    selectedPlayers.insert(player.id)
                }
            }
        }
    }
}

