//
//  SettingsView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [GolfCourse]
    @Query private var players: [Player]
    @Query private var games: [Game]
    
    @State private var showingAddCourse = false
    @State private var showingAddPlayer = false
    @State private var editingCourse: GolfCourse?
    @State private var editingPlayer: Player?
    @State private var cloudKitStatus: String = "Checking..."
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    NavigationLink(destination: TutorialView()) {
                        Label("Tutorial", systemImage: "book.fill")
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Help")
                }
                
                Section {
                    // Courses
                    ForEach(courses) { course in
                        NavigationLink(destination: SettingsCourseDetailView(course: course, onEdit: { editingCourse = course }, onDelete: { deleteCourse(course) })) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                
                                Text("\(course.holesArray.count) holes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCourses)
                    
                    Button(action: { showingAddCourse = true }) {
                        Label("Add Course", systemImage: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Courses")
                }
                
                Section {
                    // Players
                    ForEach(players) { player in
                        NavigationLink(destination: PlayerDetailView(player: player, onEdit: { editingPlayer = player }, onDelete: { deletePlayer(player) })) {
                            HStack {
                                Circle()
                                    .fill(player.isCurrentUser ? Color.green : Color.blue)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text(player.name.prefix(1))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                                
                                Text(player.name)
                                    .font(.body)
                                
                                if player.isCurrentUser {
                                    Text("(You)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if player.handicap > 0 {
                                    Text("HCP: \(String(format: "%.1f", player.handicap))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deletePlayers)
                    
                    Button(action: { showingAddPlayer = true }) {
                        Label("Add Player", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Players")
                }
                
                Section {
                    NavigationLink(destination: StablefordSettingsView()) {
                        Label("Stableford Points", systemImage: "star.fill")
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("Game Settings")
                } footer: {
                    Text("Configure point values for Stableford scoring")
                }
                
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appVersion)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Build")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appBuild)")
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("App Information")
                }
                
                Section {
                    HStack {
                        Text("Total Games")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(games.count)")
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("CloudKit Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cloudKitStatus)
                            .fontWeight(.medium)
                            .foregroundColor(cloudKitStatus.contains("Available") ? .green : .orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !cloudKitStatus.contains("Available") {
                            Text("CloudKit Sync Issues:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text("• Ensure both devices use the same Apple ID")
                                .font(.caption)
                            Text("• Enable iCloud Drive in Settings")
                                .font(.caption)
                            Text("• Check internet connection on both devices")
                                .font(.caption)
                        }
                        
                        Text("Schema Migration Issue:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        Text("If sync fails with 'trackingPlayerIDs' errors, CloudKit has old schema records. Reset the CloudKit container in Xcode → Window → CloudKit Dashboard → Select container → Schema → Reset Development Schema (or delete old records).")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Data Sync")
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingAddCourse) {
            AddCourseView()
        }
        .sheet(item: $editingCourse) { course in
            // For now, just show the full course view
            CoursesView()
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView()
        }
            .sheet(item: $editingPlayer) { player in
            EditPlayerView(player: player)
        }
        .onAppear {
            checkCloudKitStatus()
        }
    }
    
    private func checkCloudKitStatus() {
        let container = CKContainer(identifier: "iCloud.DJB.Golf-Scoreboard")
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    cloudKitStatus = "Available"
                case .noAccount:
                    cloudKitStatus = "No iCloud Account"
                case .restricted:
                    cloudKitStatus = "Restricted"
                case .couldNotDetermine:
                    cloudKitStatus = "Unknown"
                case .temporarilyUnavailable:
                    cloudKitStatus = "Temporarily Unavailable"
                @unknown default:
                    cloudKitStatus = "Unknown"
                }
                
                if let error = error {
                    cloudKitStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func deleteCourses(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(courses[index])
        }
    }
    
    private func deletePlayers(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
    }
    
    private func deleteCourse(_ course: GolfCourse) {
        modelContext.delete(course)
    }
    
    private func deletePlayer(_ player: Player) {
        modelContext.delete(player)
    }
}

struct SettingsCourseDetailView: View {
    let course: GolfCourse
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var uniqueTeeColors: [String] {
        let teeColors = Set((course.holes ?? []).flatMap { ($0.teeDistances ?? []).map { $0.teeColor } })
        return teeColors.sorted()
    }
    
    private var sortedHoles: [Hole] {
        (course.holes ?? []).sorted(by: { $0.holeNumber < $1.holeNumber })
    }
    
    private func totalYardage(for teeColor: String) -> Int {
        let allHoles = course.holes ?? []
        var total = 0
        for hole in allHoles {
            if let teeDistance = (hole.teeDistances ?? []).first(where: { $0.teeColor == teeColor }) {
                total += teeDistance.distanceYards
            }
        }
        return total
    }
    
    var body: some View {
        Form {
            Section {
                Text(course.name)
                    .font(.title2)
                    .fontWeight(.bold)
            } header: {
                Text("Course Name")
            }
            
            // Display course summary info if tee sets exist
            if let teeSets = course.teeSets, !teeSets.isEmpty {
                Section {
                    ForEach(teeSets.sorted(by: { $0.teeColor < $1.teeColor }), id: \.teeColor) { teeSet in
                        HStack {
                            Text(teeSet.teeColor)
                                .fontWeight(.semibold)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total: \(totalYardage(for: teeSet.teeColor)) yds")
                                    .fontWeight(.medium)
                                Text("Rating: \(String(format: "%.1f", teeSet.rating))")
                                Text("Slope: \(Int(teeSet.slope))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Tee Sets")
                }
            }
            
            // Display hole details grouped by tee color
            if !uniqueTeeColors.isEmpty {
                ForEach(uniqueTeeColors, id: \.self) { teeColor in
                    Section {
                        ForEach(sortedHoles, id: \.holeNumber) { hole in
                            if let teeDistance = (hole.teeDistances ?? []).first(where: { $0.teeColor == teeColor }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Hole \(hole.holeNumber)")
                                            .fontWeight(.semibold)
                                        Text("Par \(hole.par)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(teeDistance.distanceYards) yds")
                                            .fontWeight(.medium)
                                        if hole.mensHandicap > 0 {
                                            Text("HCP \(hole.mensHandicap)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("\(teeColor) Tees")
                    }
                }
            } else if let holes = course.holes, !holes.isEmpty {
                // Fallback: show basic hole info if no tee distances
                Section {
                    ForEach(sortedHoles, id: \.holeNumber) { hole in
                        HStack {
                            Text("Hole \(hole.holeNumber)")
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("Par \(hole.par)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Holes")
                }
            }
        }
        .navigationTitle("Course Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct PlayerDetailView: View {
    let player: Player
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Circle()
                        .fill(player.isCurrentUser ? Color.green : Color.blue)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(player.name.prefix(1))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if player.isCurrentUser {
                            Text("Current User")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            } header: {
                Text("Player")
            }
            
            Section {
                Text(String(format: "%.1f", player.handicap))
                    .font(.title)
                    .fontWeight(.bold)
            } header: {
                Text("Handicap")
            }
            
            // Contact Information
            if player.email != nil || player.phoneNumber != nil {
                Section {
                    if let email = player.email, !email.isEmpty {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(email)
                                .textSelection(.enabled)
                        }
                    }
                    
                    if let phone = player.phoneNumber, !phone.isEmpty {
                        HStack {
                            Image(systemName: "phone")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text(phone)
                                .textSelection(.enabled)
                        }
                    }
                } header: {
                    Text("Contact Information")
                }
            }
        }
        .navigationTitle("Player Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [GolfCourse.self, Player.self], inMemory: true)
}

