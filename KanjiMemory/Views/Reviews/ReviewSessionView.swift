import SwiftUI
import SwiftData

enum ReviewQuestionType {
    case meaning
    case reading
}

enum ReviewSubjectType {
    case radical
    case kanji
    case vocabulary
}

/// A review item that tracks answers for both meaning and reading
/// Includes wrong counts for accurate WaniKani sync (like Tsurukame)
struct ReviewItemState: Identifiable {
    let id = UUID()
    let subjectType: ReviewSubjectType
    let subjectId: Int  // WaniKani subject ID (radical.id, kanji.wanikaniId, vocab.id)
    let character: String
    let meanings: [String]
    let readings: [String]  // Empty for radicals
    let wanikaniAssignmentId: Int?  // Required for submitting reviews to WaniKani
    var meaningAnswered = false
    var readingAnswered = false
    var meaningCorrect = false
    var readingCorrect = false
    // Track wrong counts for accurate WaniKani sync
    var meaningWrongCount = 0
    var readingWrongCount = 0

    // Radicals only need meaning
    var needsReading: Bool {
        subjectType != .radical
    }

    var isComplete: Bool {
        if needsReading {
            return meaningAnswered && readingAnswered
        }
        return meaningAnswered
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
        // Calculate total questions: radicals=1 (meaning only), kanji/vocab=2 (meaning + reading)
        let totalQuestions = reviewItems.reduce(0) { count, item in
            count + (item.needsReading ? 2 : 1)
        }
        let answeredQuestions = reviewItems.reduce(0) { count, item in
            var answered = item.meaningAnswered ? 1 : 0
            if item.needsReading {
                answered += item.readingAnswered ? 1 : 0
            }
            return count + answered
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
        // Ensure DataManager has loaded its data
        if !dataManager.isLoaded {
            await dataManager.loadBundledData()
        }

        let now = Date()
        var items: [ReviewItemState] = []

        print("🔍 Loading review items at \(now)")
        print("📚 DataManager loaded: \(dataManager.isLoaded), radicals: \(dataManager.allRadicals.count), kanji: \(dataManager.allKanji.count), vocab: \(dataManager.allVocabulary.count)")

        // Query for due radicals - fetch ALL then filter (SwiftData predicate workaround)
        let radicalDescriptor = FetchDescriptor<RadicalProgress>(
            sortBy: [SortDescriptor(\.nextReviewAt)]
        )
        if let allRadicals = try? modelContext.fetch(radicalDescriptor) {
            let dueRadicals = allRadicals.filter { progress in
                guard let reviewAt = progress.nextReviewAt else { return false }
                return reviewAt <= now
            }
            print("📖 Radicals: \(allRadicals.count) total, \(dueRadicals.count) due")

            for progress in dueRadicals {
                if let radical = dataManager.allRadicals.first(where: { $0.id == progress.radicalId }) {
                    items.append(ReviewItemState(
                        subjectType: .radical,
                        subjectId: radical.id,
                        character: radical.displayCharacter,
                        meanings: radical.meanings.map { $0.meaning },
                        readings: [],  // Radicals have no readings
                        wanikaniAssignmentId: progress.wanikaniAssignmentId
                    ))
                }
            }
        }

        // Query for due kanji - fetch ALL then filter
        let kanjiDescriptor = FetchDescriptor<KanjiProgress>(
            sortBy: [SortDescriptor(\.nextReviewAt)]
        )
        if let allKanji = try? modelContext.fetch(kanjiDescriptor) {
            let dueKanji = allKanji.filter { progress in
                guard let reviewAt = progress.nextReviewAt else { return false }
                return reviewAt <= now
            }
            print("📖 Kanji: \(allKanji.count) total, \(dueKanji.count) due")

            for progress in dueKanji {
                if let kanji = dataManager.getKanji(byCharacter: progress.character) {
                    items.append(ReviewItemState(
                        subjectType: .kanji,
                        subjectId: kanji.wanikaniId,
                        character: kanji.character,
                        meanings: kanji.meanings,
                        readings: kanji.allReadings,
                        wanikaniAssignmentId: progress.wanikaniAssignmentId
                    ))
                }
            }
        }

        // Query for due vocabulary - fetch ALL then filter
        let vocabDescriptor = FetchDescriptor<VocabularyProgress>(
            sortBy: [SortDescriptor(\.nextReviewAt)]
        )
        if let allVocab = try? modelContext.fetch(vocabDescriptor) {
            let dueVocab = allVocab.filter { progress in
                guard let reviewAt = progress.nextReviewAt else { return false }
                return reviewAt <= now
            }
            print("📖 Vocabulary: \(allVocab.count) total, \(dueVocab.count) due")

            for progress in dueVocab {
                if let vocab = dataManager.allVocabulary.first(where: { $0.id == progress.vocabularyId }) {
                    items.append(ReviewItemState(
                        subjectType: .vocabulary,
                        subjectId: vocab.id,
                        character: vocab.characters,
                        meanings: vocab.allMeanings,
                        readings: vocab.allReadings,
                        wanikaniAssignmentId: progress.wanikaniAssignmentId
                    ))
                }
            }
        }

        print("✅ Total review items found: \(items.count)")

        guard !items.isEmpty else {
            print("⚠️ No review items found, marking session complete")
            sessionComplete = true
            isLoading = false
            return
        }

        // Shuffle and limit to 10 items per session
        reviewItems = Array(items.shuffled().prefix(10))

        // Set initial question type based on user preference
        // For radicals, always start with meaning
        if let first = reviewItems.first {
            if first.subjectType == .radical {
                currentQuestionType = .meaning
            } else {
                currentQuestionType = reviewSettings.readingFirst ? .reading : .meaning
            }
        }

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

        // Check if all questions are answered for this item
        if item.isComplete {
            // Update SRS for this item
            updateSRS(for: item)

            // Move to next item
            currentIndex += 1

            if currentIndex >= reviewItems.count {
                sessionComplete = true
                HapticManager.sessionComplete()
            } else {
                // Set question type for next item based on its type and user preference
                let nextItem = reviewItems[currentIndex]
                if nextItem.subjectType == .radical {
                    currentQuestionType = .meaning
                } else {
                    currentQuestionType = reviewSettings.readingFirst ? .reading : .meaning
                }
            }
        } else {
            // Switch to the other question type (only for non-radicals)
            HapticManager.selection()
            currentQuestionType = currentQuestionType == .meaning ? .reading : .meaning
        }
    }

    private func updateSRS(for item: ReviewItemState) {
        // Calculate new SRS stage based on subject type
        // For radicals, only meaning matters; for kanji/vocab, both matter
        let readingCorrectForSRS = item.needsReading ? item.readingCorrect : true

        switch item.subjectType {
        case .radical:
            let subjectId = item.subjectId
            let descriptor = FetchDescriptor<RadicalProgress>(
                predicate: #Predicate { $0.radicalId == subjectId }
            )
            guard let progress = try? modelContext.fetch(descriptor).first else { return }

            let newStage = SRSCalculator.calculateNextStage(
                currentStage: progress.srs,
                meaningCorrect: item.meaningCorrect,
                readingCorrect: readingCorrectForSRS
            )
            progress.srs = newStage
            progress.nextReviewAt = SRSCalculator.calculateNextReviewDate(for: newStage)
            progress.updatedAt = Date()
            print("Updated radical \(item.character): \(progress.srs.name)")

        case .kanji:
            let character = item.character
            let descriptor = FetchDescriptor<KanjiProgress>(
                predicate: #Predicate { $0.character == character }
            )
            guard let progress = try? modelContext.fetch(descriptor).first else { return }

            let newStage = SRSCalculator.calculateNextStage(
                currentStage: progress.srs,
                meaningCorrect: item.meaningCorrect,
                readingCorrect: readingCorrectForSRS
            )
            progress.srs = newStage
            progress.nextReviewAt = SRSCalculator.calculateNextReviewDate(for: newStage)
            progress.timesReviewed += 1
            if item.meaningCorrect && item.readingCorrect {
                progress.timesCorrect += 1
            }
            progress.updatedAt = Date()
            print("Updated kanji \(item.character): \(progress.srs.name)")

        case .vocabulary:
            let subjectId = item.subjectId
            let descriptor = FetchDescriptor<VocabularyProgress>(
                predicate: #Predicate { $0.vocabularyId == subjectId }
            )
            guard let progress = try? modelContext.fetch(descriptor).first else { return }

            let newStage = SRSCalculator.calculateNextStage(
                currentStage: progress.srs,
                meaningCorrect: item.meaningCorrect,
                readingCorrect: readingCorrectForSRS
            )
            progress.srs = newStage
            progress.nextReviewAt = SRSCalculator.calculateNextReviewDate(for: newStage)
            progress.updatedAt = Date()
            print("Updated vocab \(item.character): \(progress.srs.name)")
        }

        try? modelContext.save()

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
    @State private var romajiInput = ""

    // Display text: for readings, show converted kana; for meanings, show raw input
    private var displayText: String {
        if questionType == .reading {
            return RomajiConverter.convertForDisplay(romajiInput)
        }
        return userAnswer
    }

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

            // Type badge
            HStack {
                Text(item.subjectType == .radical ? "Radical" :
                     item.subjectType == .kanji ? "Kanji" : "Vocabulary")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(
                        item.subjectType == .radical ? Color.blue :
                        item.subjectType == .kanji ? Color.purple : Color.green
                    )
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
                    if questionType == .reading {
                        // For readings: show converted kana, input romaji
                        VStack(spacing: 8) {
                            // Display converted kana
                            Text(displayText.isEmpty ? " " : displayText)
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .padding(.horizontal)

                            // Hidden-ish romaji input
                            TextField("Type in romaji (e.g., 'ka' → か)", text: $romajiInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                                .onSubmit {
                                    // Convert and set the answer before submitting
                                    userAnswer = RomajiConverter.convertForDisplay(romajiInput)
                                    onSubmit()
                                }
                                .onChange(of: romajiInput) { _, _ in
                                    // Keep userAnswer in sync for answer checking
                                    userAnswer = RomajiConverter.convertForDisplay(romajiInput)
                                }
                                .padding(.horizontal)
                        }
                    } else {
                        // For meanings: standard text input
                        TextField("Enter meaning...", text: $userAnswer)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .autocapitalization(.none)
                            .focused($isInputFocused)
                            .onSubmit(onSubmit)
                            .padding(.horizontal)
                    }

                    Button("Submit") {
                        if questionType == .reading {
                            userAnswer = RomajiConverter.convertForDisplay(romajiInput)
                        }
                        onSubmit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(questionType == .reading ? romajiInput.isEmpty : userAnswer.isEmpty)
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
        .onChange(of: userAnswer) { _, newValue in
            // Reset romajiInput when userAnswer is cleared (next question)
            if newValue.isEmpty {
                romajiInput = ""
            }
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
