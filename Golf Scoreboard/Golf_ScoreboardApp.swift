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
            Shot.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
                
                try? container.mainContext.save()
                print("✅ Default courses imported")
            } else {
                print("ℹ️ Courses already exist in database")
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
