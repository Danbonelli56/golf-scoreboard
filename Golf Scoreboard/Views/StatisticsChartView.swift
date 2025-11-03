//
//  StatisticsChartView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsChartView: View {
    @Query private var players: [Player]
    @Query private var shots: [Shot]
    @Query private var games: [Game]
    
    var body: some View {
        List {
            ForEach(players) { player in
                Section(header: Text(player.name).font(.headline)) {
                    PlayerChartsSection(player: player)
                }
            }
        }
    }
}

struct PlayerChartsSection: View {
    let player: Player
    @Query private var shots: [Shot]
    @Query private var games: [Game]
    
    var body: some View {
        let playerShots = shots.filter { $0.player?.id == player.id }
        let playerGames = games.filter { $0.playersArray.contains(where: { $0.id == player.id }) }
        let stats = ShotStatistics.calculateStatistics(for: player, shots: shots)
        
        // Club distance comparison chart (for non-putters)
        if let clubStats = stats.filter({ !$0.value.isPutter && !$0.value.distances.isEmpty }) as? [String: ClubStatistics], !clubStats.isEmpty {
            ClubDistanceChart(clubStats: clubStats)
        }
        
        // Putter stats per game chart
        let putterShots = playerShots.filter({ $0.isPutt && $0.club?.lowercased() == "putter" })
        if !putterShots.isEmpty && !playerGames.isEmpty {
            PutterTrendChart(player: player, games: playerGames.sorted(by: { $0.date > $1.date }))
        }
    }
}

struct ClubDistanceChart: View {
    let clubStats: [String: ClubStatistics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Distance by Club")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Chart {
                ForEach(Array(clubStats.keys.sorted { club1, club2 in
                    if club1 == "Driver" { return true }
                    if club2 == "Driver" { return false }
                    return club1 < club2
                }), id: \.self) { club in
                    if let clubData = clubStats[club] {
                        BarMark(
                            x: .value("Club", club),
                            y: .value("Distance", clubData.averageDistance)
                        )
                        .foregroundStyle(.blue.gradient)
                        .annotation {
                            Text("\(Int(clubData.averageDistance))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine()
                }
            }
            
            Text("Average distance in yards")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct PutterTrendChart: View {
    let player: Player
    let games: [Game]
    @Query private var shots: [Shot]
    
    var body: some View {
        let gamePuttsData = calculatePuttStatsPerGame()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Putts Per Hole (Per Game)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Chart(gamePuttsData, id: \.gameName) { data in
                LineMark(
                    x: .value("Game", data.gameName),
                    y: .value("Putts/Hole", data.puttsPerHole)
                )
                .foregroundStyle(.green.gradient)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
                
                // Add average line
                RuleMark(y: .value("Average", data.overallAverage))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation {
                        Text("Avg: \(String(format: "%.2f", data.overallAverage))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine()
                }
            }
            
            Text("Putts per hole trend")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func calculatePuttStatsPerGame() -> [GamePuttData] {
        var dataPoints: [GamePuttData] = []
        
        for game in games {
            let gameShots = shots.filter { 
                guard let shotGameID = $0.game?.id else { return false }
                return shotGameID == game.id && $0.player?.id == player.id && $0.isPutt && $0.club?.lowercased() == "putter"
            }
            
            // Count putts per hole
            var holesWithPutts: Set<Int> = []
            var totalPutts = 0
            
            for shot in gameShots {
                holesWithPutts.insert(shot.holeNumber)
                totalPutts += 1
            }
            
            if !holesWithPutts.isEmpty {
                let puttsPerHole = Double(totalPutts) / Double(holesWithPutts.count)
                
                // Calculate overall average for reference
                let allPutterShots = shots.filter { $0.player?.id == player.id && $0.isPutt && $0.club?.lowercased() == "putter" }
                var allHoles: Set<Int> = []
                var allTotalPutts = 0
                for shot in allPutterShots {
                    allHoles.insert(shot.holeNumber)
                    allTotalPutts += 1
                }
                let overallAverage = allHoles.isEmpty ? 0.0 : Double(allTotalPutts) / Double(allHoles.count)
                
                dataPoints.append(GamePuttData(
                    gameName: game.course?.name ?? "Game",
                    puttsPerHole: puttsPerHole,
                    overallAverage: overallAverage
                ))
            }
        }
        
        return dataPoints
    }
}

struct GamePuttData {
    let gameName: String
    let puttsPerHole: Double
    let overallAverage: Double
}

#Preview {
    StatisticsChartView()
        .modelContainer(for: [Player.self, Shot.self, Game.self], inMemory: true)
}

