//
//  ShotStatisticsView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct ShotStatisticsView: View {
    @Query private var players: [Player]
    @Query private var shots: [Shot]
    @Query(sort: \Game.date, order: .reverse) private var allGames: [Game]
    @State private var selectedTab = 0
    @AppStorage("statsGameCount") private var statsGameCount: Int = 0
    
    // Filter games based on user selection
    private var filteredGames: [Game] {
        if statsGameCount == 0 {
            // Show all games
            return allGames
        } else {
            // Show only the most recent N games
            return Array(allGames.prefix(statsGameCount))
        }
    }
    
    // Filter shots to only include those from filtered games
    // Also ensure shots have valid relationships (not deleted or orphaned)
    private var validShots: [Shot] {
        let validGameIDs = Set(filteredGames.map { $0.id })
        return shots.filter { shot in
            // Ensure shot has valid game relationship
            guard let gameID = shot.game?.id else { return false }
            // Ensure shot has valid player relationship
            guard shot.player != nil else { return false }
            // Only include shots from filtered games
            return validGameIDs.contains(gameID)
        }
    }
    
    // Calculate average scores (gross and net) for a player across filtered games
    private func averageScores(for player: Player) -> (gross: Double, net: Double)? {
        let playerGames = filteredGames.filter { game in
            game.playersArray.contains(where: { $0.id == player.id })
        }
        
        guard !playerGames.isEmpty else { return nil }
        
        var totalGross = 0
        var totalNet = 0
        var gameCount = 0
        
        for game in playerGames {
            if let score = game.totalScores.first(where: { $0.player.id == player.id }) {
                totalGross += score.gross
                totalNet += score.net
                gameCount += 1
            }
        }
        
        guard gameCount > 0 else { return nil }
        return (
            gross: Double(totalGross) / Double(gameCount),
            net: Double(totalNet) / Double(gameCount)
        )
    }
    
    // Available game count options
    private let gameCountOptions = [0, 5, 10, 20, 50]
    
    private var gameCountText: String {
        if statsGameCount == 0 {
            return "All Games (\(allGames.count))"
        } else {
            let actualCount = min(statsGameCount, allGames.count)
            return "Last \(actualCount) Games"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Game count selector
                VStack(spacing: 8) {
                    HStack {
                        Text("Games Included")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(gameCountText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Picker("Number of Games", selection: $statsGameCount) {
                        ForEach(gameCountOptions, id: \.self) { count in
                            Text(count == 0 ? "All Games" : "Last \(count) Games")
                                .tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                
                TabView(selection: $selectedTab) {
                    // Summary View
                    List {
                        ForEach(players) { player in
                            Section(header: Text(player.name).font(.headline)) {
                                let stats = ShotStatistics.calculateStatistics(for: player, shots: validShots)
                                let overall = ShotStatistics.getOverallStats(for: player, shots: validShots)
                            
                            // Overall stats
                            HStack {
                                Text("Total Shots Tracked")
                                Spacer()
                                Text("\(overall.totalShots)")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Average Distance")
                                Spacer()
                                Text("\(Int(overall.averageDistance)) yds")
                                    .foregroundColor(.secondary)
                            }
                            
                            // Average scores (gross and net)
                            if let avgScores = averageScores(for: player) {
                                HStack {
                                    Text("Average Score (Gross)")
                                    Spacer()
                                    Text(String(format: "%.1f", avgScores.gross))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Average Score (Net)")
                                    Spacer()
                                    Text(String(format: "%.1f", avgScores.net))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Bunker statistics
                            let bunkerStats = ShotStatistics.getBunkerStats(for: player, shots: validShots)
                            if bunkerStats.totalBunkerShots > 0 {
                                Divider()
                                
                                HStack {
                                    Text("Bunker Shots")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Per Round:")
                                    Spacer()
                                    Text(String(format: "%.1f", bunkerStats.shotsPerRound))
                                        .foregroundColor(.secondary)
                                }
                                
                                if bunkerStats.averageDistance > 0 {
                                    HStack {
                                        Text("Average Distance:")
                                        Spacer()
                                        Text(String(format: "%.0f yds", bunkerStats.averageDistance))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack {
                                    Text("Total:")
                                    Spacer()
                                    Text("\(bunkerStats.totalBunkerShots)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Stats by club
                            if !stats.isEmpty {
                                Divider()
                                
                                ForEach(Array(stats.keys.sorted { club1, club2 in
                                    // Put Driver first
                                    if club1 == "Driver" { return true }
                                    if club2 == "Driver" { return false }
                                    // Then sort alphabetically
                                    return club1 < club2
                                }), id: \.self) { club in
                                    if let clubStats = stats[club] {
                                        ClubStatsRow(stats: clubStats)
                                    }
                                }
                            } else {
                                Text("No shot data available")
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                    }
                    .tabItem {
                        Label("Summary", systemImage: "list.bullet")
                    }
                    .tag(0)
                    
                    // Charts View
                    StatisticsChartView(filteredGames: filteredGames, filteredShots: validShots)
                        .tabItem {
                            Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        .tag(1)
                }
            }
            .navigationTitle("Shot Statistics")
            .onReceive(NotificationCenter.default.publisher(for: .shotsUpdated)) { _ in
                // Force view refresh when shots are updated/deleted
                // SwiftData @Query should automatically update, but this ensures UI refreshes
            }
        }
    }
}

struct ClubStatsRow: View {
    let stats: ClubStatistics
    
    private var straightCount: Int { stats.shotsByResult["Straight"] ?? 0 }
    private var leftCount: Int { stats.shotsByResult["Left"] ?? 0 }
    private var rightCount: Int { stats.shotsByResult["Right"] ?? 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stats.club)
                .font(.headline)
            
            // Special display for Putter
            if stats.isPutter {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Per Round:")
                        Text(String(format: "%.1f putts", stats.puttsPerRound))
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Per Hole:")
                        Text(String(format: "%.2f putts", stats.puttsPerHole))
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(stats.totalPutts) total")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    // Direction and distance indicators for putts
                    if !stats.shotsByResult.isEmpty || stats.longPutts > 0 || stats.shortPutts > 0 {
                        HStack(spacing: 12) {
                            if let rightCount = stats.shotsByResult["Right"], rightCount > 0 {
                                Label("\(rightCount)", systemImage: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            if let leftCount = stats.shotsByResult["Left"], leftCount > 0 {
                                Label("\(leftCount)", systemImage: "arrow.left")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if let straightCount = stats.shotsByResult["Straight"], straightCount > 0 {
                                Label("\(straightCount)", systemImage: "arrow.up")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if stats.longPutts > 0 {
                                Label("\(stats.longPutts)", systemImage: "arrow.up.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                            if stats.shortPutts > 0 {
                                Label("\(stats.shortPutts)", systemImage: "arrow.down.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .font(.caption)
            } else if stats.averageDistance > 0 {
                // Distance stats for non-putters (if available)
                HStack {
                    Text("Avg:")
                    Text("\(Int(stats.averageDistance)) yds")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                    
                    Text("|")
                        .foregroundColor(.secondary)
                    
                    Text("Range:")
                    Text("\(stats.minDistance)-\(stats.maxDistance) yds")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(stats.totalShots) shots")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .font(.caption)
            } else {
                // Show total shots count even when no distance data
                HStack {
                    Text("\(stats.totalShots) shots")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Spacer()
                }
            }
            
            // Shot direction breakdown (for non-putters only)
            if !stats.isPutter && !stats.shotsByResult.isEmpty {
                HStack(spacing: 12) {
                    if straightCount > 0 {
                        Label("\(straightCount)", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    if leftCount > 0 {
                        Label("\(leftCount)", systemImage: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    if rightCount > 0 {
                        Label("\(rightCount)", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ShotStatisticsView()
        .modelContainer(for: [Player.self, Shot.self, Game.self], inMemory: true)
}
