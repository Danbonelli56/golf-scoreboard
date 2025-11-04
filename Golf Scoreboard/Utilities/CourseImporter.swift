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
        
        // Gold tees distances
        let goldDistances = [551, 371, 385, 206, 557, 382, 218, 396, 420, 366, 384, 196, 587, 360, 356, 431, 164, 548]
        
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
            let goldTee = TeeDistance(teeColor: "Gold", distanceYards: goldDistances[i])
            let blueTee = TeeDistance(teeColor: "Blue", distanceYards: blueDistances[i])
            let blackTee = TeeDistance(teeColor: "Black", distanceYards: blackDistances[i])
            let whiteTee = TeeDistance(teeColor: "White", distanceYards: whiteDistances[i])
            
            if hole.teeDistances == nil { hole.teeDistances = [] }
            hole.teeDistances!.append(goldTee)
            hole.teeDistances!.append(blueTee)
            hole.teeDistances!.append(blackTee)
            hole.teeDistances!.append(whiteTee)
            
            if course.holes == nil { course.holes = [] }
            course.holes!.append(hole)
        }
        
        // Add tee sets with slope and rating
        let teeSets = [
            TeeSet(teeColor: "Gold", slope: 140.0, rating: 73.1),
            TeeSet(teeColor: "Blue", slope: 133.0, rating: 70.5),
            TeeSet(teeColor: "Black", slope: 124.0, rating: 68.5),
            TeeSet(teeColor: "White", slope: 111.0, rating: 66.1)
        ]
        
        if course.teeSets == nil { course.teeSets = [] }
        for teeSet in teeSets {
            course.teeSets!.append(teeSet)
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
            
            if hole.teeDistances == nil { hole.teeDistances = [] }
            hole.teeDistances!.append(goldTee)
            hole.teeDistances!.append(whiteTee)
            
            if course.holes == nil { course.holes = [] }
            course.holes!.append(hole)
        }
        
        // Add tee sets
        let teeSets = [
            TeeSet(teeColor: "Gold", slope: 141.0, rating: 74.5),
            TeeSet(teeColor: "White", slope: 130.0, rating: 69.0)
        ]
        
        if course.teeSets == nil { course.teeSets = [] }
        for teeSet in teeSets {
            course.teeSets!.append(teeSet)
        }
        
        context.insert(course)
        return course
    }
    
    static func addGoldTeesToAmeliaRiverClub(course: GolfCourse, context: ModelContext) {
        // Gold tees distances from scorecard
        let goldDistances = [551, 371, 385, 206, 557, 382, 218, 396, 420, 366, 384, 196, 587, 360, 356, 431, 164, 548]
        
        let holes = (course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }
        for (index, hole) in holes.enumerated() {
            if index < goldDistances.count {
                // Check if gold tee already exists for this hole
                let hasGoldTee = (hole.teeDistances ?? []).contains { $0.teeColor.lowercased() == "gold" }
                if !hasGoldTee {
                    let goldTee = TeeDistance(teeColor: "Gold", distanceYards: goldDistances[index])
                    if hole.teeDistances == nil { hole.teeDistances = [] }
                    hole.teeDistances!.append(goldTee)
                }
            }
        }
        
        // Add gold tee set if it doesn't exist
        let hasGoldTeeSet = (course.teeSets ?? []).contains { $0.teeColor.lowercased() == "gold" }
        if !hasGoldTeeSet {
            let goldTeeSet = TeeSet(teeColor: "Gold", slope: 140.0, rating: 73.1)
            if course.teeSets == nil { course.teeSets = [] }
            course.teeSets!.append(goldTeeSet)
        }
    }
    
    static func addWhiteTeesToNorthHampton(course: GolfCourse, context: ModelContext) {
        // White tees distances from BlueGolf
        let whiteDistances = [342, 549, 154, 385, 335, 455, 159, 308, 322, 274, 352, 472, 372, 155, 492, 355, 122, 365]
        
        let holes = (course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }
        for (index, hole) in holes.enumerated() {
            if index < whiteDistances.count {
                // Check if white tee already exists for this hole
                let hasWhiteTee = (hole.teeDistances ?? []).contains { $0.teeColor.lowercased() == "white" }
                if !hasWhiteTee {
                    let whiteTee = TeeDistance(teeColor: "White", distanceYards: whiteDistances[index])
                    if hole.teeDistances == nil { hole.teeDistances = [] }
                    hole.teeDistances!.append(whiteTee)
                }
            }
        }
        
        // Add white tee set if it doesn't exist
        let hasWhiteTeeSet = (course.teeSets ?? []).contains { $0.teeColor.lowercased() == "white" }
        if !hasWhiteTeeSet {
            let whiteTeeSet = TeeSet(teeColor: "White", slope: 130.0, rating: 69.0)
            if course.teeSets == nil { course.teeSets = [] }
            course.teeSets!.append(whiteTeeSet)
        }
    }
    
    static func createLaurelIslandLinks(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "Laurel Island Links",
            location: "Kingsland, GA",
            slope: 126, // Using White tees as reference
            rating: 70.2
        )
        
        // Par values
        let pars = [4, 4, 3, 5, 4, 5, 4, 3, 4, 4, 3, 4, 5, 4, 5, 4, 3, 4]
        
        // Men's handicaps
        let mensHandicaps = [8, 2, 12, 14, 18, 6, 4, 16, 10, 1, 15, 7, 9, 3, 11, 13, 17, 5]
        
        // White tees distances
        let whiteDistances = [344, 369, 160, 456, 286, 538, 380, 130, 325, 409, 154, 391, 494, 401, 512, 328, 148, 378]
        
        // Green tees distances
        let greenDistances = [320, 336, 135, 440, 256, 481, 340, 109, 307, 365, 118, 345, 398, 335, 459, 295, 129, 328]
        
        // Create holes with distances
        for i in 0..<18 {
            let hole = Hole(
                holeNumber: i + 1,
                par: pars[i],
                mensHandicap: mensHandicaps[i]
            )
            
            // Add tee distances
            let whiteTee = TeeDistance(teeColor: "White", distanceYards: whiteDistances[i])
            let greenTee = TeeDistance(teeColor: "Green", distanceYards: greenDistances[i])
            
            if hole.teeDistances == nil { hole.teeDistances = [] }
            hole.teeDistances!.append(whiteTee)
            hole.teeDistances!.append(greenTee)
            
            if course.holes == nil { course.holes = [] }
            course.holes!.append(hole)
        }
        
        // Add tee sets with slope and rating
        let teeSets = [
            TeeSet(teeColor: "White", slope: 126.0, rating: 70.2),
            TeeSet(teeColor: "Green", slope: 114.0, rating: 67.0)
        ]
        
        if course.teeSets == nil { course.teeSets = [] }
        for teeSet in teeSets {
            course.teeSets!.append(teeSet)
        }
        
        context.insert(course)
        return course
    }
    
    static func createClubAtOspreyCove(context: ModelContext) -> GolfCourse {
        let course = GolfCourse(
            name: "The Club at Osprey Cove",
            location: "St. Marys, GA",
            slope: 125, // Using Gray tees as reference
            rating: 68.5
        )
        
        // Par values
        let pars = [4, 4, 5, 3, 4, 5, 3, 4, 4, 4, 3, 4, 4, 5, 4, 4, 3, 5]
        
        // Men's handicaps
        let mensHandicaps = [11, 5, 1, 17, 15, 7, 13, 3, 9, 10, 18, 16, 6, 4, 2, 8, 14, 12]
        
        // Green tees distances
        let greenDistances = [316, 328, 436, 112, 269, 457, 163, 312, 272, 312, 103, 275, 428, 489, 350, 292, 157, 315]
        
        // Gray tees distances
        let grayDistances = [316, 365, 436, 141, 305, 457, 163, 362, 328, 346, 103, 275, 366, 516, 366, 334, 157, 456]
        
        // Create holes with distances
        for i in 0..<18 {
            let hole = Hole(
                holeNumber: i + 1,
                par: pars[i],
                mensHandicap: mensHandicaps[i]
            )
            
            // Add tee distances
            let greenTee = TeeDistance(teeColor: "Green", distanceYards: greenDistances[i])
            let grayTee = TeeDistance(teeColor: "Gray", distanceYards: grayDistances[i])
            
            if hole.teeDistances == nil { hole.teeDistances = [] }
            hole.teeDistances!.append(greenTee)
            hole.teeDistances!.append(grayTee)
            
            if course.holes == nil { course.holes = [] }
            course.holes!.append(hole)
        }
        
        // Add tee sets with slope and rating
        let teeSets = [
            TeeSet(teeColor: "Green", slope: 122.0, rating: 66.5),
            TeeSet(teeColor: "Gray", slope: 125.0, rating: 68.5)
        ]
        
        if course.teeSets == nil { course.teeSets = [] }
        for teeSet in teeSets {
            course.teeSets!.append(teeSet)
        }
        
        context.insert(course)
        return course
    }
    
    // MARK: - JSON Import/Export
    
    static func exportCourseToJSON(_ course: GolfCourse) -> String? {
        var holesArray: [[String: Any]] = []
        
        let holes = (course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }
        for hole in holes {
            var teeDistancesArray: [[String: Any]] = []
            for tee in hole.teeDistances ?? [] {
                teeDistancesArray.append([
                    "teeColor": tee.teeColor,
                    "distanceYards": tee.distanceYards
                ])
            }
            
            let holeDict: [String: Any] = [
                "holeNumber": hole.holeNumber,
                "par": hole.par,
                "mensHandicap": hole.mensHandicap,
                "ladiesHandicap": hole.ladiesHandicap ?? 0,
                "teeDistances": teeDistancesArray
            ]
            
            holesArray.append(holeDict)
        }
        
        let courseDict: [String: Any] = [
            "name": course.name,
            "location": course.location ?? "",
            "slope": course.slope,
            "rating": course.rating,
            "holes": holesArray
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: courseDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return nil
    }
    
    static func importCourseFromJSON(_ jsonString: String, context: ModelContext) -> GolfCourse? {
        guard let jsonData = jsonString.data(using: .utf8),
              let courseDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let name = courseDict["name"] as? String else {
            return nil
        }
        
        let location = courseDict["location"] as? String
        let slope = courseDict["slope"] as? Int ?? 113
        let rating = courseDict["rating"] as? Double ?? 72.0
        
        let course = GolfCourse(name: name, location: location, slope: slope, rating: rating)
        
        if let holesArray = courseDict["holes"] as? [[String: Any]] {
            for holeDict in holesArray {
                guard let holeNumber = holeDict["holeNumber"] as? Int,
                      let par = holeDict["par"] as? Int,
                      let mensHandicap = holeDict["mensHandicap"] as? Int else {
                    continue
                }
                
                let ladiesHandicap = holeDict["ladiesHandicap"] as? Int
                let hole = Hole(holeNumber: holeNumber, par: par, mensHandicap: mensHandicap, ladiesHandicap: ladiesHandicap)
                
                if let teeDistancesArray = holeDict["teeDistances"] as? [[String: Any]] {
                    for teeDict in teeDistancesArray {
                        if let teeColor = teeDict["teeColor"] as? String,
                           let distanceYards = teeDict["distanceYards"] as? Int {
                            let tee = TeeDistance(teeColor: teeColor, distanceYards: distanceYards)
                            if hole.teeDistances == nil { hole.teeDistances = [] }
                            hole.teeDistances!.append(tee)
                        }
                    }
                }
                
                if course.holes == nil { course.holes = [] }
                course.holes!.append(hole)
            }
        }
        
        context.insert(course)
        return course
    }
}

