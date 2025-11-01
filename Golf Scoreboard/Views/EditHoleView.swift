//
//  EditHoleView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct EditHoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var hole: Hole
    
    @State private var teeColor = "White"
    @State private var distanceYards = ""
    
    let availableTeeColors = ["White", "Red", "Blue", "Black", "Gold", "Green", "Silver"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Existing Tee Distances") {
                    if hole.teeDistances.isEmpty {
                        Text("No tee distances added yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(hole.teeDistances.sorted(by: { $0.teeColor < $1.teeColor }), id: \.teeColor) { tee in
                            HStack {
                                Text(tee.teeColor.capitalized)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("\(tee.distanceYards)")
                                    .foregroundColor(.secondary)
                                Button(role: .destructive) {
                                    deleteTee(tee)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                
                Section("Add Tee Distance") {
                    Picker("Tee Color", selection: $teeColor) {
                        ForEach(availableTeeColors, id: \.self) { color in
                            Text(color).tag(color)
                        }
                    }
                    
                    TextField("Distance (yards)", text: $distanceYards)
                        .keyboardType(.numberPad)
                    
                    Button {
                        addTeeDistance()
                    } label: {
                        Label("Add Tee Distance", systemImage: "plus")
                    }
                    .disabled(distanceYards.isEmpty || Int(distanceYards) == nil)
                }
            }
            .navigationTitle("Edit Hole \(hole.holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addTeeDistance() {
        guard let yards = Int(distanceYards) else { return }
        
        // Check if this tee color already exists for this hole
        if let existingTee = hole.teeDistances.first(where: { $0.teeColor.lowercased() == teeColor.lowercased() }) {
            existingTee.distanceYards = yards
        } else {
            let newTee = TeeDistance(teeColor: teeColor, distanceYards: yards)
            newTee.hole = hole
            hole.teeDistances.append(newTee)
            modelContext.insert(newTee)
        }
        
        try? modelContext.save()
        distanceYards = ""
    }
    
    private func deleteTee(_ tee: TeeDistance) {
        hole.teeDistances.removeAll { $0.teeColor == tee.teeColor }
        modelContext.delete(tee)
        try? modelContext.save()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GolfCourse.self, Hole.self, TeeDistance.self, configurations: config)
    let hole = Hole(holeNumber: 1, par: 4, mensHandicap: 1)
    return EditHoleView(hole: hole)
        .modelContainer(container)
}

