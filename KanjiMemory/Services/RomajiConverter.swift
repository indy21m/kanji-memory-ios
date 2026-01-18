import Foundation

/// Converts romaji input to hiragana in real-time
/// Supports standard Hepburn romanization
struct RomajiConverter {

    // MARK: - Romaji to Hiragana Mapping

    private static let romajiMap: [String: String] = [
        // Basic vowels
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",

        // K-row
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",

        // S-row
        "sa": "さ", "si": "し", "su": "す", "se": "せ", "so": "そ",
        "shi": "し", "sha": "しゃ", "shu": "しゅ", "sho": "しょ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",

        // T-row
        "ta": "た", "ti": "ち", "tu": "つ", "te": "て", "to": "と",
        "chi": "ち", "tsu": "つ",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ",
        "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",

        // N-row
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        "n": "ん", "nn": "ん",

        // H-row
        "ha": "は", "hi": "ひ", "hu": "ふ", "he": "へ", "ho": "ほ",
        "fu": "ふ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",

        // M-row
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",

        // Y-row
        "ya": "や", "yu": "ゆ", "yo": "よ",

        // R-row
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",

        // W-row
        "wa": "わ", "wi": "ゐ", "we": "ゑ", "wo": "を",

        // G-row (voiced)
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",

        // Z-row (voiced)
        "za": "ざ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ji": "じ", "ja": "じゃ", "ju": "じゅ", "jo": "じょ",
        "zya": "じゃ", "zyu": "じゅ", "zyo": "じょ",

        // D-row (voiced)
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",

        // B-row (voiced)
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",

        // P-row (half-voiced)
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",

        // Small kana
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
        "xtu": "っ", "xtsu": "っ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        "ltu": "っ", "ltsu": "っ",

        // Long vowel mark
        "-": "ー",
    ]

    // Characters that can start a double consonant (っ)
    private static let doubleConsonants = Set(["kk", "ss", "tt", "pp", "cc", "gg", "dd", "bb", "zz", "jj", "ff", "hh", "mm", "rr"])

    // MARK: - Conversion

    /// Converts romaji string to hiragana
    /// Returns a tuple of (converted hiragana, remaining unconverted romaji buffer)
    static func convert(_ romaji: String) -> (hiragana: String, buffer: String) {
        var result = ""
        var buffer = ""

        let lowercased = romaji.lowercased()

        for char in lowercased {
            buffer.append(char)

            // Check for double consonant (っ)
            if buffer.count >= 2 {
                let lastTwo = String(buffer.suffix(2))
                if doubleConsonants.contains(lastTwo) && lastTwo.first == lastTwo.last {
                    result.append("っ")
                    buffer = String(buffer.last!)
                    continue
                }
            }

            // Try to find a match, starting from longest possible
            var matched = false
            for length in stride(from: min(buffer.count, 4), through: 1, by: -1) {
                let suffix = String(buffer.suffix(length))
                if let kana = romajiMap[suffix] {
                    // Found a match
                    result.append(kana)
                    buffer = String(buffer.dropLast(length))
                    matched = true
                    break
                }
            }

            // Handle standalone 'n' followed by non-vowel/non-y
            if !matched && buffer.count >= 2 && buffer.first == "n" {
                let second = buffer[buffer.index(after: buffer.startIndex)]
                if second != "a" && second != "i" && second != "u" && second != "e" && second != "o" && second != "y" && second != "n" {
                    result.append("ん")
                    buffer = String(buffer.dropFirst())

                    // Try to convert the remaining buffer
                    if let kana = romajiMap[buffer] {
                        result.append(kana)
                        buffer = ""
                    }
                }
            }

            // If buffer is getting too long and no match, might be invalid
            if buffer.count > 4 {
                // Just keep the last few characters
                result.append(String(buffer.dropLast(3)))
                buffer = String(buffer.suffix(3))
            }
        }

        return (result, buffer)
    }

    /// Converts romaji to hiragana for display, keeping buffer visible
    static func convertForDisplay(_ romaji: String) -> String {
        let (hiragana, buffer) = convert(romaji)
        return hiragana + buffer
    }

    /// Check if text is pure hiragana (no unconverted romaji)
    static func isPureHiragana(_ text: String) -> Bool {
        for char in text {
            let scalar = char.unicodeScalars.first!
            // Hiragana range: 0x3040-0x309F, also allow ー and spaces
            if !(scalar.value >= 0x3040 && scalar.value <= 0x309F) && char != "ー" && char != " " {
                return false
            }
        }
        return true
    }
}
