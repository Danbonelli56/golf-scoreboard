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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stats.club)
                .font(.headline)
            
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ShotStatisticsView()
        .modelContainer(for: [Player.self, Shot.self], inMemory: true)
}

