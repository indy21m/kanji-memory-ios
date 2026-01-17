import SwiftUI
import SwiftData

struct KanjiDetailView: View {
    let kanji: Kanji
    @Environment(\.modelContext) private var modelContext
    @Query private var progressList: [KanjiProgress]
    @State private var mnemonic: String = ""
    @State private var isGeneratingMnemonic = false
    @State private var showImagePicker = false

    private var progress: KanjiProgress? {
        progressList.first { $0.character == kanji.character }
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
                    onGenerate: generateMnemonic,
                    onSave: saveMnemonic
                )

                // Images section
                ImagesSection(character: kanji.character)
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
        }
    }

    private func generateMnemonic() {
        // TODO: Call API to generate mnemonic
        isGeneratingMnemonic = true
        // Simulated delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            mnemonic = "AI generated mnemonic would appear here..."
            isGeneratingMnemonic = false
        }
    }

    private func saveMnemonic() {
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
                        Text("Generate")
                    }
                    .font(.caption)
                }
                .disabled(isGenerating)
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
    @Query private var cachedImages: [CachedImage]

    private var images: [CachedImage] {
        cachedImages.filter { $0.character == character }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Images")
                    .font(.headline)

                Spacer()

                Button {
                    // TODO: Add image
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.caption)
                }
            }

            if images.isEmpty {
                Text("No images yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(images) { image in
                        if let uiImage = UIImage(data: image.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
    }
    .modelContainer(for: [KanjiProgress.self, CachedImage.self], inMemory: true)
}
