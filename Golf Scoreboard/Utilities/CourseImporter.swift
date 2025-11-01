//
//  CourseImporter.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import SwiftData

class CourseImporter {
    
    static func createAmeliaRiverClub(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "The Amelia River Club",
            location: "Amelia Island, FL",
            slope: 133, // Using Blue tees as reference
            rating: 70.5
        )
        
        // Par values
        let pars = [5, 4, 4, 3, 5, 4, 3, 4, 4, 4, 4, 3, 5, 4, 4, 4, 3, 5]
        
        // Men's handicaps
        let mensHandicaps = [17, 13, 11, 9, 15, 5, 7, 3, 1, 8, 6, 16, 10, 12, 14, 2, 18, 4]
        
        // Ladies' handicaps
        let ladiesHandicaps = [11, 13, 7, 17, 5, 9, 15, 3, 1, 14, 10, 18, 4, 8, 12, 2, 16, 6]
        
        // Blue tees distances
        let blueDistances = [521, 337, 372, 176, 521, 356, 190, 363, 389, 339, 357, 160, 538, 338, 325, 407, 147, 513]
        
        // Black tees distances
        let blackDistances = [469, 312, 333, 151, 489, 337, 164, 343, 373, 327, 333, 135, 493, 321, 309, 383, 122, 478]
        
        // White tees distances
        let whiteDistances = [428, 276, 296, 119, 456, 301, 134, 309, 340, 311, 296, 120, 456, 280, 282, 351, 98, 437]
        
        // Create holes with distances
        for i in 0..<18 {
            let hole = Hole(
                holeNumber: i + 1,
                par: pars[i],
                mensHandicap: mensHandicaps[i],
                ladiesHandicap: ladiesHandicaps[i]
            )
            
            // Add tee distances
            let blueTee = TeeDistance(teeColor: "Blue", distanceYards: blueDistances[i])
            let blackTee = TeeDistance(teeColor: "Black", distanceYards: blackDistances[i])
            let whiteTee = TeeDistance(teeColor: "White", distanceYards: whiteDistances[i])
            
            hole.teeDistances.append(blueTee)
            hole.teeDistances.append(blackTee)
            hole.teeDistances.append(whiteTee)
            
            course.holes.append(hole)
        }
        
        // Add tee sets with slope and rating
        let teeSets = [
            TeeSet(teeColor: "Gold", slope: 140.0, rating: 73.1),
            TeeSet(teeColor: "Blue", slope: 133.0, rating: 70.5),
            TeeSet(teeColor: "Black", slope: 124.0, rating: 68.5),
            TeeSet(teeColor: "White", slope: 111.0, rating: 66.1)
        ]
        
        for teeSet in teeSets {
            course.teeSets.append(teeSet)
        }
        
        context.insert(course)
        return course
    }
    
    static func createNorthHamptonGolfClub(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "The Golf Club at North Hampton",
            location: "Fernandina Beach, FL",
            slope: 141, // Using Gold tees as reference
            rating: 74.5
        )
        
        // Par values
        let pars = [4, 5, 3, 4, 4, 5, 3, 4, 4, 4, 4, 5, 4, 3, 5, 4, 3, 4]
        
        // Men's handicaps
        let mensHandicaps = [11, 3, 17, 1, 7, 13, 9, 15, 5, 16, 6, 14, 2, 12, 10, 4, 18, 8]
        
        // Gold tees distances (shown on scorecard)
        let goldDistances = [406, 620, 195, 448, 375, 525, 189, 366, 393, 325, 411, 552, 445, 218, 580, 446, 140, 449]
        
        // White tees distances from BlueGolf
        let whiteDistances = [342, 549, 154, 385, 335, 455, 159, 308, 322, 274, 352, 472, 372, 155, 492, 355, 122, 365]
        
        // Create holes with distances
        for i in 0..<18 {
            let hole = Hole(
                holeNumber: i + 1,
                par: pars[i],
                mensHandicap: mensHandicaps[i]
            )
            
            // Add tee distances
            let goldTee = TeeDistance(teeColor: "Gold", distanceYards: goldDistances[i])
            let whiteTee = TeeDistance(teeColor: "White", distanceYards: whiteDistances[i])
            
            hole.teeDistances.append(goldTee)
            hole.teeDistances.append(whiteTee)
            
            course.holes.append(hole)
        }
        
        // Add tee sets
        let teeSets = [
            TeeSet(teeColor: "Gold", slope: 141.0, rating: 74.5),
            TeeSet(teeColor: "White", slope: 130.0, rating: 69.0)
        ]
        
        for teeSet in teeSets {
            course.teeSets.append(teeSet)
        }
        
        context.insert(course)
        return course
    }
}

