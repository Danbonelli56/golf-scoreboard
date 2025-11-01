//
//  ImportCourseView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI

struct ImportCourseView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var importJSONText: String
    var onImport: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Paste JSON course data below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $importJSONText)
                        .frame(minHeight: 300)
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Course JSON")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JSON Format Example:")
                            .fontWeight(.semibold)
                        
                        Text("""
                        {
                          "name": "Course Name",
                          "location": "City, State",
                          "slope": 113,
                          "rating": 72.0,
                          "holes": [
                            {
                              "holeNumber": 1,
                              "par": 4,
                              "mensHandicap": 1,
                              "ladiesHandicap": 0,
                              "teeDistances": [
                                {
                                  "teeColor": "White",
                                  "distanceYards": 350
                                }
                              ]
                            }
                          ]
                        }
                        """)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Format")
                }
                
                Section {
                    Text("Data Sources:")
                        .fontWeight(.semibold)
                    
                    Link(destination: URL(string: "https://www.bluegolf.com")!) {
                        Label("BlueGolf - Free course profiles", systemImage: "link")
                    }
                    
                    Link(destination: URL(string: "https://www.opentee.app")!) {
                        Label("Open Tee - 31,000+ courses", systemImage: "link")
                    }
                    
                    Text("Manually format scorecard data into JSON or copy from existing course exports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Where to Get Course Data")
                }
            }
            .navigationTitle("Import Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        onImport()
                    }
                    .disabled(importJSONText.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ImportCourseView(importJSONText: .constant("")) {
        print("Import tapped")
    }
}

