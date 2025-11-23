//
//  StablefordSettings.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import Foundation
import Combine

class StablefordSettings: ObservableObject {
    static let shared = StablefordSettings()
    
    private let store = NSUbiquitousKeyValueStore.default
    
    // Keys for iCloud Key-Value Store
    private let doubleEagleKey = "stablefordPointsDoubleEagle"
    private let eagleKey = "stablefordPointsEagle"
    private let birdieKey = "stablefordPointsBirdie"
    private let parKey = "stablefordPointsPar"
    private let bogeyKey = "stablefordPointsBogey"
    private let doubleBogeyKey = "stablefordPointsDoubleBogey"
    
    // Default values
    private let defaultDoubleEagle = 5
    private let defaultEagle = 4
    private let defaultBirdie = 3
    private let defaultPar = 2
    private let defaultBogey = 1
    private let defaultDoubleBogey = 0
    
    // Published properties for SwiftUI
    @Published var pointsForDoubleEagle: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForDoubleEagle, forKey: doubleEagleKey)
                store.synchronize()
            }
        }
    }
    
    @Published var pointsForEagle: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForEagle, forKey: eagleKey)
                store.synchronize()
            }
        }
    }
    
    @Published var pointsForBirdie: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForBirdie, forKey: birdieKey)
                store.synchronize()
            }
        }
    }
    
    @Published var pointsForPar: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForPar, forKey: parKey)
                store.synchronize()
            }
        }
    }
    
    @Published var pointsForBogey: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForBogey, forKey: bogeyKey)
                store.synchronize()
            }
        }
    }
    
    @Published var pointsForDoubleBogey: Int {
        didSet {
            if !isUpdatingFromCloud {
                store.set(pointsForDoubleBogey, forKey: doubleBogeyKey)
                store.synchronize()
            }
        }
    }
    
    // Flag to prevent write loops when updating from cloud
    private var isUpdatingFromCloud = false
    
    private init() {
        // Initialize with defaults first (required for @Published properties)
        isUpdatingFromCloud = true
        pointsForDoubleEagle = defaultDoubleEagle
        pointsForEagle = defaultEagle
        pointsForBirdie = defaultBirdie
        pointsForPar = defaultPar
        pointsForBogey = defaultBogey
        pointsForDoubleBogey = defaultDoubleBogey
        
        // Migrate from UserDefaults if iCloud doesn't have values yet
        migrateFromUserDefaultsIfNeeded()
        
        // Load values from iCloud Key-Value Store, or use defaults
        pointsForDoubleEagle = store.object(forKey: doubleEagleKey) as? Int ?? defaultDoubleEagle
        pointsForEagle = store.object(forKey: eagleKey) as? Int ?? defaultEagle
        pointsForBirdie = store.object(forKey: birdieKey) as? Int ?? defaultBirdie
        pointsForPar = store.object(forKey: parKey) as? Int ?? defaultPar
        pointsForBogey = store.object(forKey: bogeyKey) as? Int ?? defaultBogey
        pointsForDoubleBogey = store.object(forKey: doubleBogeyKey) as? Int ?? defaultDoubleBogey
        isUpdatingFromCloud = false
        
        // Listen for remote changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }
    
    // Migrate existing UserDefaults values to iCloud Key-Value Store (one-time migration)
    private func migrateFromUserDefaultsIfNeeded() {
        let userDefaults = UserDefaults.standard
        let migrationKey = "stablefordSettingsMigratedToiCloud"
        
        // Check if migration has already been done
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        
        // Check if iCloud already has values (don't overwrite if they exist)
        let hasiCloudValues = store.object(forKey: doubleEagleKey) != nil ||
                             store.object(forKey: eagleKey) != nil ||
                             store.object(forKey: birdieKey) != nil
        
        // Only migrate if UserDefaults has custom values and iCloud doesn't
        if !hasiCloudValues {
            var migrated = false
            
            if let de = userDefaults.object(forKey: doubleEagleKey) as? Int, de != defaultDoubleEagle {
                store.set(de, forKey: doubleEagleKey)
                migrated = true
            }
            if let e = userDefaults.object(forKey: eagleKey) as? Int, e != defaultEagle {
                store.set(e, forKey: eagleKey)
                migrated = true
            }
            if let b = userDefaults.object(forKey: birdieKey) as? Int, b != defaultBirdie {
                store.set(b, forKey: birdieKey)
                migrated = true
            }
            if let p = userDefaults.object(forKey: parKey) as? Int, p != defaultPar {
                store.set(p, forKey: parKey)
                migrated = true
            }
            if let bo = userDefaults.object(forKey: bogeyKey) as? Int, bo != defaultBogey {
                store.set(bo, forKey: bogeyKey)
                migrated = true
            }
            if let db = userDefaults.object(forKey: doubleBogeyKey) as? Int, db != defaultDoubleBogey {
                store.set(db, forKey: doubleBogeyKey)
                migrated = true
            }
            
            if migrated {
                store.synchronize()
            }
        }
        
        // Mark migration as complete
        userDefaults.set(true, forKey: migrationKey)
    }
    
    @objc private func ubiquitousKeyValueStoreDidChange(_ notification: Notification) {
        // Update published properties when changes come from another device
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                self.isUpdatingFromCloud = true
                for key in changedKeys {
                    switch key {
                    case self.doubleEagleKey:
                        self.pointsForDoubleEagle = self.store.object(forKey: key) as? Int ?? self.defaultDoubleEagle
                    case self.eagleKey:
                        self.pointsForEagle = self.store.object(forKey: key) as? Int ?? self.defaultEagle
                    case self.birdieKey:
                        self.pointsForBirdie = self.store.object(forKey: key) as? Int ?? self.defaultBirdie
                    case self.parKey:
                        self.pointsForPar = self.store.object(forKey: key) as? Int ?? self.defaultPar
                    case self.bogeyKey:
                        self.pointsForBogey = self.store.object(forKey: key) as? Int ?? self.defaultBogey
                    case self.doubleBogeyKey:
                        self.pointsForDoubleBogey = self.store.object(forKey: key) as? Int ?? self.defaultDoubleBogey
                    default:
                        break
                    }
                }
                self.isUpdatingFromCloud = false
            }
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

