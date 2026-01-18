import SwiftUI

/// A reusable filter chip component with selection state
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill))
                .foregroundColor(isSelected ? color : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Filter chip with icon
struct IconFilterChip: View {
    let label: String
    let systemImage: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.tertiarySystemFill))
            .foregroundColor(isSelected ? color : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            FilterChip(label: "All", isSelected: true, color: .purple, action: {})
            FilterChip(label: "Kanji", isSelected: false, color: .purple, action: {})
            FilterChip(label: "Vocab", isSelected: false, color: .green, action: {})
        }

        HStack {
            IconFilterChip(label: "All Levels", systemImage: "slider.horizontal.3", isSelected: false, color: .purple, action: {})
            IconFilterChip(label: "Level 1-10", systemImage: "slider.horizontal.3", isSelected: true, color: .purple, action: {})
        }
    }
    .padding()
}
