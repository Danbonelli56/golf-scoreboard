//
//  EditPlayerView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct EditPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var player: Player
    
    @State private var playerName: String
    @State private var handicap: Double
    @State private var isCurrentUser: Bool
    @State private var preferredTeeColor: String
    
    init(player: Player) {
        self.player = player
        _playerName = State(initialValue: player.name)
        _handicap = State(initialValue: player.handicap)
        _isCurrentUser = State(initialValue: player.isCurrentUser)
        _preferredTeeColor = State(initialValue: player.preferredTeeColor ?? "White")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Player Information") {
                    TextField("Name", text: $playerName)
                        .textInputAutocapitalization(.words)
                    
                    Stepper("Handicap: \(String(format: "%.1f", handicap))", value: $handicap, in: 0...36, step: 0.1)
                    
                    Toggle("Current User", isOn: $isCurrentUser)
                    
                    Picker("Preferred Tee", selection: $preferredTeeColor) {
                        Text("White").tag("White")
                        Text("Blue").tag("Blue")
                        Text("Black").tag("Black")
                        Text("Gold").tag("Gold")
                        Text("Green").tag("Green")
                        Text("Red").tag("Red")
                    }
                }
                
                if isCurrentUser {
                    Section {
                        Text("This player will be used as the default when no name is provided for shots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlayer()
                    }
                    .disabled(playerName.isEmpty)
                }
            }
        }
    }
    
    private func savePlayer() {
        player.name = playerName
        player.handicap = handicap
        player.isCurrentUser = isCurrentUser
        player.preferredTeeColor = preferredTeeColor
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, configurations: config)
    let player = Player(name: "Test Player", handicap: 5.0)
    
    return EditPlayerView(player: player)
        .modelContainer(container)
}

