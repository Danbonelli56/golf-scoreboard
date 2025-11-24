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
    @State private var trackingPlayers: Set<UUID> = []
    @State private var selectedTeeColor: String? = nil
    @State private var selectedGameFormat: String = "stroke"
    @State private var team1Players: Set<UUID> = []
    @State private var team2Players: Set<UUID> = []
    @State private var team1Name: String = "Team 1"
    @State private var team2Name: String = "Team 2"
    @State private var showingTeamValidationAlert = false
    @State private var teamValidationMessage = ""
    
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
                Section("Quick Import") {
                    NavigationLink {
                        CalendarImportView(
                            selectedGameIDString: $selectedGameIDString,
                            onGameCreated: {
                                // Dismiss this view when a game is created from calendar
                                dismiss()
                            }
                        )
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Import from Calendar")
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
                
                Section("Game Format") {
                    Picker("Format", selection: $selectedGameFormat) {
                        Text("Stroke Play").tag("stroke")
                        Text("Stableford").tag("stableford")
                        Text("Team Stableford").tag("team_stableford")
                        Text("Best Ball").tag("bestball")
                        Text("Best Ball Match Play").tag("bestball_matchplay")
                        // Future formats: Skins
                        // Text("Skins").tag("skins")
                    }
                    .pickerStyle(.menu)
                    
                    if selectedGameFormat == "stableford" {
                        let settings = StablefordSettings.shared
                        Text("Points: Double Eagle (\(settings.pointsForDoubleEagle)), Eagle (\(settings.pointsForEagle)), Birdie (\(settings.pointsForBirdie)), Par (\(settings.pointsForPar)), Bogey (\(settings.pointsForBogey)), Double Bogey+ (\(settings.pointsForDoubleBogey))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedGameFormat == "team_stableford" {
                        let settings = StablefordSettings.shared
                        Text("Two teams of two players. Each team's total Stableford points (sum of both players' points) determines the winner. Points: Double Eagle (\(settings.pointsForDoubleEagle)), Eagle (\(settings.pointsForEagle)), Birdie (\(settings.pointsForBirdie)), Par (\(settings.pointsForPar)), Bogey (\(settings.pointsForBogey)), Double Bogey+ (\(settings.pointsForDoubleBogey))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedGameFormat == "bestball" {
                        Text("Two teams of two players. Each team's score is the best (lowest) net score (with handicaps) from their players on each hole.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedGameFormat == "bestball_matchplay" {
                        Text("Two teams of two players. Teams compete hole-by-hole using net scores (with handicaps). The team with the better net score wins the hole.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Team assignment section for Best Ball and Team Stableford
                if (selectedGameFormat == "bestball" || selectedGameFormat == "bestball_matchplay" || selectedGameFormat == "team_stableford") && !selectedPlayers.isEmpty {
                    Section("Team Assignment") {
                        Text("Select Team 1 or Team 2 for each player. You need 2 players on each team.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Team names
                        HStack {
                            TextField("Team 1 Name", text: $team1Name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Team 2 Name", text: $team2Name)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Column headers
                        HStack {
                            Text("Player")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Team 1")
                                .frame(width: 50)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Team 2")
                                .frame(width: 50)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                        
                        // Team status
                        HStack {
                            Text("Team 1: \(team1Players.count)/2")
                                .font(.caption)
                                .foregroundColor(team1Players.count == 2 ? .green : .secondary)
                            Spacer()
                            Text("Team 2: \(team2Players.count)/2")
                                .font(.caption)
                                .foregroundColor(team2Players.count == 2 ? .green : .secondary)
                        }
                        .padding(.bottom, 4)
                        
                        // Player list with team selection
                        ForEach(players.filter { selectedPlayers.contains($0.id) }) { player in
                            PlayerTeamSelectionRow(
                                player: player,
                                team1Players: $team1Players,
                                team2Players: $team2Players
                            )
                        }
                    }
                }
                
                // Tee selection section (only show when course is selected and has tees)
                if selectedCourse != nil, !availableTeeColors.isEmpty {
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
                    
                    NavigationLink("Add Player") {
                        AddPlayerView()
                    }
                }
                
                // Shot Tracking section (only show when players are selected)
                if !selectedPlayers.isEmpty {
                    Section("Shot Tracking") {
                        Text("Select which players will track their shots. Other players' scores can be entered manually on the scorecard.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(players.filter { selectedPlayers.contains($0.id) }) { player in
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
            }
            .onAppear {
                // Initialize tee selection if course is already selected
                if selectedCourse != nil && selectedTeeColor == nil && !availableTeeColors.isEmpty {
                    selectedTeeColor = defaultTeeColor
                }
                // Default tracking players to current user if available
                if trackingPlayers.isEmpty, let currentUser = players.first(where: { $0.isCurrentUser }) {
                    trackingPlayers.insert(currentUser.id)
                }
            }
            .onChange(of: selectedPlayers) { oldValue, newValue in
                // When players are selected, default tracking to current user if available
                if trackingPlayers.isEmpty, let currentUser = players.first(where: { $0.isCurrentUser }), newValue.contains(currentUser.id) {
                    trackingPlayers.insert(currentUser.id)
                }
                // Remove tracking for players who are no longer selected
                trackingPlayers = trackingPlayers.filter { newValue.contains($0) }
                // Remove team assignments for players who are no longer selected
                team1Players = team1Players.filter { newValue.contains($0) }
                team2Players = team2Players.filter { newValue.contains($0) }
            }
            
            .onChange(of: selectedGameFormat) { oldValue, newValue in
                // Reset team assignments when format changes
                if newValue != "bestball" && newValue != "bestball_matchplay" {
                    team1Players = []
                    team2Players = []
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
            .alert("Team Assignment Required", isPresented: $showingTeamValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(teamValidationMessage)
            }
        }
    }
    
    private func startGame() {
        // Validate team-based game assignments
        if selectedGameFormat == "bestball" || selectedGameFormat == "bestball_matchplay" || selectedGameFormat == "team_stableford" {
            if selectedPlayers.count != 4 {
                let formatName = selectedGameFormat == "team_stableford" ? "Team Stableford" : "Best Ball"
                teamValidationMessage = "\(formatName) requires exactly 4 players. You have \(selectedPlayers.count) players selected."
                showingTeamValidationAlert = true
                return
            }
            if team1Players.count != 2 {
                teamValidationMessage = "Team 1 must have exactly 2 players. Currently has \(team1Players.count) player(s)."
                showingTeamValidationAlert = true
                return
            }
            if team2Players.count != 2 {
                teamValidationMessage = "Team 2 must have exactly 2 players. Currently has \(team2Players.count) player(s)."
                showingTeamValidationAlert = true
                return
            }
            // Check that all selected players are assigned to a team
            let allAssignedPlayers = team1Players.union(team2Players)
            if allAssignedPlayers.count != 4 {
                teamValidationMessage = "All 4 players must be assigned to a team."
                showingTeamValidationAlert = true
                return
            }
        }
        
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
        
        // Get tracking player IDs (default to current user if none selected)
        let trackingPlayerIDsArray: [UUID] = {
            if trackingPlayers.isEmpty, let currentUser = selectedPlayersArray.first(where: { $0.isCurrentUser }) {
                return [currentUser.id]
            }
            return Array(trackingPlayers)
        }()
        
        // Create team assignments for Best Ball and Team Stableford
        let teamAssignments: [String: [UUID]]? = {
            if selectedGameFormat == "bestball" || selectedGameFormat == "bestball_matchplay" || selectedGameFormat == "team_stableford" {
                // Validate team assignments
                if selectedPlayers.count != 4 {
                    // Show alert or return nil - for now just return nil
                    return nil
                }
                if team1Players.count != 2 || team2Players.count != 2 {
                    // Show alert or return nil - for now just return nil
                    return nil
                }
                // Check that all selected players are assigned to a team
                let allAssignedPlayers = team1Players.union(team2Players)
                if allAssignedPlayers.count != 4 {
                    return nil
                }
                
                return [
                    team1Name.isEmpty ? "Team 1" : team1Name: Array(team1Players),
                    team2Name.isEmpty ? "Team 2" : team2Name: Array(team2Players)
                ]
            }
            return nil
        }()
        
        let newGame = Game(course: selectedCourse, players: selectedPlayersArray, selectedTeeColor: teeColorToUse, trackingPlayerIDs: trackingPlayerIDsArray, gameFormat: selectedGameFormat, teamAssignments: teamAssignments)
        
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


struct PlayerTeamSelectionRow: View {
    let player: Player
    @Binding var team1Players: Set<UUID>
    @Binding var team2Players: Set<UUID>
    
    var body: some View {
        HStack {
            // Player name
            Text(player.name)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Team 1 column
            VStack {
                Button {
                    let pid = player.id
                    if team1Players.contains(pid) {
                        team1Players.remove(pid)
                    } else {
                        team2Players.remove(pid)
                        team1Players.insert(pid)
                    }
                } label: {
                    Image(systemName: team1Players.contains(player.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(team1Players.contains(player.id) ? .blue : .gray)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 50)
            
            // Team 2 column
            VStack {
                Button {
                    let pid = player.id
                    if team2Players.contains(pid) {
                        team2Players.remove(pid)
                    } else {
                        team1Players.remove(pid)
                        team2Players.insert(pid)
                    }
                } label: {
                    Image(systemName: team2Players.contains(player.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(team2Players.contains(player.id) ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 50)
        }
    }
}

#Preview {
    GameSetupView(selectedGameIDString: .constant(""), games: [])
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self], inMemory: true)
}

