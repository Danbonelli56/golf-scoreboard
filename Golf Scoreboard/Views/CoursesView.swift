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
    @State private var showingImportSheet = false
    @State private var importJSONText = ""
    
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingImportSheet = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    
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
            .sheet(isPresented: $showingImportSheet) {
                ImportCourseView(importJSONText: $importJSONText, onImport: {
                    if !importJSONText.isEmpty {
                        importCourse(from: importJSONText)
                    }
                    showingImportSheet = false
                    importJSONText = ""
                })
            }
            .overlay {
                if courses.isEmpty {
                    EmptyCoursesView()
                }
            }
        }
    }
    
    private func importCourse(from jsonString: String) {
        _ = CourseImporter.importCourseFromJSON(jsonString, context: modelContext)
        try? modelContext.save()
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
    
    private var uniqueTeeColors: [String] {
        let teeColors = Set((course.holes ?? []).flatMap { ($0.teeDistances ?? []).map { $0.teeColor } })
        return teeColors.sorted()
    }
    
    var body: some View {
        Form {
            Section("Course Information") {
                TextField("Course Name", text: $course.name)
                
                Stepper("Slope: \(course.slope)", value: $course.slope, in: 55...155)
                
                Stepper("Rating: \(String(format: "%.1f", course.rating))", value: $course.rating, in: 60.0...80.0, step: 0.1)
            }
            
            Section("Tee Distances") {
                if (course.holes ?? []).isEmpty {
                    Text("No holes defined")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(uniqueTeeColors, id: \.self) { teeColor in
                        TeeDistanceSummary(course: course, teeColor: teeColor)
                    }
                }
            }
            
            Section("Holes") {
                if (course.holes ?? []).isEmpty {
                    Text("No holes defined")
                        .foregroundColor(.secondary)
                } else {
                    ForEach((course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }, id: \.holeNumber) { hole in
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
        let sortedHoles = (course.holes ?? []).sorted { $0.holeNumber < $1.holeNumber }
        for index in offsets {
            modelContext.delete(sortedHoles[index])
        }
        try? modelContext.save()
    }
}

struct TeeDistanceSummary: View {
    let course: GolfCourse
    let teeColor: String
    
    private var front9Total: Int {
        (course.holes ?? []).filter { $0.holeNumber <= 9 }
            .compactMap { hole in
                (hole.teeDistances ?? []).first(where: { $0.teeColor == teeColor })?.distanceYards
            }
            .reduce(0, +)
    }
    
    private var back9Total: Int {
        (course.holes ?? []).filter { $0.holeNumber > 9 }
            .compactMap { hole in
                (hole.teeDistances ?? []).first(where: { $0.teeColor == teeColor })?.distanceYards
            }
            .reduce(0, +)
    }
    
    private var totalYards: Int {
        front9Total + back9Total
    }
    
    var body: some View {
        HStack {
            Text(teeColor.capitalized)
                .fontWeight(.medium)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Front: \(front9Total)")
                Text("Back: \(back9Total)")
                Text("Total: \(totalYards)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct HoleRow: View {
    @Bindable var hole: Hole
    @State private var showingEditHole = false
    
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
            if !(hole.teeDistances ?? []).isEmpty {
                HStack(spacing: 12) {
                    ForEach((hole.teeDistances ?? []).sorted(by: { $0.teeColor < $1.teeColor }), id: \.teeColor) { tee in
                        HStack(spacing: 4) {
                            Text(tee.teeColor.capitalized)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(tee.distanceYards)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showingEditHole) {
            EditHoleView(hole: hole)
        }
        .onTapGesture {
            showingEditHole = true
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

