import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Design System Constants 
struct DesignSystem {
    // Spacing
    static let spacing = (
        xs: CGFloat(2),
        sm: CGFloat(4),
        md: CGFloat(8),
        lg: CGFloat(12),
        xl: CGFloat(16),
        xxl: CGFloat(20),
        xxxl: CGFloat(24)
    )

    // Padding
    static let padding = (
        xs: CGFloat(2),
        sm: CGFloat(4),
        md: CGFloat(8),
        lg: CGFloat(12),
        xl: CGFloat(16),
        xxl: CGFloat(20)
    )

    // Corner Radius
    static let cornerRadius = (
        sm: CGFloat(4),
        md: CGFloat(6),
        lg: CGFloat(8),
        xl: CGFloat(12),
        xxl: CGFloat(16)
    )

    // Shadows
    static let shadow = (
        sm: (radius: CGFloat(2), opacity: 0.05),
        md: (radius: CGFloat(4), opacity: 0.08),
        lg: (radius: CGFloat(6), opacity: 0.10),
        xl: (radius: CGFloat(8), opacity: 0.12)
    )

    // Icon Sizes
    static let iconSize = (
        xs: CGFloat(10),
        sm: CGFloat(12),
        md: CGFloat(16),
        lg: CGFloat(20),
        xl: CGFloat(24),
        xxl: CGFloat(32),
        xxxl: CGFloat(40)
    )

    // Button Heights
    static let buttonHeight = (
        xs: CGFloat(20),
        sm: CGFloat(28),
        md: CGFloat(36),
        lg: CGFloat(48),
        xl: CGFloat(60)
    )

    // Card Heights
    static let cardHeight = (
        xs: CGFloat(40),
        sm: CGFloat(60),
        md: CGFloat(90),
        lg: CGFloat(100),
        xl: CGFloat(120)
    )
    
    // Colors
    static let colors = (
        primary: Color.primary,
        secondary: Color.secondary,
        tertiary: Color(.tertiaryLabel),
        accent: Color.accentColor,
        background: Color(.systemBackground),
        groupedBackground: Color(.systemGroupedBackground),
        success: Color.green,
        warning: Color.orange,
        error: Color.red,
        info: Color.blue
    )
}

// MARK: - Custom View Modifiers
struct CardStyle: ViewModifier {
    var isSelected: Bool = false
    var isHovering: Bool = false

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(
                color: .black.opacity(DesignSystem.shadow.md.opacity),
                radius: DesignSystem.shadow.md.radius,
                x: 0,
                y: 4
            )
    }
}

struct RoundedProjectManagerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.xl))
            .shadow(
                color: .black.opacity(DesignSystem.shadow.lg.opacity),
                radius: DesignSystem.shadow.lg.radius,
                x: 0,
                y: 6
            )
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func cardStyle(isSelected: Bool = false) -> some View {
        self.modifier(CardStyle(isSelected: isSelected))
    }
    
    func roundedProjectManagerStyle() -> some View {
        self.modifier(RoundedProjectManagerStyle())
    }
    
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
}

// MARK: - Action Card Style Enum
enum ActionCardStyle {
    case prominent
    case secondary
}

// MARK: - Reusable UI Components

struct WindowCountIndicator: View {
    let count: Int

    var body: some View {
        Label("\(count)", systemImage: "rectangle.3.group")
            .font(.headline)
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.xs)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

struct CircularButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.md))
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.buttonHeight.md, height: DesignSystem.buttonHeight.md)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignSystem.spacing.md) {
            IconBadge(icon: icon)

            VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct IconBadge: View {
    let icon: String
    var color: Color = Color.accentColor

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: DesignSystem.iconSize.lg))
            .foregroundStyle(color)
            .frame(width: DesignSystem.iconSize.xl, height: DesignSystem.iconSize.xl)
    }
}

struct PrimaryActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var style: ActionCardStyle = .secondary
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(style == .prominent ? .white : Color.accentColor)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(style == .prominent ? .white : .primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(style == .prominent ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                .fill(style == .prominent ? Color.accentColor : Color.secondary.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isDestructive: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.md))
                    .foregroundStyle(isDestructive ? .red : .secondary)

                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isDestructive ? .red : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.buttonHeight.lg)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md)
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md)
                        .strokeBorder(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 4 : 2)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct DataImportActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var style: ActionCardStyle = .secondary
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(style == .prominent ? .white : Color.accentColor)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(style == .prominent ? .white : .primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(style == .prominent ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.md)
            .padding(DesignSystem.padding.md)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                .fill(style == .prominent ? Color.green : Color.secondary.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg)
                        .stroke(.white.opacity(isHovered ? 0.3 : 0.1), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 12 : 6, x: 0, y: isHovered ? 6 : 3)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct WindowSizeBadge: View {
    let width: Double
    let height: Double

    var body: some View {
        Text("\(Int(width))×\(Int(height))")
            .font(.caption2)
            .fontDesign(.monospaced)
            .padding(.horizontal, DesignSystem.padding.sm)
            .padding(.vertical, DesignSystem.padding.xs)
            .background(Color.secondary.opacity(0.2))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }
}

struct EmptyStateView: View {
    var title: String = "No Active Views"
    var subtitle: String = "Create a new view to get started"
    var icon: String = "rectangle.dashed"

    var body: some View {
        VStack(spacing: DesignSystem.spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.xl))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignSystem.cardHeight.md)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
    }
}

// MARK: - Home View Components

struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var color: Color = .accentColor
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl, weight: .medium))
                    .foregroundStyle(color)

                VStack(spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.cardHeight.lg)
            .padding(DesignSystem.padding.lg)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.xl)
                .fill(Color.secondary.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.xl)
                        .strokeBorder(color.opacity(isHovered ? 0.5 : 0.2), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 16 : 8, x: 0, y: isHovered ? 8 : 4)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct UserProfileButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: DesignSystem.iconSize.lg))
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("User")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Pro Account")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: DesignSystem.iconSize.xs))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SettingsButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: DesignSystem.iconSize.md))
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.buttonHeight.md, height: DesignSystem.buttonHeight.md)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Button Styles

struct VisionOSButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DataTableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CurvedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.padding.lg)
            .padding(.vertical, DesignSystem.padding.md)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.xl))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Spatial Components

struct SpatialControlButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var isSelected: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.sm))
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ExportButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: DesignSystem.iconSize.sm))
                
                Text("Export")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(Color.blue)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Import Components

struct ImportMethodButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.lg))
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.padding.lg)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct FormatButton: View {
    let format: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(format)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DesignSystem.padding.md)
                .padding(.vertical, DesignSystem.padding.sm)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Charts Components

struct ControlButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .padding(.horizontal, DesignSystem.padding.md)
                .padding(.vertical, DesignSystem.padding.sm)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Recent File Components

struct RecentFileButton: View {
    let fileName: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: DesignSystem.iconSize.sm))
                    .foregroundStyle(.secondary)
                
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.iconSize.xs))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DesignSystem.padding.md)
            .padding(.vertical, DesignSystem.padding.sm)
            .background(Color.secondary.opacity(isHovered ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.md))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Spatial Metadata Components

struct SpatialHeaderView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignSystem.spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.xl))
                .foregroundStyle(Color.accentColor)
                .frame(width: DesignSystem.iconSize.xxl, height: DesignSystem.iconSize.xxl)

            VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.padding.xl)
        .cardStyle()
    }
}

struct EmptyStateSection: View {
    let title: String
    let subtitle: String
    let icon: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.iconSize.xxxl))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignSystem.spacing.sm) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.padding.xxl)
        .cardStyle()
    }
}

struct ActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconSize.xl))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: DesignSystem.iconSize.xxl, height: DesignSystem.iconSize.xxl)

                VStack(alignment: .leading, spacing: DesignSystem.spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.iconSize.sm))
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignSystem.padding.lg)
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(isHovered ? 0.1 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius.lg))
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Error Types
enum FileImportError: Error, LocalizedError {
    case noData
    case invalidFormat
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data found in the file"
        case .invalidFormat:
            return "Invalid file format"
        case .parsingFailed:
            return "Failed to parse the data"
        }
    }
}