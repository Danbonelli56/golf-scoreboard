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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
