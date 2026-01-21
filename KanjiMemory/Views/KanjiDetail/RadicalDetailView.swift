import SwiftUI
import SwiftData

struct RadicalDetailView: View {
    let radical: Radical
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @Query private var progressList: [RadicalProgress]
    @Query private var userSettings: [UserSettings]
    @StateObject private var dataManager = DataManager.shared
    @State private var mnemonic: String = ""
    @State private var isGeneratingMnemonic = false
    @State private var isGeneratingImage = false
    @State private var errorMessage: String?
    @State private var remoteImages: [RemoteImage] = []

    private var progress: RadicalProgress? {
        progressList.first { $0.radicalId == radical.id }
    }

    private var settings: UserSettings? {
        userSettings.first
    }

    // Find kanji that use this radical
    private var relatedKanji: [Kanji] {
        dataManager.allKanji.filter { kanji in
            kanji.radicals.contains(radical.primaryMeaning)
        }.prefix(12).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main radical card
                VStack(spacing: 12) {
                    if radical.hasCharacter {
                        Text(radical.displayCharacter)
                            .font(.system(size: 100))
                    } else {
                        // Image-based radical
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Text("部")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(radical.primaryMeaning)
                        .font(.title2)
                        .fontWeight(.semibold)

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
                        Text("Level \(radical.level)")
                            .font(.headline)
                    }

                    Text("Learn this radical to unlock kanji in Level \(radical.level)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // All meanings (if more than one)
                if radical.meanings.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meanings")
                            .font(.headline)

                        FlowLayout(spacing: 8) {
                            ForEach(radical.meanings, id: \.meaning) { meaning in
                                Text(meaning.meaning)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(meaning.primary ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
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

                // Mnemonic section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Mnemonic")
                            .font(.headline)

                        Spacer()

                        Button(action: generateMnemonic) {
                            HStack(spacing: 4) {
                                if isGeneratingMnemonic {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(authManager.isAuthenticated ? "Generate" : "Sign in")
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
                        .disabled(isGeneratingMnemonic)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    TextEditor(text: $mnemonic)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button("Save Mnemonic", action: saveMnemonic)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(mnemonic.isEmpty)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // Images section
                ImagesSection(
                    character: radical.displayCharacter,
                    remoteImages: remoteImages,
                    isGenerating: isGeneratingImage,
                    isAuthenticated: authManager.isAuthenticated,
                    onGenerateImage: generateImage,
                    onRefresh: loadRemoteImages
                )

                // Related kanji section
                if !relatedKanji.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🔗")
                            Text("Used in Kanji")
                                .font(.headline)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(relatedKanji) { kanji in
                                NavigationLink(destination: KanjiDetailView(kanji: kanji)) {
                                    Text(kanji.character)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
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
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(radical.displayCharacter)
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
            return
        }

        isGeneratingMnemonic = true
        errorMessage = nil

        Task {
            do {
                let prefs = settings?.aiPreferences ?? AIPreferences()

                // Generate mnemonic for radical (simpler than kanji)
                let generatedMnemonic = try await APIService.shared.generateMnemonic(
                    character: radical.displayCharacter,
                    meanings: radical.meanings.map { $0.meaning },
                    readings: [], // Radicals don't have readings
                    style: prefs.mnemonicStyle,
                    interests: prefs.personalInterests
                )

                await MainActor.run {
                    mnemonic = generatedMnemonic
                    isGeneratingMnemonic = false
                    saveMnemonic()
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

    private func saveMnemonic() {
        if let existing = progress {
            existing.mnemonic = mnemonic
            existing.updatedAt = Date()
        } else {
            let newProgress = RadicalProgress(radicalId: radical.id)
            newProgress.mnemonic = mnemonic
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
                    character: radical.displayCharacter,
                    mnemonic: mnemonic,
                    style: prefs.imageStyle
                )

                // Download and cache the image
                let imageData = try await APIService.shared.downloadImage(from: imageUrl)

                await MainActor.run {
                    // Save to local cache
                    let cachedImage = CachedImage(
                        character: radical.displayCharacter,
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
                let images = try await APIService.shared.getImages(forCharacter: radical.displayCharacter)
                await MainActor.run {
                    remoteImages = images
                }
            } catch {
                print("Failed to load remote images: \(error)")
            }
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

#Preview {
    NavigationStack {
        RadicalDetailView(radical: Radical(
            id: 1,
            characters: "一",
            image: nil,
            meanings: [Meaning(meaning: "Ground", primary: true)],
            level: 1,
            slug: "ground"
        ))
        .environmentObject(AuthManager.shared)
    }
    .modelContainer(for: [RadicalProgress.self, UserSettings.self], inMemory: true)
}
