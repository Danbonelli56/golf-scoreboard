//
//  AddShotView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct AddShotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let game: Game?
    let holeNumber: Int
    let player: Player?
    
    @State private var selectedPlayer: Player?
    @State private var shotNumber = 1
    @State private var distanceToHole = ""
    @State private var club: String? = nil
    @State private var selectedResult: ShotResult = .straight
    @State private var isPutt = false
    @State private var initialDistanceSet = false
    // New fields for putts
    @State private var puttFeet = ""
    @State private var puttBias: String = "exact" // exact | long | short
    
    var body: some View {
        NavigationView {
            Form {
                Section("Shot Details") {
                    Picker("Player", selection: $selectedPlayer) {
                        if let player = player {
                            Text(player.name).tag(player as Player?)
                        }
                        ForEach(game?.players ?? []) { p in
                            Text(p.name).tag(p as Player?)
                        }
                    }
                    
                    Stepper("Shot Number: \(shotNumber)", value: $shotNumber, in: 1...10)
                    
                    Toggle("Is Putt", isOn: $isPutt)
                }
                
                Section("Shot Information") {
                    TextField("Distance to hole (yards)", text: $distanceToHole)
                        .keyboardType(.numberPad)
                    
                    if isPutt {
                        TextField("Putt length (feet)", text: $puttFeet)
                            .keyboardType(.numberPad)
                        Picker("Putt bias", selection: $puttBias) {
                            Text("Exact").tag("exact")
                            Text("Long").tag("long")
                            Text("Short").tag("short")
                        }
                    }
                    
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
                }
            }
            .navigationTitle("Add Shot")
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
        .onAppear {
            selectedPlayer = player ?? game?.playersArray.first
            
            // Set initial distance based on shot number
            if !initialDistanceSet && shotNumber == 1 {
                setInitialDistance()
                initialDistanceSet = true
            }
        }
    }
    
    private func setInitialDistance() {
        // For the first shot, use the hole's distance (length)
        guard let course = game?.course,
              let holes = course.holes,
              let hole = holes.first(where: { $0.holeNumber == holeNumber }),
              let teeDistances = hole.teeDistances else {
            return
        }
        if let white = teeDistances.first(where: { $0.teeColor.lowercased() == "white" }) {
            distanceToHole = "\(white.distanceYards)"
        } else if let first = teeDistances.first {
            distanceToHole = "\(first.distanceYards)"
        }
    }
    
    private func saveShot() {
        let distance = Int(distanceToHole)
        let puttFeetValue = Int(puttFeet)
        let newShot = Shot(
            player: selectedPlayer,
            holeNumber: holeNumber,
            shotNumber: shotNumber,
            distanceToHole: isPutt && puttFeetValue != nil ? Int(round(Double(puttFeetValue!) / 3.0)) : distance,
            originalDistanceFeet: isPutt ? puttFeetValue : nil,
            club: club,
            result: selectedResult,
            isPutt: isPutt,
            distanceTraveled: nil,
            isPenalty: false,
            isRetaking: false
        )
        
        // Associate the shot with the current game
        newShot.game = game
        
        // Insert and save
        modelContext.insert(newShot)
        try? modelContext.save()
        
        // Recalculate previous shot carry immediately
        if let selectedPlayer, shotNumber > 1 {
            let allShots: [Shot] = (try? modelContext.fetch(FetchDescriptor<Shot>())) ?? []
            let prevShots = allShots.filter { $0.player?.id == selectedPlayer.id && $0.holeNumber == holeNumber }
                .sorted { $0.shotNumber < $1.shotNumber }
            if let prev = prevShots.dropLast().last, let prevRemain = prev.distanceToHole, let currRemain = newShot.distanceToHole {
                var effectiveCurr = Double(currRemain)
                if isPutt, let feet = Int(puttFeet), puttBias == "long" {
                    effectiveCurr = -Double(feet) / 3.0
                }
                prev.distanceTraveled = Int(lround(Double(prevRemain) - effectiveCurr))
                try? modelContext.save()
            }
        }
        
        NotificationCenter.default.post(name: .shotsUpdated, object: nil)
        
        dismiss()
    }
}

#Preview {
    AddShotView(game: nil, holeNumber: 1, player: nil)
        .modelContainer(for: [Shot.self], inMemory: true)
}

