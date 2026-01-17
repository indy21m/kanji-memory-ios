import XCTest
@testable import KanjiMemory

final class KanjiMemoryTests: XCTestCase {

    // MARK: - SRS Calculator Tests

    func testSRSProgressionCorrect() {
        // Test that correct answers progress through stages
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .lesson, meaningCorrect: true, readingCorrect: true),
            .apprentice1
        )
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .apprentice1, meaningCorrect: true, readingCorrect: true),
            .apprentice2
        )
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .guru1, meaningCorrect: true, readingCorrect: true),
            .guru2
        )
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .enlightened, meaningCorrect: true, readingCorrect: true),
            .burned
        )
    }

    func testSRSRegressionOneMistake() {
        // Test that one mistake drops one stage
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .guru1, meaningCorrect: false, readingCorrect: true),
            .apprentice4
        )
    }

    func testSRSRegressionTwoMistakes() {
        // Test that two mistakes drop two stages
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .guru2, meaningCorrect: false, readingCorrect: false),
            .guru1
        )
    }

    func testSRSNeverBelowApprentice1() {
        // Test that we never go below apprentice1 (except lesson)
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .apprentice2, meaningCorrect: false, readingCorrect: false),
            .apprentice1
        )
    }

    func testBurnedStaysAtMax() {
        // Test that burned items stay burned
        XCTAssertEqual(
            SRSCalculator.calculateNextStage(currentStage: .burned, meaningCorrect: true, readingCorrect: true),
            .burned
        )
    }

    // MARK: - Kanji Model Tests

    func testKanjiPrimaryMeaning() {
        let kanji = Kanji(
            character: "一",
            meanings: ["One", "First"],
            onyomi: ["いち"],
            kunyomi: ["ひと"],
            radicals: ["Ground"],
            strokeCount: 1,
            wanikaniId: 440,
            level: 1
        )

        XCTAssertEqual(kanji.primaryMeaning, "One")
    }

    func testKanjiAllReadings() {
        let kanji = Kanji(
            character: "一",
            meanings: ["One"],
            onyomi: ["いち", "いつ"],
            kunyomi: ["ひと"],
            radicals: [],
            strokeCount: 1,
            wanikaniId: 440,
            level: 1
        )

        XCTAssertEqual(kanji.allReadings.count, 3)
        XCTAssertTrue(kanji.allReadings.contains("いち"))
        XCTAssertTrue(kanji.allReadings.contains("いつ"))
        XCTAssertTrue(kanji.allReadings.contains("ひと"))
    }

    // MARK: - SRS Stage Tests

    func testSRSStageIsLearned() {
        XCTAssertFalse(SRSStage.lesson.isLearned)
        XCTAssertFalse(SRSStage.apprentice1.isLearned)
        XCTAssertFalse(SRSStage.apprentice4.isLearned)
        XCTAssertTrue(SRSStage.guru1.isLearned)
        XCTAssertTrue(SRSStage.master.isLearned)
        XCTAssertTrue(SRSStage.burned.isLearned)
    }

    func testSRSStageIsApprentice() {
        XCTAssertFalse(SRSStage.lesson.isApprentice)
        XCTAssertTrue(SRSStage.apprentice1.isApprentice)
        XCTAssertTrue(SRSStage.apprentice4.isApprentice)
        XCTAssertFalse(SRSStage.guru1.isApprentice)
    }

    // MARK: - Vocabulary Tests

    func testVocabularyPrimaryReading() {
        let vocab = Vocabulary(
            id: 2467,
            characters: "一",
            meanings: [Meaning(meaning: "One", primary: true)],
            readings: [
                Reading(reading: "いち", primary: true),
                Reading(reading: "ひとつ", primary: false)
            ],
            level: 1,
            slug: "一"
        )

        XCTAssertEqual(vocab.primaryReading, "いち")
    }

    func testVocabularyAllReadings() {
        let vocab = Vocabulary(
            id: 2467,
            characters: "一つ",
            meanings: [Meaning(meaning: "One Thing", primary: true)],
            readings: [
                Reading(reading: "ひとつ", primary: true)
            ],
            level: 1,
            slug: "一つ"
        )

        XCTAssertEqual(vocab.allReadings, ["ひとつ"])
    }
}
