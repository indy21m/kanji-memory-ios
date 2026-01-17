import SwiftUI
import SwiftData

enum ReviewQuestionType {
    case meaning
    case reading
}

// Track the review state for each item in the session
struct ReviewItemState: Identifiable {
    let id = UUID()
    let progress: KanjiProgress
    let kanji: Kanji?
    var meaningAnswered = false
    var readingAnswered = false
    var meaningCorrect = false
    var readingCorrect = false

    var isComplete: Bool {
        meaningAnswered && readingAnswered
    }
}

struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared

    // Items passed from ReviewsView
    let dueItems: [KanjiProgress]

    @State private var reviewStates: [ReviewItemState] = []
    @State private var currentIndex = 0
    @State private var currentQuestionType: ReviewQuestionType = .meaning
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var sessionComplete = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0

    init(dueItems: [KanjiProgress] = []) {
        self.dueItems = dueItems
    }

    private var currentState: ReviewItemState? {
        guard currentIndex < reviewStates.count else { return nil }
        return reviewStates[currentIndex]
    }

    var body: some View {
        Group {
            if sessionComplete || reviewStates.isEmpty {
                SessionCompleteView(
                    dismiss: dismiss,
                    correctCount: correctCount,
                    incorrectCount: incorrectCount,
                    totalItems: reviewStates.count
                )
            } else if let state = currentState, let kanji = state.kanji {
                ReviewCardView(
                    kanji: kanji,
                    progress: state.progress,
                    questionType: currentQuestionType,
                    userAnswer: $userAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect,
                    currentIndex: currentIndex + 1,
                    totalCount: reviewStates.count,
                    onSubmit: checkAnswer,
                    onNext: nextQuestion
                )
            } else {
                // No kanji data found - skip to next or complete
                VStack {
                    ProgressView()
                    Text("Loading...")
                }
                .onAppear {
                    // Skip items without kanji data
                    nextQuestion()
                }
            }
        }
        .onAppear {
            setupSession()
        }
    }

    private func setupSession() {
        // Create review states for each due item, looking up the Kanji data
        reviewStates = dueItems.compactMap { progress in
            // Find the corresponding Kanji from bundled data
            let kanji = dataManager.allKanji.first { $0.character == progress.character }
            return ReviewItemState(progress: progress, kanji: kanji)
        }

        // Shuffle for variety
        reviewStates.shuffle()

        // Start with meaning questions
        currentQuestionType = .meaning
    }

    private func checkAnswer() {
        guard let state = currentState, let kanji = state.kanji else { return }

        switch currentQuestionType {
        case .meaning:
            let normalizedAnswer = userAnswer.lowercased().trimmingCharacters(in: .whitespaces)
            isCorrect = kanji.meanings.contains { $0.lowercased() == normalizedAnswer }
            reviewStates[currentIndex].meaningAnswered = true
            reviewStates[currentIndex].meaningCorrect = isCorrect
        case .reading:
            let normalizedAnswer = userAnswer.trimmingCharacters(in: .whitespaces)
            isCorrect = kanji.allReadings.contains { $0 == normalizedAnswer }
            reviewStates[currentIndex].readingAnswered = true
            reviewStates[currentIndex].readingCorrect = isCorrect
        }

        if isCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }

        showResult = true
    }

    private func nextQuestion() {
        showResult = false
        userAnswer = ""

        guard currentIndex < reviewStates.count else {
            finishSession()
            return
        }

        let state = reviewStates[currentIndex]

        // Check if current item is complete
        if state.isComplete {
            // Save the result for this item
            saveReviewResult(for: state)

            // Move to next item
            currentIndex += 1
            currentQuestionType = .meaning

            if currentIndex >= reviewStates.count {
                finishSession()
            }
        } else {
            // Still need to answer the other question type
            if currentQuestionType == .meaning && !state.readingAnswered {
                currentQuestionType = .reading
            } else if currentQuestionType == .reading && !state.meaningAnswered {
                currentQuestionType = .meaning
            }
        }
    }

    private func saveReviewResult(for state: ReviewItemState) {
        let progress = state.progress

        // Calculate the new SRS stage based on correctness
        let newStage = SRSCalculator.calculateNextStage(
            currentStage: progress.srs,
            meaningCorrect: state.meaningCorrect,
            readingCorrect: state.readingCorrect
        )

        // Calculate next review date
        let nextReview = SRSCalculator.calculateNextReviewDate(for: newStage)

        // Update the progress record
        progress.srs = newStage
        progress.nextReviewAt = nextReview
        progress.timesReviewed += 1
        if state.meaningCorrect && state.readingCorrect {
            progress.timesCorrect += 1
        }
        progress.updatedAt = Date()

        // Save to database
        try? modelContext.save()
    }

    private func finishSession() {
        sessionComplete = true
    }
}

struct ReviewCardView: View {
    let kanji: Kanji
    let progress: KanjiProgress
    let questionType: ReviewQuestionType
    @Binding var userAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    let currentIndex: Int
    let totalCount: Int
    let onSubmit: () -> Void
    let onNext: () -> Void

    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * CGFloat(currentIndex) / CGFloat(max(totalCount, 1)))
                }
            }
            .frame(height: 4)

            // Question type indicator
            HStack {
                Text(questionType == .meaning ? "Meaning" : "Reading")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(currentIndex)/\(totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(questionType == .meaning ? Color.pink : Color.purple)

            // SRS Stage badge
            HStack {
                SRSBadge(stage: progress.srs)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

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
                    onNext() // This will trigger session completion check
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
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var totalItems: Int = 0

    private var accuracy: Int {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Int(Double(correctCount) / Double(total) * 100)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            if totalItems > 0 {
                VStack(spacing: 16) {
                    HStack(spacing: 32) {
                        VStack {
                            Text("\(correctCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                            Text("Correct")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text("\(incorrectCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            Text("Incorrect")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("\(accuracy)% accuracy")
                        .font(.headline)
                        .foregroundStyle(.purple)
                }
            } else {
                Text("Great job! Keep up the good work.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
        ReviewSessionView(dueItems: [])
    }
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
