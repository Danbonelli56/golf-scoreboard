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
    @AppStorage("selectedGameID") private var selectedGameIDString: String = ""
    
    let filteredGames: [Game]
    let filteredShots: [Shot]
    
    var body: some View {
        List {
            ForEach(players.sortedWithCurrentUserFirst()) { player in
                Section(header: Text(player.name).font(.headline)) {
                    PlayerChartsSection(
                        player: player,
                        selectedGameIDString: selectedGameIDString,
                        validShots: filteredShots,
                        filteredGames: filteredGames
                    )
                }
            }
        }
    }
}

struct PlayerChartsSection: View {
    let player: Player
    let selectedGameIDString: String
    let validShots: [Shot] // Use filtered shots from parent
    let filteredGames: [Game] // Use filtered games from parent
    @State private var showCurrentRoundOnly = false
    
    var body: some View {
        let playerShots = validShots.filter { $0.player?.id == player.id }
        // Filter to only games that include this player
        let playerGames = filteredGames.filter { $0.playersArray.contains(where: { $0.id == player.id }) }
        let sortedGames = playerGames.sorted(by: { $0.date > $1.date })
        let stats = ShotStatistics.calculateStatistics(for: player, shots: validShots)
        
        // Toggle between all games and current round
        Picker("View", selection: $showCurrentRoundOnly) {
            Text("All Games").tag(false)
            Text("Current Round").tag(true)
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 8)
        
        // Determine which games to use
        let gamesToShow: [Game] = {
            if showCurrentRoundOnly, !selectedGameIDString.isEmpty, let gameID = UUID(uuidString: selectedGameIDString) {
                return filteredGames.filter { $0.id == gameID }
            }
            return sortedGames
        }()
        
        // Show trend chart for each club with enough data
        let clubStats = stats.filter({ !$0.value.isPutter && !$0.value.distances.isEmpty })
        ForEach(Array(clubStats.keys.sorted { club1, club2 in
            if club1 == "Driver" { return true }
            if club2 == "Driver" { return false }
            return club1 < club2
        }), id: \.self) { club in
            ClubTrendChart(player: player, club: club, games: gamesToShow, showPerHole: showCurrentRoundOnly, shots: validShots, allShots: validShots)
        }
        
        // Putter stats per game chart
        let putterShots = playerShots.filter({ $0.isPutt && $0.club?.lowercased() == "putter" })
        if !putterShots.isEmpty && !playerGames.isEmpty {
            PutterTrendChart(player: player, games: gamesToShow, showPerHole: showCurrentRoundOnly, shots: validShots, allShots: validShots)
        }
    }
}

struct ClubTrendChart: View {
    let player: Player
    let club: String
    let games: [Game]
    let showPerHole: Bool
    let shots: [Shot] // Use filtered shots from parent
    let allShots: [Shot] // All shots for overall average calculation
    
    var body: some View {
        let gameData = showPerHole ? calculateClubDistancePerHole() : calculateClubDistancePerGame()
        
        VStack(alignment: .leading, spacing: 8) {
            Text(showPerHole ? "\(club) Distance (This Round)" : "\(club) Distance Trend")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Chart(gameData, id: \.gameName) { data in
                LineMark(
                    x: .value(showPerHole ? "Hole" : "Game", data.gameName),
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
            
            Text(showPerHole ? "Average distance per hole in yards" : "Average distance in yards per game")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func calculateClubDistancePerGame() -> [ClubGameData] {
        var dataPoints: [ClubGameData] = []
        
        // Calculate overall average from all filtered shots
        let allClubShots = allShots.filter { $0.player?.id == player.id && $0.club?.lowercased() == club.lowercased() && !$0.isPutt }
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
    
    private func calculateClubDistancePerHole() -> [ClubGameData] {
        var dataPoints: [ClubGameData] = []
        
        guard let game = games.first else { return dataPoints }
        
        // Calculate overall average from all filtered shots
        let allClubShots = allShots.filter { $0.player?.id == player.id && $0.club?.lowercased() == club.lowercased() && !$0.isPutt }
        let overallAverage = calculateAverageDistance(from: allClubShots)
        
        // Get all shots for this game, player, and club
        let gameShots = shots.filter { 
            guard let shotGameID = $0.game?.id else { return false }
            return shotGameID == game.id && $0.player?.id == player.id && $0.club?.lowercased() == club.lowercased() && !$0.isPutt
        }
        
        // Group by hole
        var holeDistances: [Int: [Int]] = [:]
        for shot in gameShots {
            if let distance = shot.distanceTraveled, distance > 0 {
                holeDistances[shot.holeNumber, default: []].append(distance)
            }
        }
        
        // Create data points for each hole
        let sortedHoles = holeDistances.keys.sorted()
        for holeNum in sortedHoles {
            if let distances = holeDistances[holeNum] {
                let avgDistance = Double(distances.reduce(0, +)) / Double(distances.count)
                dataPoints.append(ClubGameData(
                    gameName: "Hole \(holeNum)",
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
    let showPerHole: Bool
    let shots: [Shot] // Use filtered shots from parent
    let allShots: [Shot] // All shots for overall average calculation
    
    var body: some View {
        let gamePuttsData = showPerHole ? calculatePuttStatsPerHole() : calculatePuttStatsPerGame()
        
        VStack(alignment: .leading, spacing: 8) {
            Text(showPerHole ? "Putts Per Hole (This Round)" : "Putts Per Hole (Per Game)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Chart(gamePuttsData, id: \.gameName) { data in
                LineMark(
                    x: .value(showPerHole ? "Hole" : "Game", data.gameName),
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
                
                // Calculate overall average for reference from all filtered shots
                let allPutterShots = allShots.filter { $0.player?.id == player.id && $0.isPutt && $0.club?.lowercased() == "putter" }
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
    
    private func calculatePuttStatsPerHole() -> [GamePuttData] {
        var dataPoints: [GamePuttData] = []
        
        guard let game = games.first else { return dataPoints }
        
        // Get all putts for this game and player
        let gameShots = shots.filter { 
            guard let shotGameID = $0.game?.id else { return false }
            return shotGameID == game.id && $0.player?.id == player.id && $0.isPutt && $0.club?.lowercased() == "putter"
        }
        
        // Calculate overall average for reference from all filtered shots
        let allPutterShots = allShots.filter { $0.player?.id == player.id && $0.isPutt && $0.club?.lowercased() == "putter" }
        var allHoles: Set<Int> = []
        var allTotalPutts = 0
        for shot in allPutterShots {
            allHoles.insert(shot.holeNumber)
            allTotalPutts += 1
        }
        let overallAverage = allHoles.isEmpty ? 0.0 : Double(allTotalPutts) / Double(allHoles.count)
        
        // Group putts by hole
        var puttsByHole: [Int: Int] = [:]
        for shot in gameShots {
            puttsByHole[shot.holeNumber, default: 0] += 1
        }
        
        // Create data points for each hole
        let sortedHoles = puttsByHole.keys.sorted()
        for holeNum in sortedHoles {
            let puttsForHole = puttsByHole[holeNum] ?? 0
            dataPoints.append(GamePuttData(
                gameName: "Hole \(holeNum)",
                puttsPerHole: Double(puttsForHole),
                overallAverage: overallAverage
            ))
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
    StatisticsChartView(filteredGames: [], filteredShots: [])
        .modelContainer(for: [Player.self, Shot.self, Game.self], inMemory: true)
}

