import SwiftUI
import SwiftData

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
    @Query private var userSettings: [UserSettings]
    @State private var wanikaniApiKey = ""
    @State private var selectedMnemonicStyle = "visual"
    @State private var selectedImageStyle = "minimalist"
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
            ScrollView {
                VStack(spacing: 24) {
                    // Header with penguin branding
                    headerSection

                    // WaniKani section
                    wanikaniSection

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

    // MARK: - WaniKani Section
    private var wanikaniSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "WaniKani Integration", emoji: "🦀")

            VStack(spacing: 12) {
                SecureField("API Key", text: $wanikaniApiKey)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)

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

                Text("Get your API key from wanikani.com/settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .alert("Sync Complete", isPresented: $showSyncResult) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = syncError {
                    Text("Error: \(error)")
                } else {
                    Text("Synced \(syncedCount) new kanji from WaniKani")
                }
            }
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
                        Text(settings.subscriptionTier.rawValue.capitalized)
                            .font(.headline)
                    }
                    Spacer()
                    Text(settings.subscriptionTier == .premium ? "∞" : "5")
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

                if settings.subscriptionTier == .free {
                    Button {
                        // TODO: Show subscription options
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
        wanikaniApiKey = settings.wanikaniApiKey ?? ""
        let prefs = settings.aiPreferences
        selectedMnemonicStyle = prefs.mnemonicStyle.rawValue
        selectedImageStyle = prefs.imageStyle.rawValue
        personalInterests = prefs.personalInterests
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
        }
    }

    @State private var syncError: String?
    @State private var syncedCount: Int = 0
    @State private var showSyncResult = false

    private func syncWaniKani() {
        isSyncing = true
        syncError = nil
        syncedCount = 0
        settings.wanikaniApiKey = wanikaniApiKey
        try? modelContext.save()

        // Set the API key for the service
        WaniKaniService.shared.setApiKey(wanikaniApiKey)

        Task {
            do {
                // Fetch all kanji assignments from WaniKani
                let assignments = try await WaniKaniService.shared.fetchAssignments(
                    subjectTypes: ["kanji"]
                )

                // Process assignments on main thread for SwiftData
                await MainActor.run {
                    processWaniKaniAssignments(assignments)
                    isSyncing = false
                    showSyncResult = true
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                    showSyncResult = true
                }
            }
        }
    }

    private func processWaniKaniAssignments(_ assignments: [WaniKaniAssignmentData]) {
        let dataManager = DataManager.shared

        for assignment in assignments {
            let info = assignment.data

            // Find the kanji from bundled data by WaniKani subject ID
            guard let kanji = dataManager.allKanji.first(where: { $0.wanikaniId == info.subjectId }) else {
                continue
            }

            // Check if we already have progress for this kanji
            let character = kanji.character
            let existingProgress = try? modelContext.fetch(
                FetchDescriptor<KanjiProgress>(
                    predicate: #Predicate { $0.character == character }
                )
            ).first

            // Convert WaniKani SRS stage to our SRSStage
            let srsStage = convertWaniKaniSRS(info.srsStage)

            // Parse the available_at date (next review date)
            var nextReviewAt: Date? = nil
            if let availableAtString = info.availableAt {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                nextReviewAt = formatter.date(from: availableAtString)
                // Try without fractional seconds if that fails
                if nextReviewAt == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    nextReviewAt = formatter.date(from: availableAtString)
                }
            }

            // If burned, no next review
            if srsStage == .burned {
                nextReviewAt = nil
            }

            if let existing = existingProgress {
                // Update existing progress
                existing.srs = srsStage
                existing.nextReviewAt = nextReviewAt
                existing.wanikaniId = info.subjectId
                existing.updatedAt = Date()
            } else {
                // Create new progress
                let newProgress = KanjiProgress(
                    character: character,
                    level: kanji.level,
                    srsStage: srsStage,
                    nextReviewAt: nextReviewAt,
                    wanikaniId: info.subjectId
                )
                modelContext.insert(newProgress)
                syncedCount += 1
            }
        }

        try? modelContext.save()
    }

    private func convertWaniKaniSRS(_ stage: Int) -> SRSStage {
        // WaniKani SRS stages: 0=Lesson, 1-4=Apprentice, 5-6=Guru, 7=Master, 8=Enlightened, 9=Burned
        switch stage {
        case 0: return .lesson
        case 1: return .apprentice1
        case 2: return .apprentice2
        case 3: return .apprentice3
        case 4: return .apprentice4
        case 5: return .guru1
        case 6: return .guru2
        case 7: return .master
        case 8: return .enlightened
        case 9: return .burned
        default: return .lesson
        }
    }
}

// MARK: - Style Card
struct StyleCard: View {
    let option: StyleOption
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSettings.self], inMemory: true)
}
