import SwiftUI
import SwiftData

struct RadicalDetailView: View {
    let radical: Radical
    @Environment(\.modelContext) private var modelContext
    @State private var mnemonic: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Main radical card
                VStack(spacing: 12) {
                    Text(radical.displayCharacter)
                        .font(.system(size: 100))

                    Text(radical.primaryMeaning)
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
                if radical.meanings.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meanings")
                            .font(.headline)

                        Text(radical.meanings.map { $0.meaning }.joined(separator: ", "))
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }

                // Mnemonic section
                MnemonicSection(
                    mnemonic: $mnemonic,
                    isGenerating: false,
                    onGenerate: { },
                    onSave: { }
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(radical.displayCharacter)
        .navigationBarTitleDisplayMode(.inline)
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
    }
    .modelContainer(for: [RadicalProgress.self], inMemory: true)
}
