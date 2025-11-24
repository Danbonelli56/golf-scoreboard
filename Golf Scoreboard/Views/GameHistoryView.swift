//
//  GameHistoryView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct GameHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Game.date, order: .reverse) private var allGames: [Game]
    
    @AppStorage("selectedGameID") private var selectedGameIDString: String = ""
    
    var completedGames: [Game] {
        allGames.filter { game in
            // Show games that are explicitly marked as completed OR are from previous days
            return game.isCompleted || game.isFromPreviousDay
        }
    }
    
    // Archive expired games when viewing history
    private func archiveExpiredGames() {
        for game in allGames {
            // Check if game is from a previous day and not yet completed
            if game.isFromPreviousDay && !game.isCompleted {
                // Mark as completed (archived) - shots are preserved via relationship
                game.isCompleted = true
            }
        }
        try? modelContext.save()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if completedGames.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No Completed Games")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Complete a game to see it here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(completedGames) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                        GameHistoryRow(game: game)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteGame(game)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            }
                    }
                }
            }
            .navigationTitle("Game History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            deleteAllCompletedGames()
                        }) {
                            Label("Delete All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                // Archive expired games when viewing history
                archiveExpiredGames()
            }
        }
    }
    
    private func deleteGame(_ game: Game) {
        // Clear selection if this was the selected game
        if let selectedID = UUID(uuidString: selectedGameIDString), selectedID == game.id {
            _selectedGameIDString.wrappedValue = ""
        }
        
        // Delete all related shots
        if let shots = game.shots {
            for shot in shots {
                modelContext.delete(shot)
            }
        }
        
        // Delete all related hole scores (which will cascade delete player scores)
        if let holeScores = game.holesScores {
            for holeScore in holeScores {
                modelContext.delete(holeScore)
            }
        }
        
        // Delete the game itself
        modelContext.delete(game)
        
        // Save changes
        try? modelContext.save()
        
        // Post notification to update statistics
        NotificationCenter.default.post(name: .shotsUpdated, object: nil)
    }
    
    private func deleteAllCompletedGames() {
        for game in completedGames {
            deleteGame(game)
        }
    }
}

struct GameHistoryRow: View {
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(game.course?.name ?? "Unknown Course")
                    .font(.headline)
                
                Spacer()
                
                Text(game.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Players and scores
            ForEach(game.playersArray) { player in
                HStack {
                    Text(player.name)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    let scores = game.totalScores.first(where: { $0.player.id == player.id })
                    if let gross = scores?.gross, let net = scores?.net {
                        Text("Gross: \(gross) | Net: \(net)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Totals summary
            HStack {
                if let front9 = game.front9Scores.first {
                    Text("Front 9: \(front9.gross)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let back9 = game.back9Scores.first {
                    Text("Back 9: \(back9.gross)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GameHistoryView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self, HoleScore.self], inMemory: true)
}

