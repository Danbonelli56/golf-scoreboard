//
//  ContentView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [GolfCourse.self, Player.self, Game.self], inMemory: true)
}
