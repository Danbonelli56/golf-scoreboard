//
//  CalendarManager.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import EventKit
import SwiftUI

struct CalendarGolfEvent {
    let event: EKEvent
    let playerNames: [String]
    let courseName: String?
    let date: Date
}

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var events: [CalendarGolfEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasFullAccess: Bool {
        // Use the standard authorization status check
        // Note: .authorized is deprecated in iOS 17+ but still works correctly
        // We use the standard API for maximum compatibility
        return authorizationStatus == .authorized
    }
    
    init() {
        // Use the standard API - it works on all iOS versions
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        // Use the standard requestAccess API
        // Note: This is deprecated in iOS 17+ but still works and is simpler
        // The async/await version still works correctly
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
            return granted
        } catch {
            await MainActor.run {
                self.authorizationStatus = .denied
            }
            return false
        }
    }
    
    func searchGolfEvents(withinDays: Int = 2) async {
        // Prevent multiple simultaneous searches
        let currentLoading = await MainActor.run { isLoading }
        if currentLoading {
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Request access if not already granted
        if !hasFullAccess {
            let granted = await requestAccess()
            if !granted {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Calendar access denied. Please enable calendar access in Settings."
                }
                return
            }
        }
        
        // Calculate date range (today + next 2 days)
        let calendar = Calendar.current
        let now = Date()
        // Start from the beginning of today (midnight) to include all of today's events
        let startDate = calendar.startOfDay(for: now)
        // End date is at the end of the day, withinDays days from now
        let endDate = calendar.date(byAdding: .day, value: withinDays, to: startDate) ?? now
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        // Create predicate for events
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endOfDay, calendars: nil)
        let calendarEvents = eventStore.events(matching: predicate)
        
        // Filter for events from "Schedule Golf" app
        // Schedule Golf typically creates events with a specific calendar or title pattern
        // We'll search for events that might be golf-related
        var golfEvents: [CalendarGolfEvent] = []
        
        for event in calendarEvents {
            // Check if event is from Schedule Golf app
            // Schedule Golf might use a specific calendar name or we can identify by patterns
            let calendarTitle = event.calendar.title.lowercased()
            let eventTitle = event.title?.lowercased() ?? ""
            
            // Look for Schedule Golf calendar or golf-related keywords
            // Also check if event has location and notes (typical golf event structure)
            let hasLocation = event.location != nil && !event.location!.trimmingCharacters(in: .whitespaces).isEmpty
            let hasNotes = event.notes != nil && !event.notes!.trimmingCharacters(in: .whitespaces).isEmpty
            
            let isScheduleGolfCalendar = calendarTitle.contains("schedule golf") ||
                                        event.calendar.source.title.lowercased().contains("schedule golf")
            let hasGolfKeywords = calendarTitle.contains("golf") || eventTitle.contains("golf")
            let looksLikeGolfEvent = hasLocation && hasNotes
            
            // Include if: Schedule Golf calendar OR golf keywords OR (has location and notes)
            let isScheduleGolf = isScheduleGolfCalendar || hasGolfKeywords || looksLikeGolfEvent
            
            if isScheduleGolf {
                // Parse player names from notes
                let playerNames = parsePlayerNames(from: event.notes ?? "")
                
                // Extract course name from location
                let courseName = event.location?.trimmingCharacters(in: .whitespaces)
                
                let golfEvent = CalendarGolfEvent(
                    event: event,
                    playerNames: playerNames,
                    courseName: courseName,
                    date: event.startDate
                )
                
                golfEvents.append(golfEvent)
            }
        }
        
        // Sort events before capturing for MainActor
        let sortedEvents = golfEvents.sorted { $0.date < $1.date }
        let isEmpty = sortedEvents.isEmpty
        
        await MainActor.run {
            self.events = sortedEvents
            isLoading = false
            
            if isEmpty {
                errorMessage = "No golf events found in the next \(withinDays) days."
            }
        }
    }
    
    private func parsePlayerNames(from notes: String) -> [String] {
        guard !notes.isEmpty else { return [] }
        
        // Schedule Golf app format is consistent:
        // "Pickup Time: 9:00 AM\nplayers: Dave Aginsky, Daniel Bonelli"
        // Format: Newline-separated, with "players:" prefix, comma-separated names
        
        // Split by newlines to handle multi-line format
        let lines = notes.components(separatedBy: CharacterSet(charactersIn: "\n\r"))
        
        // Find the line with player information (looks for "players:" or "player:")
        var playerLine: String? = nil
        for line in lines {
            let lowerLine = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lowerLine.hasPrefix("players:") || lowerLine.hasPrefix("player:") {
                playerLine = line
                break
            }
        }
        
        // If no specific player line found, try using the whole notes
        guard let textToParse = playerLine ?? (lines.first) else { return [] }
        
        // Remove the "players:" or "player:" prefix (case-insensitive)
        var cleanedText = textToParse.trimmingCharacters(in: .whitespaces)
        let lowerText = cleanedText.lowercased()
        
        if lowerText.hasPrefix("players:") {
            cleanedText = String(cleanedText.dropFirst("players:".count)).trimmingCharacters(in: .whitespaces)
        } else if lowerText.hasPrefix("player:") {
            cleanedText = String(cleanedText.dropFirst("player:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Split by comma (standard delimiter for Schedule Golf app)
        let names = cleanedText.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Clean up and capitalize names properly
        return names.map { name in
            // Capitalize first letter of each word
            let words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            return words.map { word in
                guard !word.isEmpty else { return word }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }.joined(separator: " ")
        }
    }
}

