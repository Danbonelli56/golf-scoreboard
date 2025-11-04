//
//  AddPlayerView.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 10/29/25.
//

import SwiftUI
import SwiftData
import ContactsUI
import Contacts

struct AddPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var playerName = ""
    @State private var handicapText = "0.0"
    @State private var isCurrentUser = false
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var showingContactPicker = false
    @State private var selectedContact: CNContact?
    
    private var handicap: Double {
        Double(handicapText) ?? 0.0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Player Information") {
                    HStack {
                        TextField("Name", text: $playerName)
                            .textInputAutocapitalization(.words)
                        
                        Button(action: {
                            showingContactPicker = true
                        }) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    TextField("Handicap", text: $handicapText)
                        .keyboardType(.decimalPad)
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    
                    Toggle("Current User", isOn: $isCurrentUser)
                }
                
                if isCurrentUser {
                    Section {
                        Text("This player will be used as the default when no name is provided for shots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addPlayer()
                    }
                    .disabled(playerName.isEmpty)
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPickerView { contact in
                    selectedContact = contact
                    loadContactInfo(contact)
                }
            }
        }
    }
    
    private func loadContactInfo(_ contact: CNContact) {
        // Set name
        let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        if !fullName.isEmpty {
            playerName = fullName
        }
        
        // Get first email address
        if !contact.emailAddresses.isEmpty {
            email = contact.emailAddresses[0].value as String
        }
        
        // Get first phone number
        if !contact.phoneNumbers.isEmpty {
            phoneNumber = contact.phoneNumbers[0].value.stringValue
        }
    }
    
    private func addPlayer() {
        // If marking as current user, unmark any existing current user
        if isCurrentUser {
            let existingPlayers: [Player] = try! modelContext.fetch(FetchDescriptor())
            for player in existingPlayers where player.isCurrentUser {
                player.isCurrentUser = false
            }
        }
        
        let player = Player(
            name: playerName,
            handicap: handicap,
            isCurrentUser: isCurrentUser,
            email: email.isEmpty ? nil : email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
        modelContext.insert(player)
        try? modelContext.save()
        
        dismiss()
    }
}

// Contact Picker View
struct ContactPickerView: UIViewControllerRepresentable {
    let onSelectContact: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelectContact(contact)
            parent.dismiss()
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddPlayerView()
        .modelContainer(for: [Player.self], inMemory: true)
}

