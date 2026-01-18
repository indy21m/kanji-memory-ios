import Foundation

/// Answer checking utility inspired by Tsurukame's implementation
/// Handles Japanese character conversion, fuzzy matching, and answer validation
struct AnswerChecker {

    // MARK: - Answer Result Types

    enum AnswerResult {
        case correct
        case incorrect
        case almostCorrect(distance: Int)  // For fuzzy matching
        case containsInvalidCharacters     // e.g., English in reading field
        case otherAcceptableReading        // Valid but not primary reading
    }

    // MARK: - Katakana to Hiragana Conversion

    /// Converts katakana to hiragana, preserving the long vowel mark (ー)
    /// Based on Tsurukame's convertKatakanaToHiragana implementation
    static func convertKatakanaToHiragana(_ text: String) -> String {
        // Handle ー (long vowel mark) specially - don't convert it
        if let dashIndex = text.firstIndex(of: "ー") {
            let before = String(text[..<dashIndex])
            let after = String(text[text.index(after: dashIndex)...])
            return convertKatakanaToHiragana(before) + "ー" + convertKatakanaToHiragana(after)
        }

        // Use StringTransform to convert katakana to hiragana
        return text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
    }

    // MARK: - Answer Normalization

    /// Normalizes an answer for comparison
    static func normalizeAnswer(_ text: String, forReading: Bool) -> String {
        var normalized = text
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        if forReading {
            // For readings:
            // - Convert katakana to hiragana (preserving ー)
            // - Remove wave dash variants
            // - Handle trailing 'n' → 'ん' conversion
            normalized = convertKatakanaToHiragana(normalized)
            normalized = normalized
                .replacingOccurrences(of: "〜", with: "")  // Wave dash
                .replacingOccurrences(of: "～", with: "")  // Fullwidth wave dash
                .replacingOccurrences(of: " ", with: "")  // Remove spaces in kana

            // Handle trailing 'n' that should be 'ん'
            // This helps users typing on English keyboards
            if normalized.hasSuffix("n") && !normalized.hasSuffix("nn") {
                // Check if it looks like romaji was entered
                let hasLatinChars = normalized.unicodeScalars.contains { scalar in
                    CharacterSet.lowercaseLetters.contains(scalar)
                }
                if hasLatinChars {
                    normalized = String(normalized.dropLast()) + "ん"
                }
            }
        } else {
            // For meanings:
            // - Lowercase and trim
            // - Remove punctuation that shouldn't affect matching
            normalized = normalized
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "/", with: "")
        }

        return normalized
    }

    // MARK: - Reading Check

    /// Checks if a reading answer is correct
    static func checkReading(
        answer: String,
        acceptedReadings: [String],
        autoConvertKatakana: Bool = true
    ) -> AnswerResult {
        var normalizedAnswer = answer.trimmingCharacters(in: .whitespaces)

        // Optionally convert katakana to hiragana
        if autoConvertKatakana {
            normalizedAnswer = convertKatakanaToHiragana(normalizedAnswer)
        }

        // Remove wave dash variants
        normalizedAnswer = normalizedAnswer
            .replacingOccurrences(of: "〜", with: "")
            .replacingOccurrences(of: "～", with: "")

        // Check for non-kana characters (invalid for reading)
        if containsNonKanaCharacters(normalizedAnswer) {
            return .containsInvalidCharacters
        }

        // Check against all accepted readings
        for (index, reading) in acceptedReadings.enumerated() {
            let normalizedReading = convertKatakanaToHiragana(reading)
            if normalizedAnswer == normalizedReading {
                return index == 0 ? .correct : .otherAcceptableReading
            }
        }

        return .incorrect
    }

    // MARK: - Meaning Check

    /// Checks if a meaning answer is correct
    static func checkMeaning(
        answer: String,
        acceptedMeanings: [String],
        fuzzyMatchingEnabled: Bool = true
    ) -> AnswerResult {
        let normalizedAnswer = normalizeAnswer(answer, forReading: false)

        // Check for Japanese characters (invalid for meaning)
        if containsJapaneseCharacters(normalizedAnswer) {
            return .containsInvalidCharacters
        }

        // Exact match check
        for meaning in acceptedMeanings {
            let normalizedMeaning = normalizeAnswer(meaning, forReading: false)
            if normalizedAnswer == normalizedMeaning {
                return .correct
            }
        }

        // Fuzzy matching (Levenshtein distance)
        if fuzzyMatchingEnabled {
            for meaning in acceptedMeanings {
                let normalizedMeaning = normalizeAnswer(meaning, forReading: false)
                let distance = levenshteinDistance(normalizedAnswer, normalizedMeaning)
                let tolerance = distanceTolerance(for: normalizedMeaning)

                if distance <= tolerance {
                    return .almostCorrect(distance: distance)
                }
            }
        }

        return .incorrect
    }

    // MARK: - Character Set Checks

    /// Checks if text contains non-kana characters
    static func containsNonKanaCharacters(_ text: String) -> Bool {
        let kanaSet = CharacterSet(charactersIn: Unicode.Scalar(0x3040)!...Unicode.Scalar(0x30FF)!)
            .union(CharacterSet(charactersIn: "ー"))  // Include long vowel mark

        for scalar in text.unicodeScalars {
            if !kanaSet.contains(scalar) && !CharacterSet.whitespaces.contains(scalar) {
                return true
            }
        }
        return false
    }

    /// Checks if text contains Japanese characters
    static func containsJapaneseCharacters(_ text: String) -> Bool {
        // Hiragana: 0x3040-0x309F, Katakana: 0x30A0-0x30FF, CJK: 0x4E00-0x9FAF
        let japaneseSet = CharacterSet(charactersIn: Unicode.Scalar(0x3040)!...Unicode.Scalar(0x30FF)!)
            .union(CharacterSet(charactersIn: Unicode.Scalar(0x4E00)!...Unicode.Scalar(0x9FAF)!))

        for scalar in text.unicodeScalars {
            if japaneseSet.contains(scalar) {
                return true
            }
        }
        return false
    }

    // MARK: - Levenshtein Distance (Fuzzy Matching)

    /// Calculates the Levenshtein distance between two strings
    /// Based on Tsurukame's implementation for typo tolerance
    static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    /// Determines the acceptable distance tolerance based on answer length
    /// Based on Tsurukame's distanceTolerance implementation
    static func distanceTolerance(for answer: String) -> Int {
        let length = answer.count
        if length <= 3 { return 0 }       // No typos allowed for short words
        if length <= 5 { return 1 }       // 1 typo for medium words
        if length <= 7 { return 2 }       // 2 typos for longer words
        return 2 + Int(floor(Double(length) / 7))  // Scale with length
    }
}
