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
    
    var totalShots: Int {
        shotsByResult.values.reduce(0, +)
    }
    
    init(club: String) {
        self.club = club
        self.averageDistance = 0.0
        self.minDistance = 0
        self.maxDistance = 0
        self.distances = []
        self.shotsByResult = [:]
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
            
            // Add distance if available
            if let distance = shot.distanceTraveled, distance > 0 {
                stats[club]?.addDistance(distance)
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
}

