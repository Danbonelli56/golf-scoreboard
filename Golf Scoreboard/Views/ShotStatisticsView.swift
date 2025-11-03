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
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Summary View
                List {
                    ForEach(players) { player in
                        Section(header: Text(player.name).font(.headline)) {
                            let stats = ShotStatistics.calculateStatistics(for: player, shots: shots)
                            let overall = ShotStatistics.getOverallStats(for: player, shots: shots)
                            
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
                StatisticsChartView()
                    .tabItem {
                        Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
            }
            .navigationTitle("Shot Statistics")
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
                HStack {
                    if stats.averageFeet > 0 {
                        Text("Avg:")
                        Text(String(format: "%.1f ft", stats.averageFeet))
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                        
                        Text("|")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Per Hole:")
                    Text(String(format: "%.2f putts", stats.puttsPerHole))
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(stats.totalPutts) putts")
                        .foregroundColor(.secondary)
                        .font(.caption)
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
        .modelContainer(for: [Player.self, Shot.self], inMemory: true)
}

