//
//  StablefordSettingsView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/15/25.
//

import SwiftUI

struct StablefordSettingsView: View {
    @ObservedObject private var settings = StablefordSettings.shared
    
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
                    
                    Text("Settings sync automatically via iCloud across your devices.")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("About")
            }
            
            Section {
                PointValueRow(
                    label: "Double Eagle or Better",
                    description: "3 or more under par",
                    value: $settings.pointsForDoubleEagle
                )
                
                PointValueRow(
                    label: "Eagle",
                    description: "2 under par",
                    value: $settings.pointsForEagle
                )
                
                PointValueRow(
                    label: "Birdie",
                    description: "1 under par",
                    value: $settings.pointsForBirdie
                )
                
                PointValueRow(
                    label: "Par",
                    description: "Even par",
                    value: $settings.pointsForPar
                )
                
                PointValueRow(
                    label: "Bogey",
                    description: "1 over par",
                    value: $settings.pointsForBogey
                )
                
                PointValueRow(
                    label: "Double Bogey or Worse",
                    description: "2 or more over par",
                    value: $settings.pointsForDoubleBogey
                )
            } header: {
                Text("Point Values")
            }
            
            Section {
                Button(action: {
                    settings.resetToDefaults()
                }) {
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

