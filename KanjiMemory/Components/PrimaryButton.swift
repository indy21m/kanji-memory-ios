import SwiftUI

/// A primary action button with gradient styling and haptic feedback
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.buttonTap()
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }

                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isDisabled || isLoading {
                        Color.gray.opacity(0.5)
                    } else {
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isDisabled ? .clear : .purple.opacity(0.3), radius: 8, y: 4)
        }
        .disabled(isDisabled || isLoading)
    }
}

/// A secondary button with outline styling
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.buttonTap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }

                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.purple.opacity(0.5), lineWidth: 1.5)
                    .background(Color.purple.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

/// A compact pill button for inline actions
struct PillButton: View {
    let title: String
    let icon: String?
    let style: PillButtonStyle
    let isLoading: Bool
    let action: () -> Void

    enum PillButtonStyle {
        case gradient
        case tinted(Color)
        case outline

        var gradient: LinearGradient {
            switch self {
            case .gradient:
                return LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .tinted(let color):
                return LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            case .outline:
                return LinearGradient(
                    colors: [.clear, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: PillButtonStyle = .gradient,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button {
            HapticManager.light()
            action()
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.7)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.medium))
                }

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundView)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .gradient, .tinted:
            return .white
        case .outline:
            return .purple
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .gradient:
            style.gradient
        case .tinted:
            style.gradient
        case .outline:
            Capsule()
                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                .background(Color.purple.opacity(0.05))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton("Start Review", icon: "brain.head.profile") {
            print("Primary tapped")
        }

        PrimaryButton("Loading...", isLoading: true) {
            print("Primary tapped")
        }

        PrimaryButton("Disabled", isDisabled: true) {
            print("Primary tapped")
        }

        SecondaryButton("Cancel", icon: "xmark") {
            print("Secondary tapped")
        }

        HStack(spacing: 12) {
            PillButton("Generate", icon: "sparkles", style: .gradient) {
                print("Pill tapped")
            }

            PillButton("Save", icon: "checkmark", style: .tinted(.green)) {
                print("Pill tapped")
            }

            PillButton("Edit", style: .outline) {
                print("Pill tapped")
            }
        }
    }
    .padding()
}
