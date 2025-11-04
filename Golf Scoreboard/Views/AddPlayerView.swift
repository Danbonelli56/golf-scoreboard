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
    @State private var showingPermissionAlert = false
    
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
                            requestContactsPermissionAndShowPicker()
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
                    loadContactInfo(contact)
                    // Close the contact picker sheet, but keep the AddPlayerView open
                    showingContactPicker = false
                }
            }
            .alert("Contacts Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Contacts access in Settings to import player information.")
            }
        }
    }
    
    private func requestContactsPermissionAndShowPicker() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    showingContactPicker = true
                } else {
                    showingPermissionAlert = true
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
        
        // Save with proper error handling
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving player: \(error)")
            // Still dismiss to avoid hanging - the player might still be created
            dismiss()
        }
    }
}

// Contact Picker View
struct ContactPickerView: UIViewControllerRepresentable {
    let onSelectContact: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> ContactPickerViewControllerWrapper {
        let wrapper = ContactPickerViewControllerWrapper()
        wrapper.onSelectContact = { contact in
            onSelectContact(contact)
        }
        wrapper.onCancel = {
            dismiss()
        }
        return wrapper
    }
    
    func updateUIViewController(_ uiViewController: ContactPickerViewControllerWrapper, context: Context) {}
}

class ContactPickerViewControllerWrapper: UIViewController {
    var onSelectContact: ((CNContact) -> Void)?
    var onCancel: (() -> Void)?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let picker = CNContactPickerViewController()
        picker.delegate = self
        
        // Present the picker modally
        present(picker, animated: true)
    }
}

extension ContactPickerViewControllerWrapper: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        DispatchQueue.main.async {
            // Call the selection handler - the picker will auto-dismiss
            self.onSelectContact?(contact)
        }
    }
    
    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        DispatchQueue.main.async {
            // Only dismiss the parent sheet if cancelled
            self.onCancel?()
        }
    }
}

#Preview {
    AddPlayerView()
        .modelContainer(for: [Player.self], inMemory: true)
}

