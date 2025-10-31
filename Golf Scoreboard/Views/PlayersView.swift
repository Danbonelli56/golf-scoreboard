//
//  PlayersView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct PlayersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @State private var showingAddPlayer = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(players) { player in
                    PlayerRow(player: player)
                }
                .onDelete(perform: deletePlayers)
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Label("Add Player", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                AddPlayerView()
            }
            .overlay {
                if players.isEmpty {
                    EmptyPlayersView()
                }
            }
        }
    }
    
    private func deletePlayers(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
        try? modelContext.save()
    }
}

struct PlayerRow: View {
    @State private var showingEditPlayer = false
    @Bindable var player: Player
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(player.name)
                        .font(.headline)
                    
                    if player.isCurrentUser {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                Text("Handicap: \(String(format: "%.1f", player.handicap))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: { showingEditPlayer = true }) {
                    Label("Edit", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingEditPlayer) {
            EditPlayerView(player: player)
        }
    }
}

struct EmptyPlayersView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Players")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add players to start tracking games")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PlayersView()
        .modelContainer(for: [Player.self], inMemory: true)
}

