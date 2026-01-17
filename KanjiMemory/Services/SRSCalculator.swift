import Foundation

/// SRS (Spaced Repetition System) Calculator based on WaniKani's algorithm
struct SRSCalculator {
    // SRS intervals in hours
    private static let intervals: [SRSStage: TimeInterval] = [
        .lesson: 0,
        .apprentice1: 4 * 3600,      // 4 hours
        .apprentice2: 8 * 3600,      // 8 hours
        .apprentice3: 24 * 3600,     // 1 day
        .apprentice4: 48 * 3600,     // 2 days
        .guru1: 7 * 24 * 3600,       // 1 week
        .guru2: 14 * 24 * 3600,      // 2 weeks
        .master: 30 * 24 * 3600,     // 1 month
        .enlightened: 120 * 24 * 3600 // 4 months
    ]

    /// Calculate the next SRS stage based on answer correctness
    static func calculateNextStage(
        currentStage: SRSStage,
        meaningCorrect: Bool,
        readingCorrect: Bool
    ) -> SRSStage {
        let totalIncorrect = (meaningCorrect ? 0 : 1) + (readingCorrect ? 0 : 1)

        if totalIncorrect == 0 {
            // Correct answer - move up one stage
            return nextStage(from: currentStage)
        } else {
            // Incorrect answer - move down based on number of mistakes
            return previousStage(from: currentStage, mistakes: totalIncorrect)
        }
    }

    /// Get the next stage (level up)
    private static func nextStage(from stage: SRSStage) -> SRSStage {
        switch stage {
        case .lesson: return .apprentice1
        case .apprentice1: return .apprentice2
        case .apprentice2: return .apprentice3
        case .apprentice3: return .apprentice4
        case .apprentice4: return .guru1
        case .guru1: return .guru2
        case .guru2: return .master
        case .master: return .enlightened
        case .enlightened: return .burned
        case .burned: return .burned // Already at max
        }
    }

    /// Get the previous stage (level down)
    private static func previousStage(from stage: SRSStage, mistakes: Int) -> SRSStage {
        let stagesDown = mistakes == 1 ? 1 : 2

        var currentStage = stage
        for _ in 0..<stagesDown {
            currentStage = oneStagePrevious(from: currentStage)
        }

        // Never go below apprentice1 (unless it's a lesson)
        if currentStage == .lesson {
            return .apprentice1
        }

        return currentStage
    }

    private static func oneStagePrevious(from stage: SRSStage) -> SRSStage {
        switch stage {
        case .lesson: return .lesson
        case .apprentice1: return .apprentice1
        case .apprentice2: return .apprentice1
        case .apprentice3: return .apprentice2
        case .apprentice4: return .apprentice3
        case .guru1: return .apprentice4
        case .guru2: return .guru1
        case .master: return .guru2
        case .enlightened: return .master
        case .burned: return .enlightened
        }
    }

    /// Calculate the next review date based on the new SRS stage
    static func calculateNextReviewDate(for stage: SRSStage) -> Date? {
        // Burned items don't need review
        if stage == .burned {
            return nil
        }

        guard let interval = intervals[stage] else {
            return nil
        }

        return Date().addingTimeInterval(interval)
    }

    /// Check if an item is due for review
    static func isDueForReview(nextReviewAt: Date?) -> Bool {
        guard let reviewDate = nextReviewAt else {
            return false
        }
        return reviewDate <= Date()
    }

    /// Get a human-readable string for the next review time
    static func formatNextReview(date: Date?) -> String {
        guard let date = date else {
            return "Never"
        }

        if date <= Date() {
            return "Now"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Get time remaining until next review
    static func timeUntilReview(date: Date?) -> TimeInterval? {
        guard let date = date else {
            return nil
        }

        let remaining = date.timeIntervalSince(Date())
        return remaining > 0 ? remaining : 0
    }
}

// MARK: - Review Session Manager
class ReviewSession: ObservableObject {
    struct ReviewItem: Identifiable {
        let id = UUID()
        let character: String
        let meanings: [String]
        let readings: [String]
        let currentStage: SRSStage
        var meaningAnswered = false
        var readingAnswered = false
        var meaningCorrect = false
        var readingCorrect = false
    }

    @Published var items: [ReviewItem] = []
    @Published var currentIndex = 0
    @Published var currentQuestionType: ReviewQuestionType = .meaning
    @Published var completed = false

    private var correctCount = 0
    private var incorrectCount = 0

    var currentItem: ReviewItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let totalQuestions = items.count * 2 // meaning + reading
        let answeredQuestions = items.reduce(0) { count, item in
            count + (item.meaningAnswered ? 1 : 0) + (item.readingAnswered ? 1 : 0)
        }
        return Double(answeredQuestions) / Double(totalQuestions)
    }

    var stats: (correct: Int, incorrect: Int) {
        (correctCount, incorrectCount)
    }

    func submitAnswer(answer: String) -> Bool {
        guard currentIndex < items.count else { return false }

        var item = items[currentIndex]
        let isCorrect: Bool

        switch currentQuestionType {
        case .meaning:
            let normalized = answer.lowercased().trimmingCharacters(in: .whitespaces)
            isCorrect = item.meanings.contains { $0.lowercased() == normalized }
            item.meaningAnswered = true
            item.meaningCorrect = isCorrect
        case .reading:
            let normalized = answer.trimmingCharacters(in: .whitespaces)
            isCorrect = item.readings.contains { $0 == normalized }
            item.readingAnswered = true
            item.readingCorrect = isCorrect
        }

        items[currentIndex] = item

        if isCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }

        return isCorrect
    }

    func nextQuestion() {
        guard currentIndex < items.count else {
            completed = true
            return
        }

        let item = items[currentIndex]

        // Check if we need to ask the other question type
        if currentQuestionType == .meaning && !item.readingAnswered {
            currentQuestionType = .reading
        } else if currentQuestionType == .reading && !item.meaningAnswered {
            currentQuestionType = .meaning
        } else {
            // Both answered, move to next item
            currentIndex += 1
            currentQuestionType = .meaning

            if currentIndex >= items.count {
                completed = true
            }
        }
    }

    func reset() {
        currentIndex = 0
        currentQuestionType = .meaning
        completed = false
        correctCount = 0
        incorrectCount = 0
        items = items.map { item in
            var newItem = item
            newItem.meaningAnswered = false
            newItem.readingAnswered = false
            newItem.meaningCorrect = false
            newItem.readingCorrect = false
            return newItem
        }
    }
}
