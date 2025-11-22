//
//  PreferencesView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import SwiftUI

struct PreferencesView: View {
    @AppStorage("gemini_api_key") private var geminiAPIKey: String = ""

    var body: some View {
        Form {
            Section {
                SecureField("Gemini API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            } header: {
                Text("Gemini API Configuration")
            } footer: {
                Text("Your Gemini API key is stored securely in your app's preferences. Obtain it from Google AI Studio or OpenRouter.")
            }
        }
        .padding()
        .frame(width: 400, height: 150)
    }
}

#Preview {
    PreferencesView()
}
