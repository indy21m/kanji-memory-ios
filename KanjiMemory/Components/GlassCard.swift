import SwiftUI

/// A glassmorphism-style card background modifier
/// Provides a subtle, modern glass effect with proper dark mode support
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: shadowRadius,
                        y: 5
                    )
            )
    }
}

/// A more prominent glass card with border
struct GlassCardWithBorder: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    var borderColor: Color = .purple

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: 10,
                        y: 5
                    )
            )
    }
}

/// A gradient glass card with animated border
struct GradientGlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    var gradientColors: [Color] = [.purple, .pink]

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(colorScheme == .dark ? 0.1 : 0.05) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 10,
                    y: 5
                )
            )
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a glassmorphism card style
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    /// Applies a glass card with colored border
    func glassCardWithBorder(cornerRadius: CGFloat = 16, borderColor: Color = .purple) -> some View {
        modifier(GlassCardWithBorder(cornerRadius: cornerRadius, borderColor: borderColor))
    }

    /// Applies a glass card with gradient overlay
    func gradientGlassCard(cornerRadius: CGFloat = 16, colors: [Color] = [.purple, .pink]) -> some View {
        modifier(GradientGlassCard(cornerRadius: cornerRadius, gradientColors: colors))
    }
}

#Preview {
    ZStack {
        // Background gradient
        LinearGradient(
            colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 20) {
            // Basic glass card
            VStack {
                Text("Basic Glass Card")
                    .font(.headline)
                Text("Subtle, modern appearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassCard()

            // Glass card with border
            VStack {
                Text("Glass Card with Border")
                    .font(.headline)
                Text("Adds a colored accent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassCardWithBorder(borderColor: .blue)

            // Gradient glass card
            VStack {
                Text("Gradient Glass Card")
                    .font(.headline)
                Text("Premium feel with gradient")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .gradientGlassCard()
        }
        .padding()
    }
}
