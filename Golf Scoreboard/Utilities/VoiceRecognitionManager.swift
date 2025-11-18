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
    
    // Golf vocabulary for better recognition
    private let golfVocabulary = [
        // Clubs
        "driver", "putter", "putt", "putting", "wedge", "hybrid", "iron",
        "pitching wedge", "gap wedge", "sand wedge", "lob wedge",
        "three wood", "five wood", "three hybrid", "four hybrid", "five hybrid",
        "three iron", "four iron", "five iron", "six iron", "seven iron", "eight iron", "nine iron",
        // Scores
        "par", "parr", "birdie", "bogey", "eagle", "albatross", "double bogey", "triple bogey",
        // Shot results
        "straight", "right", "left", "out of bounds", "hazard", "sand trap",
        // Golf phrases
        "on the green", "short of the green", "over the green", "short of the pin", "over the pin",
        "down the left side", "down the right side", "in the hole", "sunk putt", "made putt",
        "hole one", "hole two", "hole three", "hole four", "hole five", "hole six",
        "hole seven", "hole eight", "hole nine", "hole ten", "hole eleven", "hole twelve",
        "hole thirteen", "hole fourteen", "hole fifteen", "hole sixteen", "hole seventeen", "hole eighteen",
        // Measurements
        "yards", "feet", "long", "short"
    ]
    
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
        
        // Add context phrases for better recognition
        if #available(iOS 13.0, *) {
            recognitionRequest.contextualStrings = golfVocabulary
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

