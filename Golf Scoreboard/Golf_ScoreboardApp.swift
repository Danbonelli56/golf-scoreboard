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
            
            // Only import courses if database is empty (first launch)
            let allCourses = try? container.mainContext.fetch(FetchDescriptor<GolfCourse>())
            
            if let courses = allCourses, courses.isEmpty {
                print("📦 First launch - importing default courses")
                
                // Check if Amelia River Club already exists, if not, create it
                _ = CourseImporter.createAmeliaRiverClub(context: container.mainContext)
                
                // Check if North Hampton already exists, if not, create it
                _ = CourseImporter.createNorthHamptonGolfClub(context: container.mainContext)
                
                // Check if Laurel Island Links already exists, if not, create it
                _ = CourseImporter.createLaurelIslandLinks(context: container.mainContext)
                
                // Check if The Club at Osprey Cove already exists, if not, create it
                _ = CourseImporter.createClubAtOspreyCove(context: container.mainContext)
                
                try? container.mainContext.save()
                print("✅ Default courses imported")
            } else {
                print("ℹ️ Courses already exist in database")
                // Check for North Hampton and add white tees if missing
                if let courses = allCourses, let northHampton = courses.first(where: { $0.name == "The Golf Club at North Hampton" }) {
                    if let holes = northHampton.holes {
                        let allHolesHaveWhite = holes.allSatisfy { hole in
                            (hole.teeDistances ?? []).contains { $0.teeColor.lowercased() == "white" }
                        }
                        if !allHolesHaveWhite {
                            print("⚠️ Adding white tees to North Hampton")
                            CourseImporter.addWhiteTeesToNorthHampton(course: northHampton, context: container.mainContext)
                            try? container.mainContext.save()
                        }
                    }
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
