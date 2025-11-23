//
//  StablefordSettings.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import Foundation

class StablefordSettings {
    static let shared = StablefordSettings()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private let doubleEagleKey = "stablefordPointsDoubleEagle"
    private let eagleKey = "stablefordPointsEagle"
    private let birdieKey = "stablefordPointsBirdie"
    private let parKey = "stablefordPointsPar"
    private let bogeyKey = "stablefordPointsBogey"
    private let doubleBogeyKey = "stablefordPointsDoubleBogey"
    
    // Default values (current implementation)
    private let defaultDoubleEagle = 5
    private let defaultEagle = 4
    private let defaultBirdie = 3
    private let defaultPar = 2
    private let defaultBogey = 1
    private let defaultDoubleBogey = 0
    
    // Computed properties for point values
    var pointsForDoubleEagle: Int {
        get {
            if userDefaults.object(forKey: doubleEagleKey) == nil {
                return defaultDoubleEagle
            }
            return userDefaults.integer(forKey: doubleEagleKey)
        }
        set {
            userDefaults.set(newValue, forKey: doubleEagleKey)
        }
    }
    
    var pointsForEagle: Int {
        get {
            if userDefaults.object(forKey: eagleKey) == nil {
                return defaultEagle
            }
            return userDefaults.integer(forKey: eagleKey)
        }
        set {
            userDefaults.set(newValue, forKey: eagleKey)
        }
    }
    
    var pointsForBirdie: Int {
        get {
            if userDefaults.object(forKey: birdieKey) == nil {
                return defaultBirdie
            }
            return userDefaults.integer(forKey: birdieKey)
        }
        set {
            userDefaults.set(newValue, forKey: birdieKey)
        }
    }
    
    var pointsForPar: Int {
        get {
            if userDefaults.object(forKey: parKey) == nil {
                return defaultPar
            }
            return userDefaults.integer(forKey: parKey)
        }
        set {
            userDefaults.set(newValue, forKey: parKey)
        }
    }
    
    var pointsForBogey: Int {
        get {
            if userDefaults.object(forKey: bogeyKey) == nil {
                return defaultBogey
            }
            return userDefaults.integer(forKey: bogeyKey)
        }
        set {
            userDefaults.set(newValue, forKey: bogeyKey)
        }
    }
    
    var pointsForDoubleBogey: Int {
        get {
            if userDefaults.object(forKey: doubleBogeyKey) == nil {
                return defaultDoubleBogey
            }
            return userDefaults.integer(forKey: doubleBogeyKey)
        }
        set {
            userDefaults.set(newValue, forKey: doubleBogeyKey)
        }
    }
    
    // Reset to defaults
    func resetToDefaults() {
        pointsForDoubleEagle = defaultDoubleEagle
        pointsForEagle = defaultEagle
        pointsForBirdie = defaultBirdie
        pointsForPar = defaultPar
        pointsForBogey = defaultBogey
        pointsForDoubleBogey = defaultDoubleBogey
    }
    
    // Calculate points based on score relative to par
    func pointsForScore(scoreRelativeToPar: Int) -> Int {
        switch scoreRelativeToPar {
        case ...(-3): // Double Eagle or better
            return pointsForDoubleEagle
        case -2: // Eagle
            return pointsForEagle
        case -1: // Birdie
            return pointsForBirdie
        case 0: // Par
            return pointsForPar
        case 1: // Bogey
            return pointsForBogey
        default: // Double Bogey or worse
            return pointsForDoubleBogey
        }
    }
    
    private init() {}
}

