import SwiftUI
import SwiftData
import AVFoundation

struct VocabularyDetailView: View {
    let vocabulary: Vocabulary
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var progressList: [VocabularyProgress]
    @Query private var userSettings: [UserSettings]
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var meaningMnemonic: String = ""
    @State private var readingMnemonic: String = ""
    @State private var isGeneratingMnemonic = false
    @State private var isGeneratingImage = false
    @State private var errorMessage: String?
    @State private var remoteImages: [RemoteImage] = []

    private var progress: VocabularyProgress? {
        progressList.first { $0.vocabularyId == vocabulary.id }
    }

    private var settings: UserSettings? {
        userSettings.first
    }

    // Find the component kanji
    private var componentKanji: [Kanji] {
        vocabulary.characters.compactMap { char in
            dataManager.getKanji(byCharacter: String(char))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main vocabulary card
                VStack(spacing: 16) {
                    Text(vocabulary.characters)
                        .font(.system(size: 60))

                    Text(vocabulary.primaryReading)
                        .font(.title2)
                        .foregroundStyle(.green)

                    Text(vocabulary.primaryMeaning)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    // Audio button
                    Button {
                        // For now, we'll use text-to-speech as a fallback
                        audioPlayer.speak(vocabulary.primaryReading)
                    } label: {
                        HStack {
                            Image(systemName: audioPlayer.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            Text("Play")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                    }

                    // SRS badge
                    if let progress = progress {
                        SRSBadge(stage: progress.srs)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Level info
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("📚")
                        Text("Level \(vocabulary.level)")
                            .font(.headline)
                    }

                    Text("Learn the kanji first, then this vocabulary")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // All meanings
                if vocabulary.meanings.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meanings")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(vocabulary.meanings, id: \.meaning) { meaning in
                                Text(meaning.meaning)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(meaning.primary ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                                    .clipShape(Capsule())
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

                // All readings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Readings")
                        .font(.headline)

                    FlowLayout(spacing: 8) {
                        ForEach(vocabulary.readings, id: \.reading) { reading in
                            HStack(spacing: 4) {
                                Text(reading.reading)
                                if reading.primary {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(reading.primary ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Component Kanji section
                if !componentKanji.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🔤")
                            Text("Component Kanji")
                                .font(.headline)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(componentKanji) { kanji in
                                NavigationLink(destination: KanjiDetailView(kanji: kanji)) {
                                    VStack(spacing: 4) {
                                        Text(kanji.character)
                                            .font(.title)
                                        Text(kanji.primaryMeaning)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.purple.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
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

                // Meaning Mnemonic section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Meaning Mnemonic")
                            .font(.headline)

                        Spacer()

                        Button(action: { generateMnemonic(forMeaning: true) }) {
                            HStack(spacing: 4) {
                                if isGeneratingMnemonic {
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
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .disabled(isGeneratingMnemonic || !authManager.isAuthenticated)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    TextEditor(text: $meaningMnemonic)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Reading Mnemonic section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Reading Mnemonic")
                            .font(.headline)

                        Spacer()

                        Button(action: { generateMnemonic(forMeaning: false) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Generate")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .disabled(isGeneratingMnemonic || !authManager.isAuthenticated)
                    }

                    TextEditor(text: $readingMnemonic)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Save Mnemonics", action: saveMnemonics)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(meaningMnemonic.isEmpty && readingMnemonic.isEmpty)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Images section
                ImagesSection(
                    character: vocabulary.characters,
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
        .navigationTitle(vocabulary.characters)
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
                meaningMnemonic = progress.meaningMnemonic ?? ""
                readingMnemonic = progress.readingMnemonic ?? ""
            }
            loadRemoteImages()
        }
    }

    private func generateMnemonic(forMeaning: Bool) {
        guard authManager.isAuthenticated else {
            errorMessage = "Please sign in to generate mnemonics"
            return
        }

        isGeneratingMnemonic = true
        errorMessage = nil

        Task {
            do {
                let prefs = settings?.aiPreferences ?? AIPreferences()

                let generatedMnemonic = try await APIService.shared.generateMnemonic(
                    character: vocabulary.characters,
                    meanings: vocabulary.allMeanings,
                    readings: vocabulary.allReadings,
                    style: prefs.mnemonicStyle,
                    interests: prefs.personalInterests
                )

                await MainActor.run {
                    if forMeaning {
                        meaningMnemonic = generatedMnemonic
                    } else {
                        readingMnemonic = generatedMnemonic
                    }
                    isGeneratingMnemonic = false
                    saveMnemonics()
                }
            } catch let error as APIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    isGeneratingMnemonic = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGeneratingMnemonic = false
                }
            }
        }
    }

    private func saveMnemonics() {
        if let existing = progress {
            existing.meaningMnemonic = meaningMnemonic.isEmpty ? nil : meaningMnemonic
            existing.readingMnemonic = readingMnemonic.isEmpty ? nil : readingMnemonic
            existing.updatedAt = Date()
        } else {
            let newProgress = VocabularyProgress(vocabularyId: vocabulary.id)
            newProgress.meaningMnemonic = meaningMnemonic.isEmpty ? nil : meaningMnemonic
            newProgress.readingMnemonic = readingMnemonic.isEmpty ? nil : readingMnemonic
            modelContext.insert(newProgress)
        }
        try? modelContext.save()
    }

    private func generateImage() {
        guard authManager.isAuthenticated else {
            errorMessage = "Please sign in to generate images"
            HapticManager.warning()
            return
        }

        let mnemonic = meaningMnemonic.isEmpty ? readingMnemonic : meaningMnemonic
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
                    character: vocabulary.characters,
                    mnemonic: mnemonic,
                    style: prefs.imageStyle
                )

                // Download and cache the image
                let imageData = try await APIService.shared.downloadImage(from: imageUrl)

                await MainActor.run {
                    // Save to local cache
                    let cachedImage = CachedImage(
                        character: vocabulary.characters,
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
                let images = try await APIService.shared.getImages(forCharacter: vocabulary.characters)
                await MainActor.run {
                    remoteImages = images
                }
            } catch {
                print("Failed to load remote images: \(error)")
            }
        }
    }
}

// Audio player for vocabulary pronunciation
@MainActor
class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        if isPlaying {
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.4

        isPlaying = true
        synthesizer.speak(utterance)

        // Reset after speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isPlaying = false
        }
    }
}

#Preview {
    NavigationStack {
        VocabularyDetailView(vocabulary: Vocabulary(
            id: 2467,
            characters: "一つ",
            meanings: [Meaning(meaning: "One Thing", primary: true)],
            readings: [Reading(reading: "ひとつ", primary: true)],
            level: 1,
            slug: "一つ"
        ))
        .environmentObject(AuthManager.shared)
    }
    .modelContainer(for: [VocabularyProgress.self, UserSettings.self], inMemory: true)
}
