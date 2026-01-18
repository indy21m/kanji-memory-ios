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
    @State private var showWrongIndicator = false  // Shows wrong answer but allows retry
    @State private var showEndConfirmation = false  // End session confirmation dialog
    @State private var showDetailSheet = false  // Tap character to view detail

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
                    onNext: nextQuestion,
                    showWrongIndicator: showWrongIndicator,
                    onCharacterTap: { showDetailSheet = true },
                    dataManager: dataManager
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
                    showEndConfirmation = true
                }
            }
        }
        .confirmationDialog("End Session?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End Session", role: .destructive) {
                sessionComplete = true  // Shows SessionCompleteView with stats
            }
            Button("Resume", role: .cancel) { }
        } message: {
            Text("\(correctCount) correct, \(incorrectCount) incorrect so far")
        }
        .sheet(isPresented: $showDetailSheet) {
            if let item = currentItem {
                NavigationStack {
                    detailView(for: item)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showDetailSheet = false }
                            }
                        }
                }
            }
        }
        .task {
            await loadReviewItems()
        }
    }

    @ViewBuilder
    private func detailView(for item: ReviewItemState) -> some View {
        switch item.subjectType {
        case .kanji:
            if let kanji = dataManager.getKanji(byCharacter: item.character) {
                KanjiDetailView(kanji: kanji)
            } else {
                Text("Kanji not found")
            }
        case .radical:
            if let radical = dataManager.getRadical(byId: item.subjectId) {
                RadicalDetailView(radical: radical)
            } else {
                Text("Radical not found")
            }
        case .vocabulary:
            if let vocab = dataManager.getVocabulary(byId: item.subjectId) {
                VocabularyDetailView(vocabulary: vocab)
            } else {
                Text("Vocabulary not found")
            }
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
        var wasCorrect = false

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
                wasCorrect = true
                item.meaningAnswered = true
                item.meaningCorrect = true
                correctCount += 1
            case .incorrect, .containsInvalidCharacters, .otherAcceptableReading:
                wasCorrect = false
                item.meaningWrongCount += 1  // Track wrong count for SRS
                incorrectCount += 1
                // DON'T mark as answered - user must retry (Tsurukame style)
            }

        case .reading:
            // Use AnswerChecker for reading validation with katakana conversion
            let result = AnswerChecker.checkReading(
                answer: userAnswer,
                acceptedReadings: item.readings,
                autoConvertKatakana: reviewSettings.autoConvertKatakana
            )

            switch result {
            case .correct, .otherAcceptableReading, .almostCorrect:
                wasCorrect = true
                item.readingAnswered = true
                item.readingCorrect = true
                correctCount += 1
            case .incorrect, .containsInvalidCharacters:
                wasCorrect = false
                item.readingWrongCount += 1  // Track wrong count for SRS
                incorrectCount += 1
                // DON'T mark as answered - user must retry (Tsurukame style)
            }
        }

        reviewItems[currentIndex] = item
        isCorrect = wasCorrect

        // Haptic feedback based on answer correctness
        HapticManager.reviewAnswer(correct: wasCorrect)

        if wasCorrect {
            // Correct: show brief visual feedback then auto-advance
            showWrongIndicator = false
            showResult = true
            // Auto-advance after brief visual feedback (no button tap needed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                nextQuestion()
            }
        } else {
            // Wrong: show indicator but allow retry (Tsurukame style)
            showWrongIndicator = true
            showResult = false  // Keep input visible for retry
            userAnswer = ""  // Clear input for retry
        }
    }

    private func nextQuestion() {
        HapticManager.light()
        showResult = false
        showWrongIndicator = false
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
    let showWrongIndicator: Bool  // Shows shake/red when wrong but allows retry
    let onCharacterTap: () -> Void  // Tap character to view detail
    let dataManager: DataManager

    @FocusState private var isInputFocused: Bool
    @State private var romajiBuffer = ""  // Raw romaji being typed
    @State private var shakeOffset: CGFloat = 0

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

            // Character - tappable to view detail
            Button {
                HapticManager.light()
                onCharacterTap()
            } label: {
                Text(item.character)
                    .font(.system(size: 120))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 40)

            Spacer()

            // Answer section with improved dark mode styling
            VStack(spacing: 16) {
                if showResult && isCorrect {
                    // Show correct result - auto-advances after brief delay
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))

                        Text("Correct!")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showResult)
                } else {
                    // Input field (also shown when wrong to allow retry)
                    VStack(spacing: 8) {
                        // Show correct answer when wrong (like Tsurukame)
                        if showWrongIndicator {
                            VStack(spacing: 4) {
                                Text("Correct answer:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(questionType == .meaning ?
                                     item.meanings.joined(separator: ", ") :
                                     item.readings.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }
                            .padding(.bottom, 4)
                        }

                        if questionType == .reading {
                            // Single-line input like Tsurukame:
                            // Shows kana display with hidden romaji input underneath
                            ZStack {
                                // Kana display (what user sees)
                                Text(RomajiConverter.convertForDisplay(romajiBuffer).isEmpty ? "ひらがなで入力..." : RomajiConverter.convertForDisplay(romajiBuffer))
                                    .font(.title2)
                                    .foregroundColor(RomajiConverter.convertForDisplay(romajiBuffer).isEmpty ? .gray.opacity(0.5) : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(showWrongIndicator ? Color.red.opacity(0.1) : Color(.systemBackground))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(showWrongIndicator ? Color.red : isInputFocused ? Color.purple : Color.gray.opacity(0.3), lineWidth: showWrongIndicator ? 2 : isInputFocused ? 2 : 1)
                                    )
                                    .offset(x: shakeOffset)

                                // Hidden romaji input (captures keyboard)
                                TextField("", text: $romajiBuffer)
                                    .opacity(0.01)  // Nearly invisible but still captures input
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .focused($isInputFocused)
                                    .onSubmit {
                                        // Use finalize to convert trailing 'n' to 'ん' on submit
                                        userAnswer = RomajiConverter.finalize(romajiBuffer)
                                        onSubmit()
                                    }
                                    .onChange(of: romajiBuffer) { _, _ in
                                        userAnswer = RomajiConverter.convertForDisplay(romajiBuffer)
                                    }
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isInputFocused = true
                            }
                        } else {
                            // For meanings: standard text input
                            TextField("Enter meaning...", text: $userAnswer)
                                .font(.title2)
                                .multilineTextAlignment(.center)
                                .autocapitalization(.none)
                                .focused($isInputFocused)
                                .onSubmit(onSubmit)
                                .frame(height: 50)
                                .padding(.horizontal, 8)
                                .background(showWrongIndicator ? Color.red.opacity(0.1) : Color(.systemBackground))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(showWrongIndicator ? Color.red : Color.gray.opacity(0.3), lineWidth: showWrongIndicator ? 2 : 1)
                                )
                                .offset(x: shakeOffset)
                                .padding(.horizontal)
                        }
                    }

                    Button("Submit") {
                        if questionType == .reading {
                            // Use finalize to convert trailing 'n' to 'ん' on submit
                            userAnswer = RomajiConverter.finalize(romajiBuffer)
                        }
                        onSubmit()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(showWrongIndicator ? .orange : .purple)
                    .disabled(questionType == .reading ? romajiBuffer.isEmpty : userAnswer.isEmpty)
                    .padding()
                }
            }
            .frame(maxHeight: 250)
            .background(
                // Glassmorphism for answer area
                Color(.secondarySystemGroupedBackground)
                    .overlay(
                        // Subtle gradient overlay for visual interest
                        LinearGradient(
                            colors: [Color.purple.opacity(0.03), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
        }
        .background(Color(.systemBackground))
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: userAnswer) { _, newValue in
            // Reset romajiBuffer when userAnswer is cleared (next question)
            if newValue.isEmpty {
                romajiBuffer = ""
            }
        }
        .onChange(of: showWrongIndicator) { _, isWrong in
            // Shake animation when wrong
            if isWrong {
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                    shakeOffset = 10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeOffset = 0
                }
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
