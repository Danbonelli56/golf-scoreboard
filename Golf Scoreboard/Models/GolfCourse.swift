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
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var location: String?
    var slope: Int
    var rating: Double
    @Relationship(deleteRule: .cascade) var holes: [Hole]
    @Relationship(deleteRule: .cascade) var teeSets: [TeeSet]
    var createdAt: Date
    
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
    var teeColor: String
    var slope: Double
    var rating: Double
    
    init(teeColor: String, slope: Double, rating: Double) {
        self.teeColor = teeColor
        self.slope = slope
        self.rating = rating
    }
}

@Model
final class Hole {
    var course: GolfCourse?
    var holeNumber: Int
    var par: Int
    var mensHandicap: Int
    var ladiesHandicap: Int?
    @Relationship(deleteRule: .cascade) var teeDistances: [TeeDistance]
    
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
    var teeColor: String // "red", "white", "blue", "black", "gold", "green", etc.
    var distanceYards: Int
    
    init(teeColor: String, distanceYards: Int) {
        self.teeColor = teeColor
        self.distanceYards = distanceYards
    }
}

