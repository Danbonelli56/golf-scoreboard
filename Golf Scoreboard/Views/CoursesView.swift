//
//  CoursesView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData

struct CoursesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [GolfCourse]
    @State private var showingAddCourse = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(courses) { course in
                    NavigationLink {
                        CourseDetailView(course: course)
                    } label: {
                        CourseRow(course: course)
                    }
                }
                .onDelete(perform: deleteCourses)
            }
            .navigationTitle("Golf Courses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCourse = true
                    } label: {
                        Label("Add Course", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCourse) {
                AddCourseView()
            }
            .overlay {
                if courses.isEmpty {
                    EmptyCoursesView()
                }
            }
        }
    }
    
    private func deleteCourses(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(courses[index])
        }
        try? modelContext.save()
    }
}

struct CourseRow: View {
    let course: GolfCourse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(course.name)
                .font(.headline)
            
            Text("Slope: \(course.slope) | Rating: \(String(format: "%.1f", course.rating))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CourseDetailView: View {
    @Bindable var course: GolfCourse
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddHole = false
    
    var body: some View {
        Form {
            Section("Course Information") {
                TextField("Course Name", text: $course.name)
                
                Stepper("Slope: \(course.slope)", value: $course.slope, in: 55...155)
                
                Stepper("Rating: \(String(format: "%.1f", course.rating))", value: $course.rating, in: 60.0...80.0, step: 0.1)
            }
            
            Section("Holes") {
                if course.holes.isEmpty {
                    Text("No holes defined")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(course.holes.sorted { $0.holeNumber < $1.holeNumber }, id: \.holeNumber) { hole in
                        HoleRow(hole: hole)
                    }
                    .onDelete(perform: deleteHoles)
                }
                
                Button {
                    showingAddHole = true
                } label: {
                    Label("Add Hole", systemImage: "plus")
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddHole) {
            AddHoleView(course: course)
        }
    }
    
    private func deleteHoles(offsets: IndexSet) {
        let sortedHoles = course.holes.sorted { $0.holeNumber < $1.holeNumber }
        for index in offsets {
            modelContext.delete(sortedHoles[index])
        }
        try? modelContext.save()
    }
}

struct HoleRow: View {
    let hole: Hole
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Hole \(hole.holeNumber)")
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Par: \(hole.par)")
                    Text("HCP: \(hole.mensHandicap)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Display tee distances
            if !hole.teeDistances.isEmpty {
                HStack(spacing: 12) {
                    ForEach(hole.teeDistances.sorted(by: { $0.teeColor < $1.teeColor }), id: \.teeColor) { tee in
                        HStack(spacing: 4) {
                            Text(tee.teeColor.capitalized)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(tee.distanceYards)yds")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct EmptyCoursesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Courses")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add a course to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CoursesView()
        .modelContainer(for: [GolfCourse.self], inMemory: true)
}

