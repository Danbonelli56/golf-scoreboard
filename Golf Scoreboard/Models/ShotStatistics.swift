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
    var totalShots: Int
    var averageDistance: Double
    var minDistance: Int
    var maxDistance: Int
    var distances: [Int]
    
    init(club: String) {
        self.club = club
        self.totalShots = 0
        self.averageDistance = 0.0
        self.minDistance = 0
        self.maxDistance = 0
        self.distances = []
    }
    
    mutating func addDistance(_ distance: Int) {
        distances.append(distance)
        totalShots = distances.count
        
        if totalShots > 0 {
            averageDistance = Double(distances.reduce(0, +)) / Double(totalShots)
            minDistance = distances.min() ?? 0
            maxDistance = distances.max() ?? 0
        }
    }
}

// Player statistics aggregator
class ShotStatistics {
    
    static func calculateStatistics(for player: Player, shots: [Shot]) -> [String: ClubStatistics] {
        var stats: [String: ClubStatistics] = [:]
        
        // Filter shots for this player that have distance traveled
        let validShots = shots.filter { 
            $0.player?.id == player.id && 
            $0.distanceTraveled != nil && 
            $0.distanceTraveled! > 0
        }
        
        // Group by club
        for shot in validShots {
            guard let club = shot.club, 
                  let distance = shot.distanceTraveled else {
                continue
            }
            
            if stats[club] == nil {
                stats[club] = ClubStatistics(club: club)
            }
            
            stats[club]?.addDistance(distance)
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
}

