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
        let sortedGames = playerGames.sorted(by: { $0.date > $1.date })
        let stats = ShotStatistics.calculateStatistics(for: player, shots: shots)
        
        // Show trend chart for each club with enough data
        let clubStats = stats.filter({ !$0.value.isPutter && !$0.value.distances.isEmpty })
        ForEach(Array(clubStats.keys.sorted { club1, club2 in
            if club1 == "Driver" { return true }
            if club2 == "Driver" { return false }
            return club1 < club2
        }), id: \.self) { club in
            ClubTrendChart(player: player, club: club, games: sortedGames)
        }
        
        // Putter stats per game chart
        let putterShots = playerShots.filter({ $0.isPutt && $0.club?.lowercased() == "putter" })
        if !putterShots.isEmpty && !playerGames.isEmpty {
            PutterTrendChart(player: player, games: sortedGames)
        }
    }
}

struct ClubTrendChart: View {
    let player: Player
    let club: String
    let games: [Game]
    @Query private var shots: [Shot]
    
    var body: some View {
        let gameData = calculateClubDistancePerGame()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("\(club) Distance Trend")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Chart(gameData, id: \.gameName) { data in
                LineMark(
                    x: .value("Game", data.gameName),
                    y: .value("Distance", data.averageDistance)
                )
                .foregroundStyle(.blue.gradient)
                .interpolationMethod(.catmullRom)
                .symbol(.circle)
                
                // Add overall average line
                if let firstData = gameData.first {
                    RuleMark(y: .value("Average", firstData.overallAverage))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation {
                            Text("Avg: \(Int(firstData.overallAverage))")
                                .font(.caption2)
                                .foregroundColor(.orange)
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
            
            Text("Average distance in yards per game")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func calculateClubDistancePerGame() -> [ClubGameData] {
        var dataPoints: [ClubGameData] = []
        
        // Calculate overall average
        let allClubShots = shots.filter { $0.player?.id == player.id && $0.club?.lowercased() == club.lowercased() && !$0.isPutt }
        let overallAverage = calculateAverageDistance(from: allClubShots)
        
        for game in games {
            let gameShots = shots.filter { 
                guard let shotGameID = $0.game?.id else { return false }
                return shotGameID == game.id && $0.player?.id == player.id && $0.club?.lowercased() == club.lowercased() && !$0.isPutt
            }
            
            let avgDistance = calculateAverageDistance(from: gameShots)
            
            if avgDistance > 0 {
                dataPoints.append(ClubGameData(
                    gameName: game.course?.name ?? "Game",
                    averageDistance: avgDistance,
                    overallAverage: overallAverage
                ))
            }
        }
        
        return dataPoints
    }
    
    private func calculateAverageDistance(from shots: [Shot]) -> Double {
        let distances = shots.compactMap { $0.distanceTraveled }.filter { $0 > 0 }
        guard !distances.isEmpty else { return 0.0 }
        return Double(distances.reduce(0, +)) / Double(distances.count)
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

struct ClubGameData {
    let gameName: String
    let averageDistance: Double
    let overallAverage: Double
}

#Preview {
    StatisticsChartView()
        .modelContainer(for: [Player.self, Shot.self, Game.self], inMemory: true)
}

