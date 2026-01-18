import SwiftUI
import SwiftData

struct KanjiDetailView: View {
    let kanji: Kanji
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var progressList: [KanjiProgress]
    @Query private var userSettings: [UserSettings]
    @State private var mnemonic: String = ""
    @State private var isGeneratingMnemonic = false
    @State private var isGeneratingImage = false
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    @State private var remoteImages: [RemoteImage] = []

    private var progress: KanjiProgress? {
        progressList.first { $0.character == kanji.character }
    }

    private var settings: UserSettings? {
        userSettings.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main character card
                CharacterCard(character: kanji.character, meanings: kanji.meanings)

                // Readings section
                ReadingsSection(onyomi: kanji.onyomi, kunyomi: kanji.kunyomi)

                // Radicals section
                if !kanji.radicals.isEmpty {
                    RadicalsCompositionSection(radicals: kanji.radicals)
                }

                // Mnemonic section
                MnemonicSection(
                    mnemonic: $mnemonic,
                    isGenerating: isGeneratingMnemonic,
                    isAuthenticated: authManager.isAuthenticated,
                    errorMessage: errorMessage,
                    onGenerate: generateMnemonic,
                    onSave: saveMnemonic
                )

                // Images section
                ImagesSection(
                    character: kanji.character,
                    remoteImages: remoteImages,
                    isGenerating: isGeneratingImage,
                    isAuthenticated: authManager.isAuthenticated,
                    onGenerateImage: generateImage,
                    onRefresh: loadRemoteImages
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(kanji.character)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let progress = progress {
                    SRSBadge(stage: progress.srs)
                }
            }
        }
        .onAppear {
            if let progress = progress {
                mnemonic = progress.mnemonic ?? ""
            }
            loadRemoteImages()
        }
    }

    private func generateMnemonic() {
        guard authManager.isAuthenticated else {
            errorMessage = "Please sign in to generate mnemonics"
            HapticManager.warning()
            return
        }

        HapticManager.light()
        isGeneratingMnemonic = true
        errorMessage = nil

        Task {
            do {
                let prefs = settings?.aiPreferences ?? AIPreferences()

                let generatedMnemonic = try await APIService.shared.generateMnemonic(
                    character: kanji.character,
                    meanings: kanji.meanings,
                    readings: kanji.allReadings,
                    style: prefs.mnemonicStyle,
                    interests: prefs.personalInterests
                )

                await MainActor.run {
                    mnemonic = generatedMnemonic
                    isGeneratingMnemonic = false
                    HapticManager.success()
                    // Auto-save the generated mnemonic
                    saveMnemonic()
                }
            } catch let error as APIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isGeneratingMnemonic = false
                    HapticManager.error()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGeneratingMnemonic = false
                    HapticManager.error()
                }
            }
        }
    }

    private func saveMnemonic() {
        HapticManager.light()
        if let existing = progress {
            existing.mnemonic = mnemonic
            existing.updatedAt = Date()
        } else {
            let newProgress = KanjiProgress(
                character: kanji.character,
                level: kanji.level,
                mnemonic: mnemonic,
                wanikaniId: kanji.wanikaniId
            )
            modelContext.insert(newProgress)
        }
        try? modelContext.save()
        HapticManager.success()
    }

    private func generateImage() {
        guard authManager.isAuthenticated else {
            errorMessage = "Please sign in to generate images"
            HapticManager.warning()
            return
        }

        guard !mnemonic.isEmpty else {
            errorMessage = "Please add a mnemonic first"
            HapticManager.warning()
            return
        }

        HapticManager.light()
        isGeneratingImage = true
        errorMessage = nil

        Task {
            do {
                let prefs = settings?.aiPreferences ?? AIPreferences()

                let imageUrl = try await APIService.shared.generateImage(
                    character: kanji.character,
                    mnemonic: mnemonic,
                    style: prefs.imageStyle
                )

                // Download and cache the image
                let imageData = try await APIService.shared.downloadImage(from: imageUrl)

                await MainActor.run {
                    // Save to local cache
                    let cachedImage = CachedImage(
                        character: kanji.character,
                        imageData: imageData,
                        isAIGenerated: true,
                        prompt: mnemonic
                    )
                    modelContext.insert(cachedImage)
                    try? modelContext.save()

                    isGeneratingImage = false
                    HapticManager.success()

                    // Refresh remote images
                    loadRemoteImages()
                }
            } catch let error as APIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isGeneratingImage = false
                    HapticManager.error()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGeneratingImage = false
                    HapticManager.error()
                }
            }
        }
    }

    private func loadRemoteImages() {
        guard authManager.isAuthenticated else { return }

        Task {
            do {
                let images = try await APIService.shared.getImages(forCharacter: kanji.character)
                await MainActor.run {
                    remoteImages = images
                }
            } catch {
                print("Failed to load remote images: \(error)")
            }
        }
    }
}

struct CharacterCard: View {
    let character: String
    let meanings: [String]

    var body: some View {
        VStack(spacing: 12) {
            Text(character)
                .font(.system(size: 100))

            Text(meanings.joined(separator: ", "))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ReadingsSection: View {
    let onyomi: [String]
    let kunyomi: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readings")
                .font(.headline)

            HStack(spacing: 24) {
                if !onyomi.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("On'yomi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(onyomi.joined(separator: ", "))
                            .font(.body)
                    }
                }

                if !kunyomi.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kun'yomi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(kunyomi.joined(separator: ", "))
                            .font(.body)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct RadicalsCompositionSection: View {
    let radicals: [String]
    @StateObject private var dataManager = DataManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Radicals")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(radicals, id: \.self) { radicalName in
                    VStack {
                        Text(dataManager.getRadicalCharacter(byName: radicalName))
                            .font(.title2)
                        Text(radicalName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct MnemonicSection: View {
    @Binding var mnemonic: String
    let isGenerating: Bool
    let isAuthenticated: Bool
    let errorMessage: String?
    let onGenerate: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mnemonic")
                    .font(.headline)

                Spacer()

                Button(action: onGenerate) {
                    HStack(spacing: 4) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isAuthenticated ? "Generate" : "Sign in")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(isGenerating)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            TextEditor(text: $mnemonic)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Save Mnemonic", action: onSave)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(mnemonic.isEmpty)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ImagesSection: View {
    let character: String
    let remoteImages: [RemoteImage]
    let isGenerating: Bool
    let isAuthenticated: Bool
    let onGenerateImage: () -> Void
    let onRefresh: () -> Void

    @Query private var cachedImages: [CachedImage]

    private var localImages: [CachedImage] {
        cachedImages.filter { $0.character == character }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.headline)

                Spacer()

                Button(action: onGenerateImage) {
                    HStack(spacing: 4) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Generate")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(isGenerating || !isAuthenticated)
            }

            if localImages.isEmpty && remoteImages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No images yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !isAuthenticated {
                        Text("Sign in to generate AI images")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    // Show local cached images
                    ForEach(localImages) { image in
                        if let uiImage = UIImage(data: image.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .bottomTrailing) {
                                    if image.isAIGenerated {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                            .padding(4)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                            .padding(4)
                                    }
                                }
                        }
                    }

                    // Show remote images
                    ForEach(remoteImages) { image in
                        AsyncImage(url: URL(string: image.url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 120)
                            case .success(let loadedImage):
                                loadedImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .bottomTrailing) {
                                        if image.isAIGenerated {
                                            Image(systemName: "sparkles")
                                                .font(.caption)
                                                .padding(4)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                                .padding(4)
                                        }
                                    }
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .frame(height: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct SRSBadge: View {
    let stage: SRSStage

    var body: some View {
        Text(stage.name)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(srsColor.opacity(0.2))
            .foregroundStyle(srsColor)
            .clipShape(Capsule())
    }

    private var srsColor: Color {
        switch stage {
        case .lesson: return .gray
        case .apprentice1, .apprentice2, .apprentice3, .apprentice4: return .pink
        case .guru1, .guru2: return .purple
        case .master: return .blue
        case .enlightened: return .cyan
        case .burned: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        KanjiDetailView(kanji: Kanji(
            character: "一",
            meanings: ["One"],
            onyomi: ["いち", "いつ"],
            kunyomi: ["ひと"],
            radicals: ["Ground"],
            strokeCount: 1,
            wanikaniId: 440,
            level: 1
        ))
        .environmentObject(AuthManager.shared)
    }
    .modelContainer(for: [KanjiProgress.self, CachedImage.self, UserSettings.self], inMemory: true)
}
