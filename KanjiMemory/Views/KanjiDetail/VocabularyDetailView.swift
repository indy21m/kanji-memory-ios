import SwiftUI
import SwiftData

struct VocabularyDetailView: View {
    let vocabulary: Vocabulary
    @Environment(\.modelContext) private var modelContext
    @State private var meaningMnemonic: String = ""
    @State private var readingMnemonic: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main vocabulary card
                VStack(spacing: 12) {
                    Text(vocabulary.characters)
                        .font(.system(size: 60))

                    Text(vocabulary.primaryReading)
                        .font(.title2)
                        .foregroundStyle(.purple)

                    Text(vocabulary.primaryMeaning)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // All meanings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meanings")
                        .font(.headline)

                    Text(vocabulary.allMeanings.joined(separator: ", "))
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                // All readings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Readings")
                        .font(.headline)

                    HStack(spacing: 8) {
                        ForEach(vocabulary.readings, id: \.reading) { reading in
                            Text(reading.reading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(reading.primary ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
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

                // Audio section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Audio")
                        .font(.headline)

                    Button {
                        // TODO: Play audio
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Play pronunciation")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(vocabulary.characters)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VocabularyDetailView(vocabulary: Vocabulary(
            id: 2467,
            characters: "一",
            meanings: [Meaning(meaning: "One", primary: true)],
            readings: [Reading(reading: "いち", primary: true)],
            level: 1,
            slug: "一"
        ))
    }
    .modelContainer(for: [VocabularyProgress.self], inMemory: true)
}
