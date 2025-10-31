//
//  AddCourseView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct AddCourseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var courseName = ""
    @State private var slope = 113
    @State private var rating = 72.0
    
    var body: some View {
        NavigationView {
            Form {
                Section("Course Details") {
                    TextField("Course Name", text: $courseName)
                        .textInputAutocapitalization(.words)
                    
                    Stepper("Slope Rating: \(slope)", value: $slope, in: 55...155)
                    
                    Stepper("Course Rating: \(String(format: "%.1f", rating))", value: $rating, in: 60.0...80.0, step: 0.1)
                }
                
                Section("Holes") {
                    Text("Default 18-hole course with standard pars will be created. You can add detailed information later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createCourse()
                    }
                    .disabled(courseName.isEmpty)
                }
            }
        }
    }
    
    private func createCourse() {
        let course = GolfCourse(name: courseName, slope: slope, rating: rating)
        
        // Create default 18 holes with standard pars
        let defaultPars = [4, 5, 3, 4, 4, 5, 3, 4, 4, 5, 4, 3, 4, 4, 4, 5, 3, 4]
        let defaultHandicaps = [9, 1, 17, 13, 5, 3, 15, 7, 11, 2, 10, 18, 4, 14, 12, 6, 16, 8]
        
        for i in 0..<18 {
            let hole = Hole(
                holeNumber: i + 1,
                par: defaultPars[i],
                mensHandicap: defaultHandicaps[i]
            )
            course.holes.append(hole)
        }
        
        modelContext.insert(course)
        try? modelContext.save()
        
        dismiss()
    }
}

#Preview {
    AddCourseView()
        .modelContainer(for: [GolfCourse.self], inMemory: true)
}

