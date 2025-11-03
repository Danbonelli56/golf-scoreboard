//
//  MainTabView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            ScorecardView()
                .tabItem {
                    Label("Scorecard", systemImage: "list.bullet.rectangle")
                }
            
            ShotTrackingView()
                .tabItem {
                    Label("Shots", systemImage: "target")
                }
            
            ShotStatisticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
            
            GameHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self, Shot.self, HoleScore.self], inMemory: true)
}

