import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Style Data
struct StyleOption: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let description: String
}

let mnemonicStyles: [StyleOption] = [
    StyleOption(id: "visual", label: "Visual Imagery", emoji: "🎨", description: "Vivid mental pictures and spatial associations"),
    StyleOption(id: "story", label: "Story-based", emoji: "📚", description: "Memorable narratives with characters"),
    StyleOption(id: "humor", label: "Funny & Absurd", emoji: "😄", description: "Humor and absurd scenarios"),
    StyleOption(id: "personal", label: "Personal", emoji: "💭", description: "Relates to your experiences"),
    StyleOption(id: "logical", label: "Etymology", emoji: "🧠", description: "Component meanings and origins"),
    StyleOption(id: "cultural", label: "Cultural", emoji: "🏯", description: "Japanese culture and history")
]

let imageStyles: [StyleOption] = [
    StyleOption(id: "minimalist", label: "Minimalist", emoji: "⭕", description: "Clean, simple designs"),
    StyleOption(id: "realistic", label: "Realistic", emoji: "📸", description: "Photorealistic illustrations"),
    StyleOption(id: "cartoon", label: "Cartoon/Anime", emoji: "🎌", description: "Manga-inspired artwork"),
    StyleOption(id: "traditional", label: "Traditional", emoji: "🎋", description: "Ukiyo-e art style"),
    StyleOption(id: "abstract", label: "Abstract", emoji: "🌈", description: "Modern, conceptual")
]

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @Query private var userSettings: [UserSettings]
    @State private var wanikaniApiKey = ""
    @State private var selectedMnemonicStyle = "visual"
    @State private var selectedImageStyle = "minimalist"
    @State private var personalInterests = ""
    @State private var showWaniKaniSync = false
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var showSignOutConfirmation = false

    // Review settings (like Tsurukame)
    @State private var readingFirst = true
    @State private var groupMeaningReading = true  // Back-to-back order
    @State private var fuzzyMatchingEnabled = true
    @State private var autoConvertKatakana = true

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
            ScrollView {
                VStack(spacing: 24) {
                    // Header with penguin branding
                    headerSection

                    // Account section (Sign in with Apple)
                    accountSection

                    // WaniKani section - only visible when online
                    if networkMonitor.isConnected {
                        wanikaniSection
                    }

                    // Review Settings section (like Tsurukame)
                    reviewSettingsSection

                    // Mnemonic Style section
                    mnemonicStyleSection

                    // Image Style section
                    imageStyleSection

                    // Personal Interests section
                    interestsSection

                    // Subscription section
                    subscriptionSection

                    // About section
                    aboutSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .onAppear { loadSettings() }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🐧")
                .font(.system(size: 48))
            Text("Penguin Sensei")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("Your AI-powered kanji learning companion")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Account", emoji: "👤")

            VStack(spacing: 12) {
                if authManager.isAuthenticated, let user = authManager.currentUser {
                    // Signed in state
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Signed In")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let email = user.email {
                                Text(email)
                                    .font(.body)
                            }
                            Text(user.tier.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(user.tier == "premium" ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                                .foregroundColor(user.tier == "premium" ? .purple : .secondary)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }

                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                } else {
                    // Signed out state
                    VStack(spacing: 12) {
                        Text("Sign in to sync your progress and use AI features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        if authManager.isLoading {
                            ProgressView()
                                .frame(height: 50)
                        } else {
                            SignInWithAppleButtonView()
                                .environmentObject(authManager)
                        }

                        if let error = authManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - WaniKani Section
    private var wanikaniSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "WaniKani Integration", emoji: "🦀")

            VStack(spacing: 12) {
                SecureField("API Key", text: $wanikaniApiKey)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .onChange(of: wanikaniApiKey) { _, newValue in
                        // Save to Keychain when changed
                        if !newValue.isEmpty {
                            KeychainHelper.saveWaniKaniApiKey(newValue)
                        }
                    }

                Button {
                    syncWaniKani()
                } label: {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "Syncing..." : "Sync Progress")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: wanikaniApiKey.isEmpty ? [.gray] : [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(wanikaniApiKey.isEmpty || isSyncing)

                if let message = syncMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(message.contains("Error") ? .red : .green)
                }

                Text("Get your API key from wanikani.com/settings/personal_access_tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Review Settings Section (like Tsurukame)
    private var reviewSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Review Settings", emoji: "📝")

            VStack(spacing: 0) {
                // Reading First Toggle
                Toggle(isOn: $readingFirst) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading First")
                            .font(.body)
                        Text("Ask reading before meaning (like Tsurukame)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .onChange(of: readingFirst) { _, _ in saveReviewSettings() }

                Divider()
                    .padding(.leading)

                // Back-to-back Order Toggle
                Toggle(isOn: $groupMeaningReading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Back-to-back Order")
                            .font(.body)
                        Text("Keep meaning and reading together for same item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .onChange(of: groupMeaningReading) { _, _ in saveReviewSettings() }

                Divider()
                    .padding(.leading)

                // Fuzzy Matching Toggle
                Toggle(isOn: $fuzzyMatchingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typo Tolerance")
                            .font(.body)
                        Text("Accept close spelling for meanings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .onChange(of: fuzzyMatchingEnabled) { _, _ in saveReviewSettings() }

                Divider()
                    .padding(.leading)

                // Auto Convert Katakana Toggle
                Toggle(isOn: $autoConvertKatakana) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-convert Katakana")
                            .font(.body)
                        Text("Convert カタカナ input to hiragana")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .onChange(of: autoConvertKatakana) { _, _ in saveReviewSettings() }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Mnemonic Style Section
    private var mnemonicStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Mnemonic Style", emoji: "✨")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(mnemonicStyles) { style in
                    StyleCard(
                        option: style,
                        isSelected: selectedMnemonicStyle == style.id,
                        accentColor: .purple
                    ) {
                        selectedMnemonicStyle = style.id
                        saveSettings()
                    }
                }
            }
        }
    }

    // MARK: - Image Style Section
    private var imageStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Image Style", emoji: "🖼️")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(imageStyles) { style in
                    StyleCard(
                        option: style,
                        isSelected: selectedImageStyle == style.id,
                        accentColor: .blue
                    ) {
                        selectedImageStyle = style.id
                        saveSettings()
                    }
                }
            }
        }
    }

    // MARK: - Interests Section
    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Personal Interests", emoji: "💡")

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $personalInterests)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .onChange(of: personalInterests) { _, _ in saveSettings() }

                Text("Share your hobbies to get personalized mnemonics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Subscription", emoji: "⭐")

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Plan")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(authManager.currentUser?.tier.capitalized ?? settings.subscriptionTier.rawValue.capitalized)
                            .font(.headline)
                    }
                    Spacer()
                    Text(authManager.currentUser?.tier == "premium" ? "∞" : "5")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("AI credits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if authManager.currentUser?.tier != "premium" {
                    Button {
                        // TODO: Show subscription options (Apple IAP)
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Upgrade to Premium")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "About", emoji: "ℹ️")

            VStack(spacing: 0) {
                aboutRow(title: "Version", value: "1.0.0")
                Divider()
                aboutLinkRow(title: "Privacy Policy", systemImage: "lock.shield")
                Divider()
                aboutLinkRow(title: "Terms of Service", systemImage: "doc.text")
                Divider()

                Button {
                    // TODO: Clear data confirmation
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Progress")
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Helper Views
    private func sectionHeader(title: String, emoji: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func aboutLinkRow(title: String, systemImage: String) -> some View {
        Button {
            // TODO: Open links
        } label: {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.purple)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    // MARK: - Functions
    private func loadSettings() {
        // Load WaniKani API key from Keychain
        wanikaniApiKey = KeychainHelper.getWaniKaniApiKey() ?? ""

        // Load AI preferences
        let prefs = settings.aiPreferences
        selectedMnemonicStyle = prefs.mnemonicStyle.rawValue
        selectedImageStyle = prefs.imageStyle.rawValue
        personalInterests = prefs.personalInterests

        // Load review settings
        let reviewPrefs = settings.reviewSettings
        readingFirst = reviewPrefs.readingFirst
        groupMeaningReading = reviewPrefs.groupMeaningReading
        fuzzyMatchingEnabled = reviewPrefs.fuzzyMatchingEnabled
        autoConvertKatakana = reviewPrefs.autoConvertKatakana
    }

    private func saveSettings() {
        if let mnemonicStyle = MnemonicStyle(rawValue: selectedMnemonicStyle),
           let imageStyle = ImageStyle(rawValue: selectedImageStyle) {
            settings.aiPreferences = AIPreferences(
                mnemonicStyle: mnemonicStyle,
                imageStyle: imageStyle,
                personalInterests: personalInterests
            )
            try? modelContext.save()

            // Also sync to server if authenticated
            if authManager.isAuthenticated {
                Task {
                    try? await APIService.shared.updatePreferences(preferences: settings.aiPreferences)
                }
            }
        }
    }

    private func saveReviewSettings() {
        settings.reviewSettings = ReviewSettings(
            readingFirst: readingFirst,
            groupMeaningReading: groupMeaningReading,
            fuzzyMatchingEnabled: fuzzyMatchingEnabled,
            autoConvertKatakana: autoConvertKatakana
        )
        try? modelContext.save()
    }

    private func syncWaniKani() {
        guard !wanikaniApiKey.isEmpty else { return }

        HapticManager.light()
        isSyncing = true
        syncMessage = nil

        Task {
            do {
                // Set the API key on the service
                WaniKaniService.shared.setApiKey(wanikaniApiKey)

                // Fetch user info
                let user = try await WaniKaniService.shared.fetchUser()
                print("WaniKani user level: \(user.level)")

                // Fetch ALL assignments (radicals, kanji, vocabulary)
                let assignments = try await WaniKaniService.shared.fetchAssignments(subjectTypes: ["radical", "kanji", "vocabulary"])
                print("Fetched \(assignments.count) total assignments")

                // Get DataManager for looking up items by ID
                let dataManager = await DataManager.shared

                // Group assignments by type
                let radicalAssignments = assignments.filter { $0.data.subjectType == "radical" }
                let kanjiAssignments = assignments.filter { $0.data.subjectType == "kanji" }
                let vocabAssignments = assignments.filter { $0.data.subjectType == "vocabulary" }

                print("Radicals: \(radicalAssignments.count), Kanji: \(kanjiAssignments.count), Vocabulary: \(vocabAssignments.count)")

                // Update progress for each type
                await MainActor.run {
                    var radicalCount = 0
                    var kanjiCount = 0
                    var vocabCount = 0

                    // Process radicals
                    for assignment in radicalAssignments {
                        let subjectId = assignment.data.subjectId
                        let srsStage = assignment.data.srsStage
                        let assignmentId = assignment.id

                        if dataManager.allRadicals.contains(where: { $0.id == subjectId }) {
                            if let progress = fetchRadicalProgress(for: subjectId) {
                                progress.srsStage = srsStage
                                progress.wanikaniAssignmentId = assignmentId
                                progress.nextReviewAt = WaniKaniService.parseDate(assignment.data.availableAt)
                                progress.updatedAt = Date()
                            } else {
                                let newProgress = RadicalProgress(
                                    radicalId: subjectId,
                                    srsStage: SRSStage(rawValue: srsStage) ?? .lesson,
                                    nextReviewAt: WaniKaniService.parseDate(assignment.data.availableAt),
                                    wanikaniAssignmentId: assignmentId
                                )
                                modelContext.insert(newProgress)
                            }
                            radicalCount += 1
                        }
                    }

                    // Process kanji
                    for assignment in kanjiAssignments {
                        let subjectId = assignment.data.subjectId
                        let srsStage = assignment.data.srsStage
                        let assignmentId = assignment.id

                        if let kanji = dataManager.allKanji.first(where: { $0.wanikaniId == subjectId }) {
                            if let progress = fetchKanjiProgress(for: kanji.character) {
                                progress.srsStage = srsStage
                                progress.wanikaniAssignmentId = assignmentId
                                progress.nextReviewAt = WaniKaniService.parseDate(assignment.data.availableAt)
                                progress.updatedAt = Date()
                            } else {
                                let newProgress = KanjiProgress(
                                    character: kanji.character,
                                    level: kanji.level,
                                    srsStage: SRSStage(rawValue: srsStage) ?? .lesson,
                                    nextReviewAt: WaniKaniService.parseDate(assignment.data.availableAt),
                                    wanikaniId: subjectId,
                                    wanikaniAssignmentId: assignmentId
                                )
                                modelContext.insert(newProgress)
                            }
                            kanjiCount += 1
                        }
                    }

                    // Process vocabulary
                    for assignment in vocabAssignments {
                        let subjectId = assignment.data.subjectId
                        let srsStage = assignment.data.srsStage
                        let assignmentId = assignment.id

                        if dataManager.allVocabulary.contains(where: { $0.id == subjectId }) {
                            if let progress = fetchVocabProgress(for: subjectId) {
                                progress.srsStage = srsStage
                                progress.wanikaniAssignmentId = assignmentId
                                progress.nextReviewAt = WaniKaniService.parseDate(assignment.data.availableAt)
                                progress.updatedAt = Date()
                            } else {
                                let newProgress = VocabularyProgress(
                                    vocabularyId: subjectId,
                                    srsStage: SRSStage(rawValue: srsStage) ?? .lesson,
                                    nextReviewAt: WaniKaniService.parseDate(assignment.data.availableAt),
                                    wanikaniAssignmentId: assignmentId
                                )
                                modelContext.insert(newProgress)
                            }
                            vocabCount += 1
                        }
                    }

                    try? modelContext.save()
                    syncMessage = "Synced \(radicalCount) radicals, \(kanjiCount) kanji, \(vocabCount) vocabulary"
                    isSyncing = false
                    HapticManager.success()
                }

            } catch {
                await MainActor.run {
                    syncMessage = "Error: \(error.localizedDescription)"
                    isSyncing = false
                    HapticManager.error()
                }
            }
        }
    }

    private func fetchKanjiProgress(for character: String) -> KanjiProgress? {
        let descriptor = FetchDescriptor<KanjiProgress>(
            predicate: #Predicate { $0.character == character }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchRadicalProgress(for radicalId: Int) -> RadicalProgress? {
        let descriptor = FetchDescriptor<RadicalProgress>(
            predicate: #Predicate { $0.radicalId == radicalId }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchVocabProgress(for vocabularyId: Int) -> VocabularyProgress? {
        let descriptor = FetchDescriptor<VocabularyProgress>(
            predicate: #Predicate { $0.vocabularyId == vocabularyId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

// MARK: - Style Card
struct StyleCard: View {
    let option: StyleOption
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Text(option.emoji)
                    .font(.title2)

                Text(option.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(option.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                        .padding(6)
                }
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
        .modelContainer(for: [UserSettings.self, KanjiProgress.self], inMemory: true)
}
