//
//  CalendarManager.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/5/25.
//

import Foundation
import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return granted
        } catch {
            print("Error requesting calendar access: \(error)")
            return false
        }
    }
    
    var hasAccess: Bool {
        authorizationStatus == .authorized
    }
    
    func searchGolfEvents() async -> [GolfCalendarEvent] {
        guard !isLoading else { return [] }
        guard hasAccess else { return [] }
        
        await MainActor.run {
            isLoading = true
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        var golfEvents: [GolfCalendarEvent] = []
        
        // Search from start of today to end of tomorrow
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfToday, end: endOfTomorrow, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            // Look for events with "Golf" in the title
            if event.title?.lowercased().contains("golf") == true {
                let courseName = extractCourseName(from: event.title ?? "")
                let players = parsePlayerNames(from: event.notes ?? "")
                
                golfEvents.append(GolfCalendarEvent(
                    event: event,
                    courseName: courseName,
                    players: players,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location
                ))
            }
        }
        
        // Sort by start date
        golfEvents.sort { $0.startDate < $1.startDate }
        
        return golfEvents
    }
    
    private func extractCourseName(from title: String) -> String {
        // Format is typically "Golf at The Amelia River Club" or just "River Club"
        // Remove "Golf at " prefix if present
        let cleaned = title.replacingOccurrences(of: "Golf at ", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        
        // If empty after cleaning, return original
        return cleaned.isEmpty ? title : cleaned
    }
    
    private func parsePlayerNames(from notes: String) -> [String] {
        // Format is: "Players: Dave Aginsky, Van Garber, Daniel Bonelli, Ted Schultz"
        // Look for "Players:" line
        let lines = notes.components(separatedBy: .newlines)
        
        for line in lines {
            if line.lowercased().contains("players:") {
                // Extract everything after "Players:"
                if let range = line.range(of: "Players:", options: .caseInsensitive) {
                    let playersString = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // Split by comma
                    let names = playersString.components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    return names
                }
            }
        }
        
        return []
    }
}

struct GolfCalendarEvent: Identifiable {
    let id = UUID()
    let event: EKEvent
    let courseName: String
    let players: [String]
    let startDate: Date
    let endDate: Date
    let location: String?
}

