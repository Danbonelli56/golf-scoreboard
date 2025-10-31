//
//  TextInputBar.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import AVFoundation

struct TextInputBar: View {
    @Binding var inputText: String
    @Binding var listening: Bool
    
    @StateObject private var voiceManager = VoiceRecognitionManager()
    
    var onCommit: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Button(action: toggleListening) {
                    Image(systemName: listening ? "mic.fill" : "mic")
                        .foregroundColor(listening ? .red : .blue)
                        .font(.title2)
                }
                .padding(.leading)
                
                TextField("Say or type: 'Hole 5, John, 4'", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commit()
                    }
                
                if !inputText.isEmpty {
                    Button(action: commit) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .padding(.trailing)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .onChange(of: voiceManager.recognizedText) { _, newValue in
                // Only mirror speech into the field while actively listening
                if voiceManager.isListening {
                    inputText = newValue
                }
            }
            .onChange(of: voiceManager.isListening) { _, newValue in
                listening = newValue
            }
            .alert(
                "Voice Recognition Error",
                isPresented: Binding(
                    get: { voiceManager.errorMessage != nil },
                    set: { if !$0 { voiceManager.errorMessage = nil } }
                )
            ) {
                Button("OK") { voiceManager.errorMessage = nil }
            } message: {
                Text(voiceManager.errorMessage ?? "Unknown error")
            }
            
        }
        .onAppear {
            Task {
                await voiceManager.requestAuthorization()
            }
        }
    }
    
    private func toggleListening() {
        if listening {
            voiceManager.stopListening()
        } else {
            Task {
                do {
                    try await voiceManager.startListening()
                } catch {
                    voiceManager.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func commit() {
        // Stop mic and freeze transcription before sending
        if listening {
            voiceManager.stopListening()
        }
        // Send the text upstream for parsing
        onCommit()
        // Clear recognition state and text to avoid retyping on next start
        voiceManager.reset()
        inputText = ""
    }
}

#Preview {
    TextInputBar(inputText: .constant(""), listening: .constant(false), onCommit: {})
}

