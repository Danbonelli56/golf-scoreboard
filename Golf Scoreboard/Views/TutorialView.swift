//
//  TutorialView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI

struct TutorialView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice Commands Tutorial")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Learn how to use voice commands to track your golf shots")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Getting Started
                    SectionCard(title: "Getting Started", icon: "play.circle.fill", color: .blue) {
                        TutorialBullet(text: "Tap the microphone button to start voice recognition")
                        TutorialBullet(text: "Speak naturally - the app understands golf terminology")
                        TutorialBullet(text: "Say the player name, club, distance, and result")
                        TutorialBullet(text: "Example: 'Dan Driver 250 yards straight'")
                    }
                    
                    // Basic Shot Commands
                    SectionCard(title: "Basic Shot Commands", icon: "figure.golf", color: .green) {
                        TutorialExample(phrase: "Dan Driver 250 yards straight", description: "Player, club, distance, result")
                        TutorialExample(phrase: "Dave 7 iron 150 yards left", description: "Result can be left, right, or straight")
                        TutorialExample(phrase: "Dan Putter 10 feet straight", description: "Putts use feet instead of yards")
                        TutorialExample(phrase: "Dave 5 iron to hole 180 yards", description: "Alternative distance format")
                    }
                    
                    // Hole Navigation
                    SectionCard(title: "Hole Navigation", icon: "flag.fill", color: .orange) {
                        TutorialExample(phrase: "To hole 5", description: "Switch to hole 5")
                        TutorialExample(phrase: "Hole 5 Dan Driver 250 yards straight", description: "Specify hole in one command")
                    }
                    
                    // Penalties & Hazards
                    SectionCard(title: "Penalties & Hazards", icon: "exclamationmark.triangle.fill", color: .red) {
                        TutorialBullet(text: "Out of Bounds - Options:")
                        TutorialExample(phrase: "Dan Driver OB", description: "Indicates Out of Bounds")
                        TutorialExample(phrase: "Dave Driver out of bounds, hit again from tee", description: "Re-tee with 1 stroke penalty")
                        TutorialExample(phrase: "Dan Driver out of bounds, took a drop", description: "Take a drop with 2 stroke penalty")
                        
                        TutorialBullet(text: "Water Hazard:")
                        TutorialExample(phrase: "Dave Driver 200 yards hazard", description: "In water hazard")
                        
                        TutorialBullet(text: "Trap/Bunker:")
                        TutorialExample(phrase: "Dan 7 iron 150 yards trap", description: "Shot ended in sand trap")
                    }
                    
                    // Putt Modifiers
                    SectionCard(title: "Putt Modifiers", icon: "flag.checkered", color: .purple) {
                        TutorialBullet(text: "Track putt accuracy with modifiers:")
                        TutorialExample(phrase: "Dan Putter 10 feet short", description: "Ball stopped short")
                        TutorialExample(phrase: "Dave Putter 12 feet long", description: "Ball went past the hole")
                        TutorialBullet(text: "End a hole:")
                        TutorialExample(phrase: "Sunk putt", description: "Records putt as holed")
                        TutorialExample(phrase: "Made putt", description: "Alternative phrase")
                    }
                    
                    // Distance Formats
                    SectionCard(title: "Distance Formats", icon: "ruler.fill", color: .cyan) {
                        TutorialBullet(text: "Yards (for non-putts):")
                        TutorialExample(phrase: "250 yards", description: "Full format")
                        TutorialExample(phrase: "250 yds", description: "Abbreviated")
                        
                        TutorialBullet(text: "Feet (for putts):")
                        TutorialExample(phrase: "10 feet", description: "Full format")
                        TutorialExample(phrase: "10 ft", description: "Abbreviated")
                        
                        TutorialBullet(text: "Word numbers are recognized:")
                        TutorialExample(phrase: "two hundred fifty yards", description: "Spells out 250")
                        TutorialExample(phrase: "ten feet", description: "Spells out 10")
                    }
                    
                    // Scoring
                    SectionCard(title: "Scorecard Commands", icon: "square.grid.3x3.fill", color: .indigo) {
                        TutorialExample(phrase: "Dan hole 5 par 4", description: "Record score for hole")
                        TutorialExample(phrase: "Dave hole 3 score 5", description: "Alternative format")
                    }
                    
                    // Tips
                    SectionCard(title: "Pro Tips", icon: "lightbulb.fill", color: .yellow) {
                        TutorialBullet(text: "Speak clearly and at a normal pace")
                        TutorialBullet(text: "Wait for the microphone button to respond before speaking")
                        TutorialBullet(text: "You can add shots incrementally")
                        TutorialBullet(text: "The app tracks club distances automatically")
                        TutorialBullet(text: "Review your stats in the Charts tab")
                    }
                    
                    Spacer()
                        .frame(height: 20)
                }
            }
            .navigationTitle("Tutorial")
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct TutorialBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.secondary)
                .padding(.top, 6)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

struct TutorialExample: View {
    let phrase: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
                .padding(.leading, 18)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.leading, 18)
        }
    }
}

#Preview {
    TutorialView()
}

