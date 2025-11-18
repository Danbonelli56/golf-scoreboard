//
//  Golf_ScoreboardApp.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

@main
struct Golf_ScoreboardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            GolfCourse.self,
            Hole.self,
            TeeDistance.self,
            TeeSet.self,
            Player.self,
            Game.self,
            HoleScore.self,
            PlayerScore.self,
            Shot.self,
        ])
        // Use versioned schema to allow migrations
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // After successful container creation, validate and migrate existing data if needed
            // Note: SwiftData doesn't support automatic schema migrations for type changes
            // Existing games with old trackingPlayerIDs format will need to be handled
            let allGames = try? container.mainContext.fetch(FetchDescriptor<Game>())
            if let games = allGames {
                var needsSave = false
                for game in games {
                    // Validate trackingPlayerIDs format (should be comma-separated UUID strings)
                    if let ids = game.trackingPlayerIDs, !ids.isEmpty {
                        // Check if it's a valid comma-separated string format
                        let parts = ids.split(separator: ",")
                        let isValid = parts.allSatisfy { UUID(uuidString: String($0)) != nil }
                        if !isValid {
                            // Invalid format - clear it (will be set correctly on next game creation)
                            print("⚠️ Found invalid trackingPlayerIDs format, clearing: \(ids)")
                            game.trackingPlayerIDs = nil
                            needsSave = true
                        }
                    }
                }
                if needsSave {
                    try? container.mainContext.save()
                    print("✅ Migrated trackingPlayerIDs format")
                }
            }
            
            // Check and import default courses if they don't exist
            let allCourses = try? container.mainContext.fetch(FetchDescriptor<GolfCourse>())
            var coursesAdded = false
            
            if let courses = allCourses {
                // Check if Amelia River Club exists, if not, create it
                if !courses.contains(where: { $0.name == "The Amelia River Club" }) {
                    print("📦 Adding The Amelia River Club")
                    _ = CourseImporter.createAmeliaRiverClub(context: container.mainContext)
                    coursesAdded = true
                } else {
                    // Check for Amelia River Club and add gold tees if missing
                    if let ameliaRiver = courses.first(where: { $0.name == "The Amelia River Club" }) {
                        if let holes = ameliaRiver.holes {
                            let allHolesHaveGold = holes.allSatisfy { hole in
                                (hole.teeDistances ?? []).contains { $0.teeColor.lowercased() == "gold" }
                            }
                            if !allHolesHaveGold {
                                print("⚠️ Adding gold tees to Amelia River Club")
                                CourseImporter.addGoldTeesToAmeliaRiverClub(course: ameliaRiver, context: container.mainContext)
                                coursesAdded = true
                            }
                        }
                    }
                }
                
                // Check if North Hampton exists, if not, create it
                if !courses.contains(where: { $0.name == "The Golf Club at North Hampton" }) {
                    print("📦 Adding The Golf Club at North Hampton")
                    _ = CourseImporter.createNorthHamptonGolfClub(context: container.mainContext)
                    coursesAdded = true
                } else {
                    // Check for North Hampton and add white tees if missing
                    if let northHampton = courses.first(where: { $0.name == "The Golf Club at North Hampton" }) {
                        if let holes = northHampton.holes {
                            let allHolesHaveWhite = holes.allSatisfy { hole in
                                (hole.teeDistances ?? []).contains { $0.teeColor.lowercased() == "white" }
                            }
                            if !allHolesHaveWhite {
                                print("⚠️ Adding white tees to North Hampton")
                                CourseImporter.addWhiteTeesToNorthHampton(course: northHampton, context: container.mainContext)
                                coursesAdded = true
                            }
                        }
                    }
                }
                
                // Check if Laurel Island Links exists, if not, create it
                if !courses.contains(where: { $0.name == "Laurel Island Links" }) {
                    print("📦 Adding Laurel Island Links")
                    _ = CourseImporter.createLaurelIslandLinks(context: container.mainContext)
                    coursesAdded = true
                }
                
                // Check if The Club at Osprey Cove exists, if not, create it
                if !courses.contains(where: { $0.name == "The Club at Osprey Cove" }) {
                    print("📦 Adding The Club at Osprey Cove")
                    _ = CourseImporter.createClubAtOspreyCove(context: container.mainContext)
                    coursesAdded = true
                }
                
                if coursesAdded {
                    try? container.mainContext.save()
                    print("✅ Default courses imported")
                } else {
                    print("ℹ️ All default courses already exist")
                }
            }
            
            return container
        } catch {
            // Schema migration error - SwiftData doesn't support automatic migrations for type changes
            // The trackingPlayerIDs property was changed from [String]? to String?
            // This requires resetting the database
            print("❌ ModelContainer creation failed: \(error)")
            print("⚠️ This is likely due to a schema change (trackingPlayerIDs type changed)")
            print("💡 Solution: Delete the app and reinstall, or clear app data in Settings")
            
            // For development: you can also delete the database file manually
            // The database is stored in the app's container
            
            let errorMessage = """
            Database Schema Error
            
            The app's database schema has changed and cannot be automatically migrated.
            
            Error: \(error.localizedDescription)
            
            To fix this:
            1. Delete the app from your device
            2. Reinstall from the App Store
            
            This will reset all data. Your game history and statistics will be lost.
            
            If you're testing/developing, you can also clear the app's data in iOS Settings.
            """
            fatalError(errorMessage)
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
