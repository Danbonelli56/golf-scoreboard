//
//  SkinsScorecardView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 12/20/25.
//

import SwiftUI
import SwiftData

struct SkinsScorecardView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @State private var isEditMode = false
    @State private var showingScoreEditor = false
    @State private var selectedHoleNumber: Int = 1
    
    // Find the first hole that doesn't have scores for all players
    private func findFirstEmptyHole() -> Int? {
        let players = game.playersArray
        guard !players.isEmpty else { return 1 }
        
        for holeNumber in 1...18 {
            let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
            
            guard let holeScore = holeScore else {
                return holeNumber
            }
            
            let scores = holeScore.scores
            let allPlayersHaveScores = players.allSatisfy { player in
                scores[player.id] != nil
            }
            
            if !allPlayersHaveScores {
                return holeNumber
            }
        }
        
        return nil
    }
    
    // Helper to extract first name
    func firstName(from fullName: String) -> String {
        fullName.components(separatedBy: " ").first ?? fullName
    }
    
    // Helper to extract last initial
    func lastInitial(from fullName: String) -> String? {
        let parts = fullName.components(separatedBy: " ")
        if parts.count > 1, let lastPart = parts.last, !lastPart.isEmpty {
            return String(lastPart.prefix(1)).uppercased()
        }
        return nil
    }
    
    // Display name for player - first name, or first name + last initial if duplicate first names
    func displayName(for player: Player) -> String {
        let players = game.playersArray
        let playerFirstName = firstName(from: player.name)
        
        // Check if there are multiple players with the same first name
        let duplicateFirstNames = players.filter { firstName(from: $0.name) == playerFirstName }.count > 1
        
        if duplicateFirstNames {
            // Show first name + last initial
            if let lastInitial = lastInitial(from: player.name) {
                return "\(playerFirstName) \(lastInitial)."
            }
        }
        
        // Just show first name
        return playerFirstName
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(game.course?.name ?? "Unknown Course")
                            .font(.headline)
                        Spacer()
                        
                        // Edit mode toggle
                        Button {
                            isEditMode.toggle()
                        } label: {
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text(game.date, format: .dateTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if !isEditMode {
                            Text("Tap to enter next score")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Tap any hole to edit")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Tee color display
                    if let teeColor = game.effectiveTeeColor {
                        HStack {
                            Text("Tees: \(teeColor)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Game format indicator
                    HStack {
                        Text("Format: Skins")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    // Pot information display
                    if let potPerPlayer = game.skinsPotPerPlayer, potPerPlayer > 0 {
                        if let totalPot = game.skinsTotalPot {
                            HStack {
                                Text("Pot: $\(totalPot, specifier: "%.2f") ($\(potPerPlayer, specifier: "%.2f") per player)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    } else if let valuePerSkin = game.skinsValuePerSkin {
                        // Fallback to old system for backward compatibility
                        HStack {
                            Text("Value: $\(valuePerSkin, specifier: "%.2f") per skin")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Carryover setting display
                    HStack {
                        Text("Carryover: \(game.skinsCarryoverEnabled ? "Enabled" : "Disabled")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                Divider()
                
                // Player columns
                if game.playersArray.isEmpty {
                    Text("No players in this game")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Header row with Par/HCP and player names
                    HStack(spacing: 0) {
                        Text("Hole")
                            .frame(width: 60)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("Par")
                            .frame(width: 50)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("HCP")
                            .frame(width: 50)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                            Text(displayName(for: player))
                                .frame(maxWidth: .infinity)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.tertiarySystemBackground))
                    
                    // Hole rows
                    ForEach(1...18, id: \.self) { holeNum in
                        SkinsHoleScoreRow(
                            holeNumber: holeNum,
                            game: game,
                            course: game.course,
                            isEditMode: isEditMode,
                            onTap: {
                                if isEditMode {
                                    selectedHoleNumber = holeNum
                                } else {
                                    selectedHoleNumber = findFirstEmptyHole() ?? holeNum
                                }
                                showingScoreEditor = true
                            }
                        )
                    }
                    
                    // Total rows
                    Divider()
                    SkinsTotalScoreRow(label: "Front 9", scores: game.front9Scores)
                    SkinsTotalScoreRow(label: "Back 9", scores: game.back9Scores)
                    SkinsTotalScoreRow(label: "Total", scores: game.totalScores)
                        .fontWeight(.bold)
                        .background(Color(.quaternarySystemFill))
                    
                    // Skins Summary
                    Divider()
                    SkinsSummaryView(game: game)
                }
            }
        }
        .sheet(isPresented: $showingScoreEditor) {
            ScoreEditorView(holeNumber: selectedHoleNumber, game: game)
        }
    }
}

struct SkinsHoleScoreRow: View {
    let holeNumber: Int
    @Bindable var game: Game
    let course: GolfCourse?
    let isEditMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Hole number
            Text("\(holeNumber)")
                .frame(width: 60)
                .font(.caption)
                .fontWeight(.medium)
            
            // Par
            Text(parText)
                .frame(width: 50)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Handicap
            Text(hcpText)
                .frame(width: 50)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Player scores (gross and net) with skin indicator
            ForEach(game.playersArray.sortedWithCurrentUserFirst()) { player in
                let gross = getScore(for: player)
                let net = gross != nil ? game.netScoreForHole(player: player, holeNumber: holeNumber) : nil
                let getsStroke = game.playerGetsStrokeOnHole(player: player, holeNumber: holeNumber)
                let isSkinWinner = game.skinsWinnerForHole(holeNumber)?.id == player.id
                let isCarryover = game.skinsWinnerForHole(holeNumber) == nil && gross != nil && game.skinsCarryoverEnabled
                
                VStack(spacing: 2) {
                    if let grossScore = gross {
                        Text("\(grossScore)")
                            .font(.caption)
                            .foregroundColor(scoreColor(for: grossScore))
                        if let netScore = net {
                            Text("(\(netScore))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        // Show "*" if player gets a stroke
                        if getsStroke {
                            Text("*")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        // Show skin indicator
                        if isSkinWinner {
                            Text("SKIN")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else if isCarryover {
                            Text("CO")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    } else {
                        // Show "*" instead of "-" if player gets a stroke (even without a score yet)
                        Text(getsStroke ? "*" : "-")
                            .font(.caption)
                            .foregroundColor(getsStroke ? .blue : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(holeNumber % 2 == 0 ? Color.clear : Color(.secondarySystemBackground).opacity(0.3))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var parText: String {
        if let holes = course?.holes, let hole = holes.first(where: { $0.holeNumber == holeNumber }) {
            return "\(hole.par)"
        }
        return "-"
    }
    
    private var hcpText: String {
        if let holes = course?.holes, let hole = holes.first(where: { $0.holeNumber == holeNumber }) {
            return "\(hole.mensHandicap)"
        }
        return "-"
    }
    
    private func getScore(for player: Player) -> Int? {
        let holeScore = game.holesScoresArray.first(where: { $0.holeNumber == holeNumber })
        return holeScore?.scores[player.id]
    }
    
    private func scoreColor(for score: Int) -> Color {
        guard let holes = course?.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }) else {
            return .primary
        }
        
        let par = hole.par
        let diff = score - par
        
        if diff <= -2 {
            return .purple // Double eagle or better
        } else if diff == -1 {
            return .blue // Eagle
        } else if diff == 0 {
            return .green // Par
        } else if diff == 1 {
            return .orange // Bogey
        } else {
            return .red // Double bogey or worse
        }
    }
}

struct SkinsTotalScoreRow: View {
    let label: String
    let scores: [(player: Player, gross: Int, net: Int)]
    
    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 60)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("")
                .frame(width: 50)
            
            Text("")
                .frame(width: 50)
            
            ForEach(scores, id: \.player.id) { score in
                VStack(spacing: 2) {
                    Text("\(score.gross)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(score.net))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(Color(.tertiarySystemBackground))
    }
}

struct SkinsSummaryView: View {
    @Bindable var game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skins Summary")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            let skins = game.skinsPerPlayer()
            let payouts = game.skinsPayouts()
            
            // Skins per player
            VStack(alignment: .leading, spacing: 8) {
                Text("Skins Won")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                ForEach(game.playersArray.sortedWithCurrentUserFirst(), id: \.id) { player in
                    HStack {
                        Text(player.name)
                            .font(.caption)
                        Spacer()
                        Text("\(skins[player.id] ?? 0)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            
            // Payouts (if pot per player is set or value per skin for backward compatibility)
            if (game.skinsPotPerPlayer != nil && game.skinsPotPerPlayer! > 0) || (game.skinsValuePerSkin != nil && game.skinsValuePerSkin! > 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Net Payout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    ForEach(game.playersArray.sortedWithCurrentUserFirst(), id: \.id) { player in
                        let payout = payouts[player.id] ?? 0.0
                        HStack {
                            Text(player.name)
                                .font(.caption)
                            Spacer()
                            Text(payout >= 0 ? "+$\(payout, specifier: "%.2f")" : "-$\(abs(payout), specifier: "%.2f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(payout >= 0 ? .green : .red)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Total pot info
                    let totalSkins = skins.values.reduce(0, +)
                    if totalSkins > 0 {
                        Divider()
                            .padding(.horizontal)
                        HStack {
                            Text("Total Skins Awarded:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(totalSkins)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        // Show pot-based calculation if using new system
                        if let potPerPlayer = game.skinsPotPerPlayer, potPerPlayer > 0, let totalPot = game.skinsTotalPot {
                            if let valuePerSkin = game.skinsCalculatedValuePerSkin {
                                HStack {
                                    Text("Total Pot:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("$\(totalPot, specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                
                                HStack {
                                    Text("Value per Skin:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("$\(valuePerSkin, specifier: "%.2f")")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                
                                Text("Pot divided by number of skins awarded")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                            }
                        } else if let valuePerSkin = game.skinsValuePerSkin, valuePerSkin > 0 {
                            // Old system display
                            let totalPot = Double(totalSkins) * valuePerSkin
                            
                            HStack {
                                Text("Value per Skin:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(valuePerSkin, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Text("Total Pot Value:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(totalPot, specifier: "%.2f")")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                            
                            Text("Payouts calculated by player-to-player differences")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                    } else if let potPerPlayer = game.skinsPotPerPlayer, potPerPlayer > 0, let totalPot = game.skinsTotalPot {
                        // No skins won yet, but pot is set
                        Divider()
                            .padding(.horizontal)
                        HStack {
                            Text("Total Pot:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("$\(totalPot, specifier: "%.2f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                        
                        Text("No skins awarded yet. All players have contributed to the pot.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
        }
        .padding(.bottom)
    }
}

