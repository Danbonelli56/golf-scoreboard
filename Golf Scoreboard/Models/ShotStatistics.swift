//
//  ShotStatistics.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation

// Statistics for a specific club
struct ClubStatistics {
    var club: String
    var averageDistance: Double
    var minDistance: Int
    var maxDistance: Int
    var distances: [Int]
    var shotsByResult: [String: Int]
    
    // Putter-specific stats
    var isPutter: Bool = false
    var totalPutts: Int = 0
    var uniqueHoles: Set<Int> = []
    var uniqueGames: Set<UUID> = [] // Track games for putts per round calculation
    var feetDistances: [Int] = [] // Feet for putts
    var averageFeet: Double = 0.0
    var longPutts: Int = 0 // Count of putts that went long
    var shortPutts: Int = 0 // Count of putts that came short
    
    var totalShots: Int {
        shotsByResult.values.reduce(0, +)
    }
    
    var puttsPerHole: Double {
        uniqueHoles.isEmpty ? 0.0 : Double(totalPutts) / Double(uniqueHoles.count)
    }
    
    var puttsPerRound: Double {
        uniqueGames.isEmpty ? 0.0 : Double(totalPutts) / Double(uniqueGames.count)
    }
    
    init(club: String) {
        self.club = club
        self.averageDistance = 0.0
        self.minDistance = 0
        self.maxDistance = 0
        self.distances = []
        self.shotsByResult = [:]
        self.isPutter = club.lowercased() == "putter"
        self.feetDistances = []
    }
    
    mutating func addDistance(_ distance: Int) {
        distances.append(distance)
        let count = distances.count
        
        if count > 0 {
            averageDistance = Double(distances.reduce(0, +)) / Double(count)
            minDistance = distances.min() ?? 0
            maxDistance = distances.max() ?? 0
        }
    }
    
    mutating func addPutt(holeNumber: Int, gameID: UUID?, feet: Int?, isLong: Bool = false, isShort: Bool = false) {
        totalPutts += 1
        uniqueHoles.insert(holeNumber)
        if let gameID = gameID {
            uniqueGames.insert(gameID)
        }
        if let feet = feet, feet > 0 {
            feetDistances.append(feet)
            let count = feetDistances.count
            if count > 0 {
                averageFeet = Double(feetDistances.reduce(0, +)) / Double(count)
            }
        }
        if isLong {
            longPutts += 1
        }
        if isShort {
            shortPutts += 1
        }
    }
    
    mutating func addShot(with result: String) {
        shotsByResult[result, default: 0] += 1
    }
}

// Player statistics aggregator
class ShotStatistics {
    
    static func calculateStatistics(for player: Player, shots: [Shot]) -> [String: ClubStatistics] {
        var stats: [String: ClubStatistics] = [:]
        
        // Filter shots for this player - include all shots, not just those with distance
        // For putts specifically, track them even if distanceTraveled is 0 or nil
        let validShots = shots.filter { 
            $0.player?.id == player.id
        }
        
        // Group by club
        for shot in validShots {
            guard let club = shot.club else {
                continue
            }
            
            if stats[club] == nil {
                stats[club] = ClubStatistics(club: club)
            }
            
            // Handle putts differently
            if shot.isPutt && shot.club?.lowercased() == "putter" {
                stats[club]?.addPutt(holeNumber: shot.holeNumber, gameID: shot.game?.id, feet: shot.originalDistanceFeet, isLong: shot.isLong, isShort: shot.isShort)
            } else {
                // Add distance if available for non-putts
                if let distance = shot.distanceTraveled, distance > 0 {
                    stats[club]?.addDistance(distance)
                }
            }
            
            // Always track shot result (including putts)
            stats[club]?.addShot(with: shot.result)
        }
        
        return stats
    }
    
    static func getOverallStats(for player: Player, shots: [Shot]) -> (totalShots: Int, averageDistance: Double, totalDistance: Int) {
        let validShots = shots.filter { 
            $0.player?.id == player.id && 
            $0.distanceTraveled != nil 
        }
        
        let totalShots = validShots.count
        let totalDistance = validShots.compactMap { $0.distanceTraveled }.reduce(0, +)
        let averageDistance = totalShots > 0 ? Double(totalDistance) / Double(totalShots) : 0.0
        
        return (totalShots, averageDistance, totalDistance)
    }
    
    // Calculate bunker statistics for a player
    static func getBunkerStats(for player: Player, shots: [Shot]) -> (totalBunkerShots: Int, averageDistance: Double, shotsPerRound: Double, uniqueGames: Set<UUID>) {
        let bunkerShots = shots.filter { 
            $0.player?.id == player.id && 
            $0.isInBunker && 
            !$0.isPutt
        }
        
        let totalBunkerShots = bunkerShots.count
        let distances = bunkerShots.compactMap { $0.distanceTraveled }.filter { $0 > 0 }
        let averageDistance = distances.isEmpty ? 0.0 : Double(distances.reduce(0, +)) / Double(distances.count)
        
        // Track unique games for per-round calculation
        var uniqueGames: Set<UUID> = []
        for shot in bunkerShots {
            if let gameID = shot.game?.id {
                uniqueGames.insert(gameID)
            }
        }
        
        let shotsPerRound = uniqueGames.isEmpty ? 0.0 : Double(totalBunkerShots) / Double(uniqueGames.count)
        
        return (totalBunkerShots, averageDistance, shotsPerRound, uniqueGames)
    }
}

