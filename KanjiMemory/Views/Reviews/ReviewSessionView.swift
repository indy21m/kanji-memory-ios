import SwiftUI
import SwiftData

enum ReviewQuestionType {
    case meaning
    case reading
}

struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared

    @State private var currentIndex = 0
    @State private var currentQuestionType: ReviewQuestionType = .meaning
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var sessionComplete = false

    // For now, using sample data - will be replaced with actual queue
    private var reviewItems: [Kanji] {
        dataManager.getKanji(byLevel: 1)
    }

    private var currentItem: Kanji? {
        guard currentIndex < reviewItems.count else { return nil }
        return reviewItems[currentIndex]
    }

    var body: some View {
        if sessionComplete {
            SessionCompleteView(dismiss: dismiss)
        } else if let item = currentItem {
            ReviewCardView(
                kanji: item,
                questionType: currentQuestionType,
                userAnswer: $userAnswer,
                showResult: showResult,
                isCorrect: isCorrect,
                onSubmit: checkAnswer,
                onNext: nextQuestion
            )
        } else {
            SessionCompleteView(dismiss: dismiss)
        }
    }

    private func checkAnswer() {
        guard let item = currentItem else { return }

        switch currentQuestionType {
        case .meaning:
            let normalizedAnswer = userAnswer.lowercased().trimmingCharacters(in: .whitespaces)
            isCorrect = item.meanings.contains { $0.lowercased() == normalizedAnswer }
        case .reading:
            let normalizedAnswer = userAnswer.trimmingCharacters(in: .whitespaces)
            isCorrect = item.allReadings.contains { $0 == normalizedAnswer }
        }

        showResult = true
    }

    private func nextQuestion() {
        showResult = false
        userAnswer = ""

        // Alternate between meaning and reading
        if currentQuestionType == .meaning {
            currentQuestionType = .reading
        } else {
            currentQuestionType = .meaning
            currentIndex += 1

            if currentIndex >= reviewItems.count {
                sessionComplete = true
            }
        }
    }
}

struct ReviewCardView: View {
    let kanji: Kanji
    let questionType: ReviewQuestionType
    @Binding var userAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    let onSubmit: () -> Void
    let onNext: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Question type indicator
            Text(questionType == .meaning ? "Meaning" : "Reading")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(questionType == .meaning ? Color.pink : Color.purple)

            // Character
            Text(kanji.character)
                .font(.system(size: 120))
                .padding(.vertical, 40)

            Spacer()

            // Answer section
            VStack(spacing: 16) {
                if showResult {
                    // Show result
                    VStack(spacing: 12) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(isCorrect ? .green : .red)

                        if !isCorrect {
                            Text("Correct answer:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(questionType == .meaning ?
                                 kanji.meanings.joined(separator: ", ") :
                                 kanji.allReadings.joined(separator: ", "))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Button("Continue") {
                            onNext()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isCorrect ? .green : .purple)
                        .padding(.top, 8)
                    }
                    .padding()
                } else {
                    // Input field
                    TextField(
                        questionType == .meaning ? "Enter meaning..." : "Enter reading...",
                        text: $userAnswer
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .focused($isInputFocused)
                    .onSubmit(onSubmit)
                    .padding(.horizontal)

                    Button("Submit") {
                        onSubmit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(userAnswer.isEmpty)
                    .padding()
                }
            }
            .frame(maxHeight: 200)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End") {
                    // TODO: End session
                }
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

struct SessionCompleteView: View {
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("Great job! Keep up the good work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        ReviewSessionView()
    }
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
