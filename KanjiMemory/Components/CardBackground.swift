import SwiftUI

/// A consistent card background style used throughout the app
struct CardBackground<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
            )
    }
}

/// View modifier for card background styling
struct CardBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let addShadow: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(
                        color: addShadow ? .black.opacity(0.04) : .clear,
                        radius: 3,
                        x: 0,
                        y: 2
                    )
            )
    }
}

extension View {
    /// Applies the standard card background style
    func cardBackground(
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        addShadow: Bool = true
    ) -> some View {
        modifier(CardBackgroundModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            addShadow: addShadow
        ))
    }
}

// MARK: - Gradient Card Backgrounds

/// A card with gradient border for special emphasis
struct GradientBorderCard<Content: View>: View {
    let content: Content
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    init(
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
            .shadow(color: .purple.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

/// An animated gradient border card
struct AnimatedGradientBorderCard<Content: View>: View {
    let content: Content
    let lineWidth: CGFloat
    let cornerRadius: CGFloat

    @State private var rotation: Double = 0

    init(
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.purple, .pink, .purple]),
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .shadow(color: .purple.opacity(0.2), radius: 10, x: 0, y: 4)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - SRS Colored Card

/// A card with SRS stage-colored accent
struct SRSCard<Content: View>: View {
    let content: Content
    let srsColor: Color
    let cornerRadius: CGFloat

    init(
        srsColor: Color,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.srsColor = srsColor
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .background(
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.secondarySystemGroupedBackground))

                    // SRS color accent strip
                    HStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(srsColor)
                            .frame(width: 4)
                        Spacer()
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CardBackground {
                Text("Standard Card Background")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Card with modifier")
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()

            GradientBorderCard {
                Text("Gradient Border Card")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            AnimatedGradientBorderCard {
                Text("Animated Border")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SRSCard(srsColor: .purple) {
                Text("SRS Colored Card (Guru)")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SRSCard(srsColor: .pink) {
                Text("SRS Colored Card (Apprentice)")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
