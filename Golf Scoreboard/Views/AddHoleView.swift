//
//  AddHoleView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct AddHoleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let course: GolfCourse
    
    @State private var holeNumber = 1
    @State private var par = 4
    @State private var handicap = 1
    
    var body: some View {
        NavigationView {
            Form {
                Section("Hole Details") {
                    Stepper("Hole Number: \(holeNumber)", value: $holeNumber, in: 1...18)
                    
                    Stepper("Par: \(par)", value: $par, in: 3...5)
                    
                    Stepper("Handicap: \(handicap)", value: $handicap, in: 1...18)
                }
            }
            .navigationTitle("Add Hole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addHole()
                    }
                }
            }
        }
    }
    
    private func addHole() {
        let hole = Hole(holeNumber: holeNumber, par: par, mensHandicap: handicap)
        if course.holes == nil { course.holes = [] }
        course.holes!.append(hole)
        
        modelContext.insert(hole)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GolfCourse.self, configurations: config)
    let course = GolfCourse(name: "Test Course")
    
    return AddHoleView(course: course)
        .modelContainer(container)
}

