//
//  GameDetailView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @Query private var allShots: [Shot]
    @State private var selectedTab: Int = 0
    @State private var selectedHole: Int = 1
    
    var gameShots: [Shot] {
        let gameID = game.id
        return allShots.filter { shot in
            guard let shotGameID = shot.game?.id else { return false }
            return shotGameID == gameID
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(game.course?.name ?? "Unknown Course")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                HStack {
                    Text(game.date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let teeColor = game.effectiveTeeColor {
                        Text("• \(teeColor) Tees")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Scorecard").tag(0)
                Text("Shots").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Scorecard view
                GameScorecardView(game: game)
            } else {
                // Shots view
                GameShotsDetailView(
                    game: game,
                    gameShots: gameShots,
                    selectedHole: $selectedHole
                )
            }
        }
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GameShotsDetailView: View {
    @Bindable var game: Game
    let gameShots: [Shot]
    @Binding var selectedHole: Int
    
    // Hole yardage from the scorecard
    private var holeYardage: Int? {
        guard let course = game.course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == selectedHole }),
              let teeDistances = hole.teeDistances else { return nil }
        
        let teeColor = game.effectiveTeeColor
        if let teeColor = teeColor,
           let matchingTee = teeDistances.first(where: { $0.teeColor == teeColor }) {
            return matchingTee.distanceYards
        } else if let white = teeDistances.first(where: { $0.teeColor.lowercased() == "white" }) {
            return white.distanceYards
        }
        return teeDistances.first?.distanceYards
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hole selector
                VStack(spacing: 8) {
                    HStack {
                        Text("Hole")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(selectedHole)/18")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let yards = holeYardage {
                                Text("• \(yards) yds")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Picker("Hole", selection: $selectedHole) {
                        ForEach(1...18, id: \.self) { hole in
                            Text("\(hole)").tag(hole)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                
                // Shot list
                LazyVStack(spacing: 12) {
                    ForEach(game.playersArray) { player in
                        let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == selectedHole })
                        let isHoled = holeScore?.scores[player.id] != nil
                        ShotGroupCard(
                            player: player,
                            holeNumber: selectedHole,
                            allShots: gameShots,
                            currentGameID: game.id,
                            isHoled: isHoled
                        )
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    
    let course = GolfCourse(name: "Test Course")
    let player1 = Player(name: "John", handicap: 5.0)
    let player2 = Player(name: "Jane", handicap: 10.0)
    let game = Game(course: course, players: [player1, player2])
    
    container.mainContext.insert(course)
    container.mainContext.insert(player1)
    container.mainContext.insert(player2)
    container.mainContext.insert(game)
    
    return NavigationStack {
        GameDetailView(game: game)
            .modelContainer(container)
    }
}

