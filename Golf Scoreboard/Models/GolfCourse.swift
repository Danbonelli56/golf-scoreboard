//
//  GolfCourse.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import SwiftData

@Model
final class GolfCourse {
    var id: UUID = UUID()
    var name: String = ""
    var location: String?
    var slope: Int = 113
    var rating: Double = 72.0
    @Relationship(deleteRule: .cascade, inverse: \Hole.course) var holes: [Hole]?
    @Relationship(deleteRule: .cascade, inverse: \TeeSet.course) var teeSets: [TeeSet]?
    var games: [Game]?
    var createdAt: Date = Date()
    
    init(name: String, location: String? = nil, slope: Int = 113, rating: Double = 72.0) {
        self.id = UUID()
        self.name = name
        self.location = location
        self.slope = slope
        self.rating = rating
        self.holes = []
        self.teeSets = []
        self.createdAt = Date()
    }
}

@Model
final class TeeSet {
    var course: GolfCourse?
    var teeColor: String = ""
    var slope: Double = 0.0
    var rating: Double = 0.0
    
    init(teeColor: String, slope: Double, rating: Double) {
        self.teeColor = teeColor
        self.slope = slope
        self.rating = rating
    }
}

@Model
final class Hole {
    var course: GolfCourse?
    var holeNumber: Int = 1
    var par: Int = 4
    var mensHandicap: Int = 10
    var ladiesHandicap: Int?
    @Relationship(deleteRule: .cascade, inverse: \TeeDistance.hole) var teeDistances: [TeeDistance]?
    
    init(holeNumber: Int, par: Int, mensHandicap: Int, ladiesHandicap: Int? = nil) {
        self.holeNumber = holeNumber
        self.par = par
        self.mensHandicap = mensHandicap
        self.ladiesHandicap = ladiesHandicap
        self.teeDistances = []
    }
}

@Model
final class TeeDistance {
    var hole: Hole?
    var teeColor: String = ""
    var distanceYards: Int = 0
    
    init(teeColor: String, distanceYards: Int) {
        self.teeColor = teeColor
        self.distanceYards = distanceYards
    }
}

