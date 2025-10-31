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
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        }
        
        guard authorizationStatus == .authorized else {
            throw VoiceRecognitionError.notAuthorized
        }
        
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
        
        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
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
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                Task { @MainActor in
                    self?.recognizedText = result.bestTranscription.formattedString
                }
            }
            
            if let error = error {
                Task { @MainActor in
                    self?.stopListening()
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        
        // Configure audio engine
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        await MainActor.run {
            self.isListening = true
        }
    }
    
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        isListening = false
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

