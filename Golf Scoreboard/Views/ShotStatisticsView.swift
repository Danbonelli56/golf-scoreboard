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
    
    var body: some View {
        NavigationView {
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
                            
                            ForEach(Array(stats.keys.sorted()), id: \.self) { club in
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
            
            // Distance stats (if available)
            if stats.averageDistance > 0 {
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
            
            // Shot direction breakdown
            if !stats.shotsByResult.isEmpty {
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

