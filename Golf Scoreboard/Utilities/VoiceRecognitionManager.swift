//
//  VoiceRecognitionManager.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import Foundation
import AVFoundation
import AVFAudio
import Speech

@MainActor
class VoiceRecognitionManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Player names for vocabulary (set dynamically)
    private var playerFirstNames: [String] = []
    private var playerFullNames: [String] = []
    
    // Base golf vocabulary - focused on scoring terms and numbers
    private var baseGolfVocabulary: [String] {
        [
            // Golf scoring terms
            "par", "birdie", "bogey", "eagle", "albatross", "double bogey", "triple bogey",
            "double eagle", "double-bogey", "triple-bogey",
            // Numbers 1-12 (as words)
            "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
            // Numbers 1-12 (as digits - for contextual strings)
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12",
            // Trigger words to auto-submit scores
            "done", "submit", "finished", "enter", "that's it",
            // Command words (including common misheard variations)
            "clear", "hole", "whole", "hold", "delete", "remove"
        ]
    }
    
    // Computed vocabulary that includes player names
    private var golfVocabulary: [String] {
        // Include both first names and full names for better recognition
        // Full names are more distinctive and help avoid confusion with common words
        // Note: Having names multiple times in contextualStrings can help increase their weight
        var vocabulary = baseGolfVocabulary
        
        // Add first names (may add duplicates for short names to increase weight)
        vocabulary.append(contentsOf: playerFirstNames)
        
        // Add full names (more distinctive, less likely to be confused)
        vocabulary.append(contentsOf: playerFullNames)
        
        // For very short first names (3-4 characters), add them again to increase recognition weight
        // This helps the recognizer prioritize player names over common words like "then", "can", etc.
        for firstName in playerFirstNames {
            if firstName.count <= 4 {
                vocabulary.append(firstName) // Add again to increase weight
            }
        }
        
        return vocabulary
    }
    
    // Update player names for vocabulary
    func updatePlayerNames(_ players: [String]) {
        var firstNames: [String] = []
        var fullNames: [String] = []
        var nameVariations: [String] = []
        
        for fullName in players {
            let trimmed = fullName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Add full name (lowercase) - this is more distinctive
            fullNames.append(trimmed.lowercased())
            
            // Extract first name
            let components = trimmed.components(separatedBy: .whitespaces)
            if let firstName = components.first?.trimmingCharacters(in: .whitespaces), !firstName.isEmpty {
                let firstNameLower = firstName.lowercased()
                firstNames.append(firstNameLower)
                
                // Add common variations for short names that might be confused
                // For example, "Dan" might be confused with "then", so we add it multiple times
                // and in different contexts to increase its weight
                if firstNameLower.count <= 4 {
                    // Short names are more likely to be confused, so add them multiple times
                    // This helps the recognizer prioritize them
                    nameVariations.append(firstNameLower)
                    nameVariations.append(firstNameLower)
                }
            }
            
            // Also add last name if available (for cases where first name might be ambiguous)
            if components.count > 1, let lastName = components.last?.trimmingCharacters(in: .whitespaces), !lastName.isEmpty {
                fullNames.append(lastName.lowercased())
            }
        }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        playerFirstNames = firstNames.filter { seen.insert($0).inserted }
        playerFullNames = fullNames.filter { seen.insert($0).inserted }
        
        // Add name variations to help with short names
        // Note: contextualStrings can have duplicates, and having a term multiple times
        // can help increase its weight in recognition
        let allNames = playerFirstNames + playerFullNames + nameVariations
        
        // Debug: Print vocabulary for troubleshooting
        print("🗣️ Updated voice vocabulary:")
        print("   First names: \(playerFirstNames)")
        print("   Full names: \(playerFullNames)")
        print("   Total vocabulary size: \(golfVocabulary.count)")
        print("   All name terms: \(allNames)")
    }
    
    override init() {
        super.init()
        // Try to use on-device recognizer for better performance
        if let onDevice = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
            // Check if supports on-device recognition
            speechRecognizer = onDevice
        } else {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        speechRecognizer?.delegate = self
    }
    
    func requestAuthorization() async {
        let status = SFSpeechRecognizer.authorizationStatus()
        await MainActor.run {
            self.authorizationStatus = status
            if status == .notDetermined {
                SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
                    Task { @MainActor in
                        self?.authorizationStatus = authStatus
                    }
                }
            }
        }
    }
    
    func startListening() async throws {
        // Prevent starting if already listening
        guard !isListening else {
            return
        }
        
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        }
        
        guard authorizationStatus == .authorized else {
            throw VoiceRecognitionError.notAuthorized
        }
        
        // Clean up any existing resources first
        await cleanupResources()
        
        // Request microphone (record) permission if needed
        let audioSession = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            if AVAudioApplication.shared.recordPermission != .granted {
                await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { _ in
                        continuation.resume()
                    }
                }
            }
        } else {
            if audioSession.recordPermission != .granted {
                await withCheckedContinuation { continuation in
                    audioSession.requestRecordPermission { _ in
                        continuation.resume()
                    }
                }
            }
        }
        
        // Check if speech recognizer is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceRecognitionError.audioEngineError
        }
        
        // Configure audio session
        do {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw VoiceRecognitionError.audioEngineError
        }
        
        // Create engine and recognition request
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        let inputNode = audioEngine.inputNode
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        self.recognitionRequest = recognitionRequest
        
        // Add context phrases for better recognition (focused vocabulary)
        // Limited to: player names (first and full), numbers 1-8, and golf scoring terms
        // IMPORTANT: Set contextual strings AFTER creating the request but BEFORE starting recognition
        if #available(iOS 13.0, *) {
            let vocabulary = golfVocabulary
            recognitionRequest.contextualStrings = vocabulary
            print("🗣️ Setting contextual strings with \(vocabulary.count) terms")
            print("   Sample terms: \(vocabulary.prefix(10))")
        }
        
        // Create recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.recognizedText = result.bestTranscription.formattedString
                }
            }
            
            if let error = error {
                // Check if error is cancellation (normal when stopping)
                let nsError = error as NSError
                let isCancelled = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216
                let isServiceUnavailable = nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101
                
                Task { @MainActor in
                    // Only stop and show error if it's not a cancellation
                    if !isCancelled {
                        // Check if we're still listening before stopping (to avoid spam)
                        let wasListening = self.isListening
                        
                        // If service is unavailable, stop listening but don't show error repeatedly
                        if isServiceUnavailable {
                            if wasListening {
                                self.stopListening()
                                // Only show error once to avoid spam
                                if self.errorMessage == nil {
                                    self.errorMessage = "Speech recognition service unavailable"
                                }
                            }
                        } else {
                            if wasListening {
                                self.stopListening()
                                self.errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
        
        // Configure audio engine
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak recognitionRequest] buffer, _ in
            recognitionRequest?.append(buffer)
        }
        
        do {
        audioEngine.prepare()
        try audioEngine.start()
        } catch {
            await cleanupResources()
            throw VoiceRecognitionError.audioEngineError
        }
        
        await MainActor.run {
            self.isListening = true
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        isListening = false
        
        // Cancel recognition task first
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // End recognition request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Deactivate audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore errors when deactivating
        }
        
        // Clean up audio engine
        audioEngine = nil
    }
    
    private func cleanupResources() async {
        await MainActor.run {
            // Cancel any existing recognition task
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Stop and clean up audio engine
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine = nil
            
            // End and clean up recognition request
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            
            // Reset listening state
        isListening = false
        }
    }
    
    func reset() {
        recognizedText = ""
        errorMessage = nil
    }
}

extension VoiceRecognitionManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.errorMessage = "Speech recognition is not available"
            }
        }
    }
}

enum VoiceRecognitionError: LocalizedError {
    case notAuthorized
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .audioEngineError:
            return "Audio engine error"
        }
    }
}

