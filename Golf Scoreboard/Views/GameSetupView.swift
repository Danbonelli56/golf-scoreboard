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
                        CalendarImportView(selectedGameIDString: $selectedGameIDString)
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
        
        let newGame = Game(course: selectedCourse, players: selectedPlayersArray, selectedTeeColor: teeColorToUse)
        
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

