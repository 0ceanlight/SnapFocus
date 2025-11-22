//
//  PreferencesView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import SwiftUI

struct PreferencesView: View {
    @State private var geminiAPIKeyInput: String = ""
    @State private var showSaveMessage: Bool = false
    
    // This is still used by AgenticSchedulerView via @AppStorage
    // We update this indirectly when the save button is pressed.
    @AppStorage("gemini_api_key") private var storedGeminiAPIKey: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    SecureField("Enter Gemini API Key", text: $geminiAPIKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250) // Adjust width to fit button
                    
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(geminiAPIKeyInput.isEmpty)
                }
                
                if showSaveMessage {
                    Text("Key saved!")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            } header: {
                Text("Gemini API Configuration")
            } footer: {
                Text("Your Gemini API key is stored securely in your app's preferences. Obtain it from Google AI Studio or OpenRouter.")
            }
        }
        .padding()
        .frame(width: 400, height: 150)
    }
    
    private func saveAPIKey() {
        storedGeminiAPIKey = geminiAPIKeyInput // Explicitly save to UserDefaults
        geminiAPIKeyInput = "" // Clear the input field
        
        withAnimation {
            showSaveMessage = true
        }
        
        // Hide message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveMessage = false
            }
        }
    }
}

#Preview {
    PreferencesView()
}
