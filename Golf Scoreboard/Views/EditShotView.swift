//
//  EditShotView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct EditShotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var shot: Shot
    
    @State private var distanceToHole: String
    @State private var club: String?
    @State private var selectedResult: ShotResult
    @State private var isPutt: Bool
    @State private var puttFeet: String = ""
    @State private var puttLengthBias: String = "exact" // exact | long | short
    
    init(shot: Shot) {
        self.shot = shot
        _distanceToHole = State(initialValue: shot.distanceToHole.map { "\($0)" } ?? "")
        _club = State(initialValue: shot.club)
        _selectedResult = State(initialValue: ShotResult(rawValue: shot.result) ?? .straight)
        _isPutt = State(initialValue: shot.isPutt)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Shot Details") {
                    HStack {
                        Text("Shot Number")
                        Spacer()
                        Text("\(shot.shotNumber)")
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Distance to hole (yards)", text: $distanceToHole)
                        .keyboardType(.numberPad)
                    
                    Picker("Club", selection: $club) {
                        Text("None").tag(nil as String?)
                        Text("Driver").tag("Driver" as String?)
                        Text("3 Wood").tag("3 Wood" as String?)
                        Text("5 Wood").tag("5 Wood" as String?)
                        Text("3 Hybrid").tag("3 Hybrid" as String?)
                        Text("4 Hybrid").tag("4 Hybrid" as String?)
                        Text("5 Hybrid").tag("5 Hybrid" as String?)
                        Text("3 Iron").tag("3 Iron" as String?)
                        Text("4 Iron").tag("4 Iron" as String?)
                        Text("5 Iron").tag("5 Iron" as String?)
                        Text("6 Iron").tag("6 Iron" as String?)
                        Text("7 Iron").tag("7 Iron" as String?)
                        Text("8 Iron").tag("8 Iron" as String?)
                        Text("9 Iron").tag("9 Iron" as String?)
                        Text("PW").tag("PW" as String?)
                        Text("GW").tag("GW" as String?)
                        Text("SW").tag("SW" as String?)
                        Text("LW").tag("LW" as String?)
                        Text("Putter").tag("Putter" as String?)
                    }
                    
                    Picker("Result", selection: $selectedResult) {
                        ForEach(ShotResult.allCases, id: \.self) { result in
                            Text(result.rawValue).tag(result)
                        }
                    }
                    
                    Toggle("Is Putt", isOn: $isPutt)
                    if isPutt {
                        TextField("Putt length (feet)", text: $puttFeet)
                            .keyboardType(.numberPad)
                        Picker("Putt bias", selection: $puttLengthBias) {
                            Text("Exact").tag("exact")
                            Text("Long").tag("long")
                            Text("Short").tag("short")
                        }
                    }
                    
                    if let traveled = shot.distanceTraveled {
                        HStack {
                            Text("Distance Traveled")
                            Spacer()
                            Text("\(traveled) yards")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveShot()
                    }
                }
            }
        }
    }
    
    private func saveShot() {
        // Update fields for this shot
        if isPutt, let feet = Int(puttFeet), feet > 0 {
            let yards = Int(round(Double(feet) / 3.0))
            shot.distanceToHole = yards
            shot.originalDistanceFeet = feet
        } else {
            shot.distanceToHole = Int(distanceToHole)
            shot.originalDistanceFeet = nil
        }
        shot.club = club
        shot.result = selectedResult.rawValue
        shot.isPutt = isPutt
        
        // Recompute neighbors: previous carry and this shot's carry (if next exists)
        if let player = shot.player {
            let allShots: [Shot] = (try? modelContext.fetch(FetchDescriptor<Shot>())) ?? []
            let shotsForPlayerHole = allShots.filter { $0.player?.id == player.id && $0.holeNumber == shot.holeNumber }
                .sorted { $0.shotNumber < $1.shotNumber }
            if let idx = shotsForPlayerHole.firstIndex(where: { $0.id == shot.id }) {
                // Previous carry
                if idx > 0 {
                    let prev = shotsForPlayerHole[idx - 1]
                    if prev.isPutt == false, let prevRemain = prev.distanceToHole, let currRemain = shot.distanceToHole {
                        let traveled = prevRemain - currRemain
                        prev.distanceTraveled = traveled
                    }
                }
                // This shot's carry based on next remaining
                if idx < shotsForPlayerHole.count - 1 {
                    let next = shotsForPlayerHole[idx + 1]
                    if shot.isPutt == false, let currRemain = shot.distanceToHole, let nextRemain = next.distanceToHole {
                        let thisTraveled = currRemain - nextRemain
                        shot.distanceTraveled = thisTraveled
                    }
                }
            }
        }
        
        try? modelContext.save()
        NotificationCenter.default.post(name: .shotsUpdated, object: nil)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Player.self, configurations: config)
    let player = Player(name: "Test Player", handicap: 5.0)
    
    return EditPlayerView(player: player)
        .modelContainer(container)
}

