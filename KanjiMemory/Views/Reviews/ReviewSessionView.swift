import SwiftUI
import SwiftData

enum ReviewQuestionType {
    case meaning
    case reading
}

/// A review item that tracks answers for both meaning and reading
/// Includes wrong counts for accurate WaniKani sync (like Tsurukame)
struct ReviewItemState: Identifiable {
    let id = UUID()
    let character: String
    let meanings: [String]
    let readings: [String]
    let level: Int
    let progressId: String
    let wanikaniAssignmentId: Int?  // Required for submitting reviews to WaniKani
    var meaningAnswered = false
    var readingAnswered = false
    var meaningCorrect = false
    var readingCorrect = false
    // Track wrong counts for accurate WaniKani sync
    var meaningWrongCount = 0
    var readingWrongCount = 0

    var isComplete: Bool {
        meaningAnswered && readingAnswered
    }
}

struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared
    @Query private var userSettings: [UserSettings]

    // Review session state
    @State private var reviewItems: [ReviewItemState] = []
    @State private var currentIndex = 0
    @State private var currentQuestionType: ReviewQuestionType = .reading  // Default to reading-first
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var sessionComplete = false
    @State private var isLoading = true

    // Stats
    @State private var correctCount = 0
    @State private var incorrectCount = 0

    // Computed review settings (like Tsurukame)
    private var reviewSettings: ReviewSettings {
        userSettings.first?.reviewSettings ?? ReviewSettings()
    }

    private var currentItem: ReviewItemState? {
        guard currentIndex < reviewItems.count else { return nil }
        return reviewItems[currentIndex]
    }

    private var progress: Double {
        guard !reviewItems.isEmpty else { return 0 }
        let totalQuestions = reviewItems.count * 2 // meaning + reading
        let answeredQuestions = reviewItems.reduce(0) { count, item in
            count + (item.meaningAnswered ? 1 : 0) + (item.readingAnswered ? 1 : 0)
        }
        return Double(answeredQuestions) / Double(totalQuestions)
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading reviews...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessionComplete {
                SessionCompleteView(
                    correct: correctCount,
                    incorrect: incorrectCount,
                    dismiss: dismiss
                )
            } else if let item = currentItem {
                ReviewCardView(
                    item: item,
                    questionType: currentQuestionType,
                    userAnswer: $userAnswer,
                    showResult: showResult,
                    isCorrect: isCorrect,
                    progress: progress,
                    onSubmit: checkAnswer,
                    onNext: nextQuestion
                )
            } else {
                SessionCompleteView(
                    correct: correctCount,
                    incorrect: incorrectCount,
                    dismiss: dismiss
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End") {
                    dismiss()
                }
            }
        }
        .task {
            await loadReviewItems()
        }
    }

    private func loadReviewItems() async {
        // Query for items due for review
        let now = Date()
        let descriptor = FetchDescriptor<KanjiProgress>(
            predicate: #Predicate { progress in
                progress.nextReviewAt != nil && progress.nextReviewAt! <= now
            },
            sortBy: [SortDescriptor(\.nextReviewAt)]
        )

        guard let dueItems = try? modelContext.fetch(descriptor), !dueItems.isEmpty else {
            sessionComplete = true
            isLoading = false
            return
        }

        // Convert to review items with kanji data
        var items: [ReviewItemState] = []
        for progress in dueItems.prefix(10) { // Limit to 10 items per session
            if let kanji = dataManager.getKanji(byCharacter: progress.character) {
                items.append(ReviewItemState(
                    character: kanji.character,
                    meanings: kanji.meanings,
                    readings: kanji.allReadings,
                    level: kanji.level,
                    progressId: progress.character,
                    wanikaniAssignmentId: progress.wanikaniAssignmentId  // Include assignment ID for WaniKani sync
                ))
            }
        }

        reviewItems = items.shuffled()

        // Set initial question type based on user preference (like Tsurukame)
        currentQuestionType = reviewSettings.readingFirst ? .reading : .meaning

        isLoading = false
    }

    private func checkAnswer() {
        guard currentIndex < reviewItems.count else { return }

        var item = reviewItems[currentIndex]

        switch currentQuestionType {
        case .meaning:
            // Use AnswerChecker for meaning validation with fuzzy matching
            let result = AnswerChecker.checkMeaning(
                answer: userAnswer,
                acceptedMeanings: item.meanings,
                fuzzyMatchingEnabled: reviewSettings.fuzzyMatchingEnabled
            )

            switch result {
            case .correct, .almostCorrect:
                isCorrect = true
                item.meaningAnswered = true
                item.meaningCorrect = true
            case .incorrect, .containsInvalidCharacters, .otherAcceptableReading:
                isCorrect = false
                item.meaningWrongCount += 1  // Track wrong count
                // Only mark as answered if correct (like Tsurukame)
                // This means user must answer correctly to proceed
                item.meaningAnswered = true  // For now, mark answered to proceed
                item.meaningCorrect = false
            }

        case .reading:
            // Use AnswerChecker for reading validation with katakana conversion
            let result = AnswerChecker.checkReading(
                answer: userAnswer,
                acceptedReadings: item.readings,
                autoConvertKatakana: reviewSettings.autoConvertKatakana
            )

            switch result {
            case .correct, .otherAcceptableReading:
                isCorrect = true
                item.readingAnswered = true
                item.readingCorrect = true
            case .almostCorrect:
                // For readings, almostCorrect isn't used, but handle it
                isCorrect = true
                item.readingAnswered = true
                item.readingCorrect = true
            case .incorrect, .containsInvalidCharacters:
                isCorrect = false
                item.readingWrongCount += 1  // Track wrong count
                item.readingAnswered = true
                item.readingCorrect = false
            }
        }

        reviewItems[currentIndex] = item

        if isCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }

        // Haptic feedback based on answer correctness
        HapticManager.reviewAnswer(correct: isCorrect)

        showResult = true
    }

    private func nextQuestion() {
        HapticManager.light()
        showResult = false
        userAnswer = ""

        guard currentIndex < reviewItems.count else {
            sessionComplete = true
            HapticManager.sessionComplete()
            return
        }

        let item = reviewItems[currentIndex]

        // Check if both questions are answered for this item
        if item.isComplete {
            // Update SRS for this item
            updateSRS(for: item)

            // Move to next item
            currentIndex += 1

            // Reset question type based on user preference (like Tsurukame)
            currentQuestionType = reviewSettings.readingFirst ? .reading : .meaning

            if currentIndex >= reviewItems.count {
                sessionComplete = true
                HapticManager.sessionComplete()
            }
        } else {
            // Switch to the other question type
            HapticManager.selection()
            currentQuestionType = currentQuestionType == .meaning ? .reading : .meaning
        }
    }

    private func updateSRS(for item: ReviewItemState) {
        // Find the progress entry
        let progressId = item.progressId
        let descriptor = FetchDescriptor<KanjiProgress>(
            predicate: #Predicate { $0.character == progressId }
        )

        guard let progress = try? modelContext.fetch(descriptor).first else {
            return
        }

        // Calculate new SRS stage
        let newStage = SRSCalculator.calculateNextStage(
            currentStage: progress.srs,
            meaningCorrect: item.meaningCorrect,
            readingCorrect: item.readingCorrect
        )

        // Update progress
        progress.srs = newStage
        progress.nextReviewAt = SRSCalculator.calculateNextReviewDate(for: newStage)
        progress.timesReviewed += 1
        if item.meaningCorrect && item.readingCorrect {
            progress.timesCorrect += 1
        }
        progress.updatedAt = Date()

        try? modelContext.save()

        print("Updated \(item.character): \(progress.srs.name), next review: \(progress.nextReviewAt?.description ?? "nil")")

        // Submit review to WaniKani in background
        Task {
            await submitToWaniKani(for: item)
        }
    }

    /// Submits a review to WaniKani API
    /// This syncs the local review result back to the user's WaniKani account
    private func submitToWaniKani(for item: ReviewItemState) async {
        // Only submit if we have an assignment ID and API key
        guard let assignmentId = item.wanikaniAssignmentId,
              let apiKey = KeychainHelper.getWaniKaniApiKey(),
              !apiKey.isEmpty else {
            print("Skipping WaniKani sync for \(item.character) - no assignment ID or API key")
            return
        }

        // Use actual wrong counts for accurate WaniKani sync (like Tsurukame)
        let meaningIncorrect = item.meaningWrongCount
        let readingIncorrect = item.readingWrongCount

        // Set API key on service
        WaniKaniService.shared.setApiKey(apiKey)

        do {
            try await WaniKaniService.shared.submitReview(
                assignmentId: assignmentId,
                meaningIncorrect: meaningIncorrect,
                readingIncorrect: readingIncorrect
            )
            print("✅ Synced review for \(item.character) to WaniKani (meaning: \(meaningIncorrect) wrong, reading: \(readingIncorrect) wrong)")
        } catch let error as WaniKaniError {
            // Handle specific WaniKani errors
            switch error {
            case .httpError(let statusCode) where statusCode == 422:
                // 422 = Already reviewed elsewhere (like Tsurukame's handling)
                // This commonly happens when doing reviews before progress from
                // elsewhere has synced - the item was already reviewed elsewhere
                print("⚠️ Review for \(item.character) already submitted elsewhere (422)")
            default:
                print("❌ Failed to sync review for \(item.character): \(error.localizedDescription)")
            }
        } catch {
            print("❌ Failed to sync review for \(item.character): \(error.localizedDescription)")
            // TODO: Store failed syncs for later retry
        }
    }
}

struct ReviewCardView: View {
    let item: ReviewItemState
    let questionType: ReviewQuestionType
    @Binding var userAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    let progress: Double
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
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            // Question type indicator
            Text(questionType == .meaning ? "Meaning" : "Reading")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(questionType == .meaning ? Color.pink : Color.purple)

            // Level badge
            HStack {
                Text("Level \(item.level)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Character
            Text(item.character)
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
                                 item.meanings.joined(separator: ", ") :
                                 item.readings.joined(separator: ", "))
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
        .onAppear {
            isInputFocused = true
        }
    }
}

struct SessionCompleteView: View {
    let correct: Int
    let incorrect: Int
    let dismiss: DismissAction

    @State private var showContent = false
    @State private var starScale: CGFloat = 0.5

    private var total: Int { correct + incorrect }
    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int(Double(correct) / Double(total) * 100)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Success animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(showContent ? 1 : 0.8)

                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(starScale)
                    .rotationEffect(.degrees(showContent ? 0 : -30))
            }

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            // Stats
            HStack(spacing: 32) {
                StatBox(value: "\(correct)", label: "Correct", color: .green)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                StatBox(value: "\(incorrect)", label: "Incorrect", color: .red)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                StatBox(value: "\(accuracy)%", label: "Accuracy", color: .purple)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
            }

            Text("Great job! Keep up the good work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(showContent ? 1 : 0)

            Button("Done") {
                HapticManager.buttonTap()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .padding(.top, 20)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showContent = true
                starScale = 1.0
            }
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ReviewSessionView()
    }
    .environmentObject(AuthManager.shared)
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
