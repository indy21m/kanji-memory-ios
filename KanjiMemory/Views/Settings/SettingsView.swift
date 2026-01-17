import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @State private var wanikaniApiKey = ""
    @State private var selectedMnemonicStyle: MnemonicStyle = .visual
    @State private var selectedImageStyle: ImageStyle = .minimalist
    @State private var personalInterests = ""
    @State private var showWaniKaniSync = false
    @State private var isSyncing = false

    private var settings: UserSettings {
        if let existing = userSettings.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        try? modelContext.save()
        return newSettings
    }

    var body: some View {
        NavigationStack {
            List {
                // WaniKani section
                Section {
                    SecureField("API Key", text: $wanikaniApiKey)
                        .textContentType(.password)

                    Button {
                        syncWaniKani()
                    } label: {
                        HStack {
                            Text("Sync with WaniKani")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(wanikaniApiKey.isEmpty || isSyncing)
                } header: {
                    Text("WaniKani")
                } footer: {
                    Text("Enter your WaniKani API key to sync your progress. Get it from wanikani.com/settings/personal_access_tokens")
                }

                // AI Preferences section
                Section("AI Preferences") {
                    Picker("Mnemonic Style", selection: $selectedMnemonicStyle) {
                        ForEach(MnemonicStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Picker("Image Style", selection: $selectedImageStyle) {
                        ForEach(ImageStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personal Interests")
                            .font(.subheadline)
                        TextField("e.g., anime, sports, music", text: $personalInterests)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 4)
                }

                // Subscription section
                Section("Subscription") {
                    HStack {
                        Text("Current Plan")
                        Spacer()
                        Text(settings.subscriptionTier.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("AI Generations")
                        Spacer()
                        Text("\(settings.aiGenerationsUsed) / \(settings.subscriptionTier == .premium ? "∞" : "5")")
                            .foregroundStyle(.secondary)
                    }

                    if settings.subscriptionTier == .free {
                        Button("Upgrade to Premium") {
                            // TODO: Show subscription options
                        }
                        .foregroundStyle(.purple)
                    }
                }

                // Data section
                Section("Data") {
                    Button("Clear All Progress") {
                        // TODO: Show confirmation
                    }
                    .foregroundStyle(.red)

                    Button("Export Data") {
                        // TODO: Export data
                    }
                }

                // About section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSettings()
            }
            .onChange(of: selectedMnemonicStyle) { _, _ in saveSettings() }
            .onChange(of: selectedImageStyle) { _, _ in saveSettings() }
            .onChange(of: personalInterests) { _, _ in saveSettings() }
            .onChange(of: wanikaniApiKey) { _, newValue in
                settings.wanikaniApiKey = newValue
                try? modelContext.save()
            }
        }
    }

    private func loadSettings() {
        wanikaniApiKey = settings.wanikaniApiKey ?? ""
        let prefs = settings.aiPreferences
        selectedMnemonicStyle = prefs.mnemonicStyle
        selectedImageStyle = prefs.imageStyle
        personalInterests = prefs.personalInterests
    }

    private func saveSettings() {
        settings.aiPreferences = AIPreferences(
            mnemonicStyle: selectedMnemonicStyle,
            imageStyle: selectedImageStyle,
            personalInterests: personalInterests
        )
        try? modelContext.save()
    }

    private func syncWaniKani() {
        isSyncing = true
        // TODO: Implement WaniKani sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSyncing = false
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSettings.self], inMemory: true)
}
