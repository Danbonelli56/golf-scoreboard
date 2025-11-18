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
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToScorecard)) { _ in
            // Navigate to scorecard tab (index 0)
            selectedTab = 0
        }
    }
}

// Notification for navigating to scorecard
extension Notification.Name {
    static let navigateToScorecard = Notification.Name("navigateToScorecard")
}

#Preview {
    MainTabView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self, Shot.self, HoleScore.self], inMemory: true)
}

