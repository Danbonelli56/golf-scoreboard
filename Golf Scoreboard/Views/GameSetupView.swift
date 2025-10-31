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
    
    var body: some View {
        NavigationView {
            Form {
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
                    }
                    
                    NavigationLink("Add Course") {
                        AddCourseView()
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
        let newGame = Game(course: selectedCourse, players: selectedPlayersArray)
        
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

