import SwiftUI
import SwiftData
import AVFoundation

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
    let level: Int  // WaniKani level for display
    let srsStage: SRSStage  // Current SRS stage for display
    let audioURL: String?  // Audio URL for vocabulary
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

    /// Soft background gradient colors based on subject type (web app inspired - light mode)
    var backgroundGradientSoft: [Color] {
        switch subjectType {
        case .radical:
            return [SubjectTypeColors.radicalSoftStart, SubjectTypeColors.radicalSoftEnd]
        case .kanji:
            return [SubjectTypeColors.kanjiSoftStart, SubjectTypeColors.kanjiSoftEnd]
        case .vocabulary:
            return [SubjectTypeColors.vocabularySoftStart, SubjectTypeColors.vocabularySoftEnd]
        }
    }

    /// Deep background gradient colors based on subject type (web app inspired - dark mode)
    var backgroundGradientDeep: [Color] {
        switch subjectType {
        case .radical:
            return [SubjectTypeColors.radicalDeepStart, SubjectTypeColors.radicalDeepEnd]
        case .kanji:
            return [SubjectTypeColors.kanjiDeepStart, SubjectTypeColors.kanjiDeepEnd]
        case .vocabulary:
            return [SubjectTypeColors.vocabularyDeepStart, SubjectTypeColors.vocabularyDeepEnd]
        }
    }

    /// Character text color based on subject type (light mode only - dark mode uses white)
    var characterTextColor: Color {
        switch subjectType {
        case .radical:
            return SubjectTypeColors.radicalTextColor
        case .kanji:
            return SubjectTypeColors.kanjiTextColor
        case .vocabulary:
            return SubjectTypeColors.vocabularyTextColor
        }
    }
}

struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var dataManager = DataManager.shared
    @Query private var userSettings: [UserSettings]

    /// Filter to only show specific subject types (nil = all types)
    var subjectTypeFilter: ReviewSubjectType? = nil

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

    /// Total answers given (for accuracy calculation)
    private var totalAnswered: Int {
        correctCount + incorrectCount
    }

    /// Count of fully completed items (both meaning and reading answered)
    private var completedItemCount: Int {
        reviewItems.filter { $0.isComplete }.count
    }

    /// Items remaining in the queue
    private var queueCount: Int {
        reviewItems.count - completedItemCount
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
                    showWrongIndicator: $showWrongIndicator,
                    onCharacterTap: { showDetailSheet = true },
                    dataManager: dataManager,
                    correctCount: correctCount,
                    totalAnswered: totalAnswered,
                    completedCount: completedItemCount,
                    queueCount: queueCount
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
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("End") {
                    showEndConfirmation = true
                }
                .foregroundStyle(.white)
                .fontWeight(.medium)
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
                        wanikaniAssignmentId: progress.wanikaniAssignmentId,
                        level: radical.level,
                        srsStage: progress.srs,
                        audioURL: nil  // Radicals have no audio
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
                        wanikaniAssignmentId: progress.wanikaniAssignmentId,
                        level: kanji.level,
                        srsStage: progress.srs,
                        audioURL: nil  // Kanji typically don't have audio
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
                        wanikaniAssignmentId: progress.wanikaniAssignmentId,
                        level: vocab.level,
                        srsStage: progress.srs,
                        audioURL: nil  // TODO: Add audio URL from WaniKani data
                    ))
                }
            }
        }

        print("✅ Total review items found: \(items.count)")

        // Apply subject type filter if specified
        if let filter = subjectTypeFilter {
            items = items.filter { $0.subjectType == filter }
            print("🔍 After filter (\(filter)): \(items.count) items")
        }

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

// MARK: - Tsurukame-Style Review Card View

struct ReviewCardView: View {
    let item: ReviewItemState
    let questionType: ReviewQuestionType
    @Binding var userAnswer: String
    let showResult: Bool
    let isCorrect: Bool
    let progress: Double
    let onSubmit: () -> Void
    let onNext: () -> Void
    @Binding var showWrongIndicator: Bool
    let onCharacterTap: () -> Void
    let dataManager: DataManager

    // Stats for the stats bar
    let correctCount: Int
    let totalAnswered: Int
    let completedCount: Int
    let queueCount: Int

    @FocusState private var isInputFocused: Bool
    @State private var romajiBuffer = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var showDetailPanel = false
    @Environment(\.colorScheme) private var colorScheme

    /// Soft background gradient - uses new web-app-inspired softer colors
    private var backgroundGradient: [Color] {
        colorScheme == .dark ? item.backgroundGradientDeep : item.backgroundGradientSoft
    }

    /// Character text color - uses subject-based colors in light mode, white in dark mode
    private var characterColor: Color {
        colorScheme == .dark ? .white : item.characterTextColor
    }

    var body: some View {
        ZStack {
            // Dynamic background by subject type
            LinearGradient(
                colors: backgroundGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: item.subjectType)

            VStack(spacing: 0) {
                // Thin white progress bar at very top
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 3)

                // Stats bar
                ReviewStatsBar(
                    correctCount: correctCount,
                    totalAnswered: totalAnswered,
                    completedCount: completedCount,
                    queueCount: queueCount
                )

                // Question type indicator with SRS dots
                QuestionTypeIndicator(
                    subjectType: item.subjectType,
                    questionType: questionType,
                    srsStage: item.srsStage
                )

                Spacer()

                // Character - tappable to view detail
                Button {
                    HapticManager.light()
                    onCharacterTap()
                } label: {
                    Text(item.character)
                        .font(.system(size: dynamicFontSize(for: item.character)))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundColor(characterColor)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 30)

                Spacer()

                // Answer section - Glassmorphic card styling
                VStack(spacing: 16) {
                    if showResult && isCorrect {
                        // Correct answer feedback - horizontal banner style
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)

                            Text("Correct!")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            LinearGradient(
                                colors: [.green.opacity(0.9), .mint.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showResult)
                    } else {
                        // Input area
                        answerInputSection
                    }
                }
                .frame(maxHeight: 280)
                .background(
                    // Glassmorphic card background
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(colorScheme == .dark
                            ? Color.white.opacity(0.05)
                            : Color.white.opacity(0.7))
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 15, y: -5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3), lineWidth: 1)
                )
            }

            // Wrong answer detail panel (slides up from bottom)
            if showDetailPanel {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showDetailPanel = false
                        }
                    }

                VStack {
                    Spacer()

                    SubjectDetailPanel(
                        item: item,
                        srsStage: item.srsStage,
                        level: item.level,
                        audioURL: item.audioURL,
                        onContinue: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showDetailPanel = false
                            }
                            // Reset so next wrong answer triggers onChange again
                            showWrongIndicator = false
                        },
                        onShowFullDetail: {
                            showDetailPanel = false
                            showWrongIndicator = false
                            onCharacterTap()
                        }
                    )
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            isInputFocused = true
        }
        .onChange(of: userAnswer) { _, newValue in
            if newValue.isEmpty {
                romajiBuffer = ""
            }
        }
        .onChange(of: showWrongIndicator) { _, isWrong in
            if isWrong {
                // Dismiss keyboard when wrong
                isInputFocused = false
                // Show detail panel when wrong
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showDetailPanel = true
                }
                // Shake animation
                withAnimation(.default.repeatCount(3, autoreverses: true).speed(6)) {
                    shakeOffset = 10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeOffset = 0
                }
            }
        }
    }

    // MARK: - Answer Input Section

    @ViewBuilder
    private var answerInputSection: some View {
        VStack(spacing: 12) {
            // Removed redundant "Enter the reading" text - question type header is sufficient
            Spacer()
                .frame(height: 16)

            if questionType == .reading {
                // Kana input with romaji conversion - Glass styling
                ZStack {
                    Text(RomajiConverter.convertForDisplay(romajiBuffer).isEmpty
                         ? "答え"
                         : RomajiConverter.convertForDisplay(romajiBuffer))
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(RomajiConverter.convertForDisplay(romajiBuffer).isEmpty
                                       ? .gray.opacity(0.4)
                                       : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isInputFocused
                                    ? subjectAccentColor.opacity(0.8)
                                    : Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .offset(x: shakeOffset)

                    TextField("", text: $romajiBuffer)
                        .opacity(0.01)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isInputFocused)
                        .onSubmit {
                            userAnswer = RomajiConverter.finalize(romajiBuffer)
                            onSubmit()
                        }
                        .onChange(of: romajiBuffer) { _, _ in
                            userAnswer = RomajiConverter.convertForDisplay(romajiBuffer)
                        }
                }
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = true
                }
            } else {
                // Meaning input - Glass styling
                TextField("Answer", text: $userAnswer)
                    .font(.system(size: 24, weight: .medium))
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .focused($isInputFocused)
                    .onSubmit(onSubmit)
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isInputFocused
                                ? subjectAccentColor.opacity(0.8)
                                : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .offset(x: shakeOffset)
                    .padding(.horizontal, 20)
            }

            // Submit button - Glass styling with accent color
            Button {
                if questionType == .reading {
                    userAnswer = RomajiConverter.finalize(romajiBuffer)
                }
                onSubmit()
            } label: {
                Text("Submit")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isInputEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.5))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [subjectAccentColor, subjectAccentColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                  ))
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: isInputEmpty ? .clear : subjectAccentColor.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(isInputEmpty)
            .scaleEffect(isInputEmpty ? 1.0 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isInputEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var isInputEmpty: Bool {
        questionType == .reading ? romajiBuffer.isEmpty : userAnswer.isEmpty
    }

    private var subjectAccentColor: Color {
        switch item.subjectType {
        case .radical: return SubjectTypeColors.radicalPrimary
        case .kanji: return SubjectTypeColors.kanjiPrimary
        case .vocabulary: return SubjectTypeColors.vocabularyPrimary
        }
    }

    /// Dynamic font size based on character count to prevent truncation
    private func dynamicFontSize(for text: String) -> CGFloat {
        switch text.count {
        case 1: return 120
        case 2: return 100
        case 3: return 80
        case 4: return 65
        default: return 55
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

// MARK: - Stats Bar Component

/// Stats bar for review session showing accuracy, completed count, and queue remaining
/// Styled like Tsurukame's review stats display
struct ReviewStatsBar: View {
    let correctCount: Int
    let totalAnswered: Int
    let completedCount: Int
    let queueCount: Int

    private var successRate: Int {
        guard totalAnswered > 0 else { return 100 }
        return Int(Double(correctCount) / Double(totalAnswered) * 100)
    }

    var body: some View {
        HStack(spacing: 24) {
            ReviewStatItem(
                icon: "hand.thumbsup.fill",
                value: "\(successRate)%",
                color: successRate >= 80 ? .green : successRate >= 60 ? .yellow : .red
            )
            ReviewStatItem(
                icon: "checkmark",
                value: "\(completedCount)",
                color: .white
            )
            ReviewStatItem(
                icon: "tray.full.fill",
                value: "\(queueCount)",
                color: .white.opacity(0.8)
            )
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct ReviewStatItem: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
        }
        .foregroundStyle(color)
    }
}

// MARK: - SRS Progress Dots

/// SRS progress indicator dots (like Tsurukame)
struct SRSProgressDots: View {
    let stage: SRSStage

    private var dotCount: Int {
        switch stage {
        case .lesson: return 1
        case .apprentice1, .apprentice2, .apprentice3, .apprentice4: return 4
        case .guru1, .guru2: return 2
        case .master, .enlightened, .burned: return 1
        }
    }

    private var filledDots: Int {
        switch stage {
        case .lesson: return 0
        case .apprentice1: return 1
        case .apprentice2: return 2
        case .apprentice3: return 3
        case .apprentice4: return 4
        case .guru1: return 1
        case .guru2: return 2
        case .master, .enlightened, .burned: return 1
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? stage.indicatorColor : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Question Type Indicator

/// Enhanced question type indicator showing "Kanji Reading" format with SRS dots
/// Uses softer badge colors based on question type
struct QuestionTypeIndicator: View {
    let subjectType: ReviewSubjectType
    let questionType: ReviewQuestionType
    let srsStage: SRSStage?
    @Environment(\.colorScheme) private var colorScheme

    private var subjectTypeText: String {
        switch subjectType {
        case .radical: return "Radical"
        case .kanji: return "Kanji"
        case .vocabulary: return "Vocabulary"
        }
    }

    private var questionTypeText: String {
        switch questionType {
        case .meaning: return "Meaning"
        case .reading: return "Reading"
        }
    }

    /// Softer badge color based on question type
    private var badgeColor: Color {
        switch questionType {
        case .meaning: return .purple
        case .reading: return .green
        }
    }

    /// Text color adapts to colorScheme
    private var textColor: Color {
        colorScheme == .dark ? .white : badgeColor.opacity(0.9)
    }

    var body: some View {
        HStack {
            Spacer()
            // Question type badge with softer styling
            Text("\(subjectTypeText) \(questionTypeText)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                )
            Spacer()
            if let stage = srsStage {
                SRSProgressDots(stage: stage)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
        )
    }
}

// MARK: - Subject Detail Panel

/// Detailed panel shown when user answers incorrectly (Tsurukame-style)
struct SubjectDetailPanel: View {
    let item: ReviewItemState
    let srsStage: SRSStage
    let level: Int
    let audioURL: String?
    let onContinue: () -> Void
    let onShowFullDetail: () -> Void

    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Character header
                    HStack {
                        Text(item.character)
                            .font(.system(size: 48))
                            .foregroundColor(.primary)
                        Spacer()
                        if item.subjectType == .vocabulary, audioURL != nil {
                            Button {
                                playAudio()
                            } label: {
                                Image(systemName: isPlayingAudio ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(subjectColor)
                                    .padding(12)
                                    .background(Circle().fill(subjectColor.opacity(0.15)))
                            }
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // READING section
                    if item.subjectType != .radical {
                        DetailPanelSection(title: "READING", color: subjectColor) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(item.readings, id: \.self) { reading in
                                    Text(reading)
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }

                    // MEANING section
                    DetailPanelSection(title: "MEANING", color: subjectColor) {
                        Text(item.meanings.joined(separator: ", "))
                            .font(.title3)
                            .foregroundColor(.primary)
                    }

                    // Show all information button
                    Button {
                        onShowFullDetail()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Show all information")
                        }
                        .font(.subheadline)
                        .foregroundStyle(subjectColor)
                    }
                    .padding(.horizontal)

                    Divider()

                    // STATS section
                    DetailPanelSection(title: "STATS", color: subjectColor) {
                        VStack(spacing: 12) {
                            DetailStatRow(label: "WaniKani Level", value: "\(level)")
                            DetailStatRow(label: "SRS Stage", value: srsStage.name, color: srsStage.indicatorColor)
                            DetailStatRow(label: "Status", value: srsProgressText)
                        }
                    }

                    // Continue button
                    Button {
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(subjectColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemBackground) : .white)
                .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
        )
    }

    private var subjectColor: Color {
        switch item.subjectType {
        case .radical: return SubjectTypeColors.radicalPrimary
        case .kanji: return SubjectTypeColors.kanjiPrimary
        case .vocabulary: return SubjectTypeColors.vocabularyPrimary
        }
    }

    private var srsProgressText: String {
        switch srsStage {
        case .lesson: return "Not started"
        case .apprentice1, .apprentice2, .apprentice3, .apprentice4: return "Learning"
        case .guru1, .guru2: return "Confident"
        case .master: return "Mastered"
        case .enlightened: return "Nearly burned"
        case .burned: return "Burned 🔥"
        }
    }

    private func playAudio() {
        guard let urlString = audioURL,
              let url = URL(string: urlString) else { return }
        isPlayingAudio = true
        let playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            isPlayingAudio = false
        }
        HapticManager.light()
    }
}

private struct DetailPanelSection<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .tracking(1)
            content
        }
        .padding(.horizontal)
    }
}

private struct DetailStatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    NavigationStack {
        ReviewSessionView()
    }
    .environmentObject(AuthManager.shared)
    .modelContainer(for: [KanjiProgress.self], inMemory: true)
}
