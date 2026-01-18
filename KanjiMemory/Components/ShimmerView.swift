import SwiftUI

/// A shimmering loading placeholder view for skeleton loading states
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.2),
                    Color.gray.opacity(0.35),
                    Color.gray.opacity(0.2)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
            .animation(
                .linear(duration: 1.2)
                .repeatForever(autoreverses: false),
                value: phase
            )
        }
        .onAppear {
            phase = 1
        }
    }
}

/// A shimmer modifier that can be applied to any view
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: phase * geometry.size.width * 1.6 - geometry.size.width * 0.3)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
                .mask(content)
            )
            .onAppear {
                phase = 1
            }
    }
}

extension View {
    /// Adds a shimmer animation overlay to the view
    func shimmer() -> some View {
        modifier(Shimmer())
    }
}

// MARK: - Skeleton Components

/// Skeleton placeholder for loading kanji cards
struct KanjiCardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 44, height: 44)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 12)
                .shimmer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// Skeleton placeholder for loading level cards
struct LevelCardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 40, height: 40)
                .shimmer()

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 24, height: 12)
                        .shimmer()
                }
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 3)
                .shimmer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// Skeleton placeholder for detail page content
struct DetailSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Character placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 160)
                .shimmer()

            // Readings placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 80)
                .shimmer()

            // Mnemonic placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 120)
                .shimmer()
        }
        .padding()
    }
}

/// Skeleton placeholder for stats cards
struct StatsCardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 32, height: 32)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 40, height: 20)
                .shimmer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 50, height: 12)
                .shimmer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            KanjiCardSkeleton()
            KanjiCardSkeleton()
            KanjiCardSkeleton()
        }

        HStack {
            LevelCardSkeleton()
            LevelCardSkeleton()
            LevelCardSkeleton()
        }

        DetailSkeleton()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
