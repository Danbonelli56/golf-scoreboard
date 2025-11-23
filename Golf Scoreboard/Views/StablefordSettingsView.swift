//
//  StablefordSettingsView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import SwiftUI

struct StablefordSettingsView: View {
    @State private var doubleEaglePoints: Int
    @State private var eaglePoints: Int
    @State private var birdiePoints: Int
    @State private var parPoints: Int
    @State private var bogeyPoints: Int
    @State private var doubleBogeyPoints: Int
    
    init() {
        let settings = StablefordSettings.shared
        _doubleEaglePoints = State(initialValue: settings.pointsForDoubleEagle)
        _eaglePoints = State(initialValue: settings.pointsForEagle)
        _birdiePoints = State(initialValue: settings.pointsForBirdie)
        _parPoints = State(initialValue: settings.pointsForPar)
        _bogeyPoints = State(initialValue: settings.pointsForBogey)
        _doubleBogeyPoints = State(initialValue: settings.pointsForDoubleBogey)
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure point values for each score relative to par in Stableford games.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Default values: Double Eagle = 5, Eagle = 4, Birdie = 3, Par = 2, Bogey = 1, Double Bogey+ = 0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("About")
            }
            
            Section {
                PointValueRow(
                    label: "Double Eagle or Better",
                    description: "3 or more under par",
                    value: $doubleEaglePoints
                )
                
                PointValueRow(
                    label: "Eagle",
                    description: "2 under par",
                    value: $eaglePoints
                )
                
                PointValueRow(
                    label: "Birdie",
                    description: "1 under par",
                    value: $birdiePoints
                )
                
                PointValueRow(
                    label: "Par",
                    description: "Even par",
                    value: $parPoints
                )
                
                PointValueRow(
                    label: "Bogey",
                    description: "1 over par",
                    value: $bogeyPoints
                )
                
                PointValueRow(
                    label: "Double Bogey or Worse",
                    description: "2 or more over par",
                    value: $doubleBogeyPoints
                )
            } header: {
                Text("Point Values")
            }
            
            Section {
                Button(action: resetToDefaults) {
                    HStack {
                        Spacer()
                        Text("Reset to Defaults")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Stableford Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveSettings()
        }
    }
    
    private func saveSettings() {
        let settings = StablefordSettings.shared
        settings.pointsForDoubleEagle = doubleEaglePoints
        settings.pointsForEagle = eaglePoints
        settings.pointsForBirdie = birdiePoints
        settings.pointsForPar = parPoints
        settings.pointsForBogey = bogeyPoints
        settings.pointsForDoubleBogey = doubleBogeyPoints
    }
    
    private func resetToDefaults() {
        doubleEaglePoints = 5
        eaglePoints = 4
        birdiePoints = 3
        parPoints = 2
        bogeyPoints = 1
        doubleBogeyPoints = 0
        saveSettings()
    }
}

struct PointValueRow: View {
    let label: String
    let description: String
    @Binding var value: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Stepper(value: $value, in: 0...20) {
                Text("\(value)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(minWidth: 40)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        StablefordSettingsView()
    }
}

