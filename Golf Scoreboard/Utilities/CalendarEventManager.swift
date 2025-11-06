//
//  CalendarEventManager.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 11/4/25.
//
//  Manages integration with calendar events created by schedule golf apps.
//  Expected format (consistent across events):
//  - Course name: In event title (e.g., "Golf at The Amelia River Club" or just "The Amelia River Club")
//  - Players: In event notes (e.g., "Players: Dan, Dave, John" or "Dan, Dave, John")
//

import Foundation
import EventKit

struct GolfEvent {
    let course: String
    let players: [String]
    let eventDate: Date
}

@MainActor
class CalendarEventManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        // For iOS 17+, we check authorization differently
        if #available(iOS 17.0, *) {
            // In iOS 17+, authorization is checked via the eventStore's status
            // We'll use the traditional method which still works but is deprecated
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            // Use the new iOS 17+ API
            let status = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = status ? .authorized : .denied
            }
        } else {
            // Use the legacy API for iOS 16 and earlier
            let status = try await eventStore.requestAccess(to: .event)
            await MainActor.run {
                authorizationStatus = status ? .authorized : .denied
            }
        }
    }
    
    /// Fetches golf events for a specific date
    /// Assumes consistent format from schedule golf app:
    /// - Course name is in the event title (or location)
    /// - Player names are in the event notes
    func fetchGolfEvents(for date: Date) async throws -> [GolfEvent] {
        // Check authorization status
        checkAuthorizationStatus()
        guard authorizationStatus == .authorized else {
            throw CalendarError.notAuthorized
        }
        
        // Get start and end of the day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        // Create predicate for events on this date
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var golfEvents: [GolfEvent] = []
        
        print("📅 Checking \(events.count) calendar events for golf events...")
        
        for event in events {
            let eventTitle = event.title ?? "(no title)"
            print("📅 Checking event: '\(eventTitle)'")
            
            // First, check if this looks like a golf event
            // Must have golf-related keywords in title, notes, or location
            if !isGolfEvent(event) {
                print("  ⏭️ Skipping - not a golf event")
                continue
            }
            
            print("  ✅ Looks like a golf event")
            
            // Extract course name from title or location
            let course = extractCourseName(from: event)
            
            // Extract player names from notes
            let players = extractPlayers(from: event)
            
            print("  📍 Course: \(course ?? "none")")
            print("  👥 Players: \(players?.joined(separator: ", ") ?? "none")")
            
            // If we have both course and players, create a golf event
            if let course = course, let players = players, !players.isEmpty {
                print("  ✅ Creating golf event")
                golfEvents.append(GolfEvent(
                    course: course,
                    players: players,
                    eventDate: event.startDate
                ))
            } else {
                print("  ⚠️ Missing course or players - skipping")
            }
        }
        
        print("📅 Found \(golfEvents.count) golf event(s)")
        return golfEvents
    }
    
    /// Checks if an event looks like a golf event
    /// Must contain golf-related keywords in title, notes, or location
    private func isGolfEvent(_ event: EKEvent) -> Bool {
        let title = event.title?.lowercased() ?? ""
        let notes = event.notes?.lowercased() ?? ""
        let location = event.location?.lowercased() ?? ""
        
        let golfKeywords = ["golf", "tee time", "tee", "round", "course", "club", "country club", 
                           "links", "fairway", "greens", "putting", "driving range", "tournament"]
        
        // Check if any golf keyword appears in title, notes, or location
        let combinedText = "\(title) \(notes) \(location)"
        return golfKeywords.contains { keyword in
            combinedText.contains(keyword)
        }
    }
    
    /// Extracts course name from event title or location
    /// Since format is consistent from schedule golf app, we can extract more directly
    private func extractCourseName(from event: EKEvent) -> String? {
        // Check title first (most common location for course name)
        if let title = event.title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
            let lowerTitle = cleanedTitle.lowercased()
            
            // If title contains golf keywords, extract just the course name
            let golfKeywords = ["golf", "course", "club", "round", "tee time", "tee"]
            if golfKeywords.contains(where: { lowerTitle.contains($0) }) {
                // Remove golf-related words to get just the course name
                var courseName = cleanedTitle
                let wordsToRemove = ["golf", "at", "course", "the", "club", "round", "tee time", "tee", "playing"]
                for word in wordsToRemove {
                    let pattern = "\\b\(word)\\b"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        courseName = regex.stringByReplacingMatches(in: courseName, options: [], range: NSRange(courseName.startIndex..., in: courseName), withTemplate: "")
                    }
                }
                // Clean up whitespace and punctuation
                courseName = courseName.trimmingCharacters(in: .whitespaces)
                while courseName.contains("  ") {
                    courseName = courseName.replacingOccurrences(of: "  ", with: " ")
                }
                courseName = courseName.trimmingCharacters(in: CharacterSet(charactersIn: "-–—•·:"))
                
                if !courseName.isEmpty {
                    return courseName
                }
            } else {
                // No golf keywords - assume the title is the course name
                return cleanedTitle
            }
        }
        
        // Check location as fallback
        if let location = event.location, !location.isEmpty {
            return location.trimmingCharacters(in: .whitespaces)
        }
        
        return nil
    }
    
    /// Extracts player names from event notes
    /// Since format is consistent from schedule golf app, we parse more directly
    /// Supports common formats:
    /// - "Players: Dan, Dave, John"
    /// - "Dan, Dave, John" (just names)
    /// - "Dan and Dave and John" (with "and")
    /// - Names on separate lines
    private func extractPlayers(from event: EKEvent) -> [String]? {
        guard let notes = event.notes, !notes.isEmpty else {
            return nil
        }
        
        // Look for a prefix like "Players:", "With:", etc., and extract text after it
        var textToParse = notes
        let playerPrefixes = ["players:", "with:", "playing:", "participants:", "attendees:"]
        
        for prefix in playerPrefixes {
            if let range = notes.lowercased().range(of: prefix) {
                textToParse = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        var playerNames: [String] = []
        
        // Split by newlines first
        let lines = textToParse.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip lines that look like URLs or emails
            let lowerLine = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lowerLine.contains("://") || lowerLine.contains("@") || lowerLine.contains("http") {
                continue
            }
            
            // Split by commas, semicolons, or "and"
            var segments = line.components(separatedBy: CharacterSet(charactersIn: ",;"))
            
            // Also split by "and" or "&"
            segments = segments.flatMap { segment in
                segment.components(separatedBy: " & ")
                    .flatMap { $0.components(separatedBy: " and ") }
                    .flatMap { $0.components(separatedBy: " AND ") }
            }
            
            for segment in segments {
                let trimmed = segment.trimmingCharacters(in: .whitespaces)
                
                // Clean up any bullet points or dashes
                var cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "-–—•·:"))
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                
                // Skip if empty, too short, or looks like non-name text
                if cleaned.isEmpty || cleaned.count < 2 {
                    continue
                }
                
                // Skip if it looks like a URL, email, or common non-name words
                if cleaned.contains("://") || cleaned.contains("@") || cleaned.contains("http") {
                    continue
                }
                
                let skipWords = ["players", "with", "playing", "participants", "attendees", "notes", "course", "time", "date"]
                if skipWords.contains(cleaned.lowercased()) {
                    continue
                }
                
                // Reasonable name length (1-30 characters, 1-3 words)
                let wordCount = cleaned.components(separatedBy: " ").filter { !$0.isEmpty }.count
                if cleaned.count <= 30 && wordCount <= 3 {
                    playerNames.append(cleaned)
                }
            }
        }
        
        // Remove duplicates and sort
        let uniquePlayers = Array(Set(playerNames)).sorted()
        
        return uniquePlayers.isEmpty ? nil : uniquePlayers
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized
    case noEventsFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access is required to import golf events"
        case .noEventsFound:
            return "No golf events found for this date"
        }
    }
}
