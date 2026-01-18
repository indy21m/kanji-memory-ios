import UIKit

/// Centralized haptic feedback manager for premium tactile experience
enum HapticManager {

    // MARK: - Impact Feedback

    /// Light impact for subtle interactions (button taps, selections)
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Medium impact for more prominent interactions (card flips, toggles)
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Heavy impact for significant actions (level unlocks, achievements)
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Soft impact for gentle feedback
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Rigid impact for firm feedback
    static func rigid() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Success notification (correct answers, completions)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Warning notification (almost correct, attention needed)
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// Error notification (incorrect answers, failures)
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection change (tab switches, scroll snapping)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Convenience Methods

    /// Review answer feedback based on correctness
    static func reviewAnswer(correct: Bool) {
        if correct {
            success()
        } else {
            error()
        }
    }

    /// Button tap feedback (standard light impact)
    static func buttonTap() {
        light()
    }

    /// Card flip feedback
    static func cardFlip() {
        medium()
    }

    /// Level unlock celebration
    static func levelUnlock() {
        DispatchQueue.main.async {
            success()
            // Double haptic for celebration effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                heavy()
            }
        }
    }

    /// Session complete celebration
    static func sessionComplete() {
        DispatchQueue.main.async {
            success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                success()
            }
        }
    }
}
