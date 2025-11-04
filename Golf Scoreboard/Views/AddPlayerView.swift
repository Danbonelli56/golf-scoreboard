//
//  AddPlayerView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct AddPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var playerName = ""
    @State private var handicapText = "0.0"
    @State private var isCurrentUser = false
    
    private var handicap: Double {
        Double(handicapText) ?? 0.0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Player Information") {
                    TextField("Name", text: $playerName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Handicap", text: $handicapText)
                        .keyboardType(.decimalPad)
                    
                    Toggle("Current User", isOn: $isCurrentUser)
                }
                
                if isCurrentUser {
                    Section {
                        Text("This player will be used as the default when no name is provided for shots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPlayer()
                    }
                    .disabled(playerName.isEmpty)
                }
            }
        }
    }
    
    private func addPlayer() {
        // If marking as current user, unmark any existing current user
        if isCurrentUser {
            let existingPlayers: [Player] = try! modelContext.fetch(FetchDescriptor())
            for player in existingPlayers where player.isCurrentUser {
                player.isCurrentUser = false
            }
        }
        
        let player = Player(name: playerName, handicap: handicap, isCurrentUser: isCurrentUser)
        modelContext.insert(player)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    AddPlayerView()
        .modelContainer(for: [Player.self], inMemory: true)
}

