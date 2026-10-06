//
//  DesignSystem.swift
//  Handz
//
//  The "Neighborly" look: soft, rounded, teal.
//  Every screen takes its colors, fonts, spacing, motion and vibration from here,
//  so changing something in this file changes it across the whole app.
//

import SwiftUI
import UIKit

// MARK: - Colors
// Each color has a light-mode and a dark-mode value and switches automatically.

enum HandzColor {
    // Screens, cards, lines
    static let background    = dynamic(0xF2F6F4, 0x0D1613)
    static let surface       = dynamic(0xFFFFFF, 0x16221E)
    static let border        = dynamic(0xDCE7E3, 0x2A3A35)

    // Text
    static let textPrimary   = dynamic(0x12302A, 0xE6F0EC)
    static let textSecondary = dynamic(0x4A5F59, 0xA3B8B1)
    static let textFaint     = dynamic(0x7F978F, 0x6E857E)

    // Teal: main buttons, links, selected tab
    static let primary       = dynamic(0x0F766E, 0x2BA898)
    static let primaryTint   = dynamic(0xDDF1EC, 0x133B35)
    static let primaryInk    = dynamic(0x0B4F49, 0x9EE6DC)

    // Green: money and "yes" (I'm Interested, Paid)
    static let accent        = dynamic(0x157F3D, 0x2EA85A)
    static let accentTint    = dynamic(0xE1F4E7, 0x14301F)
    static let accentInk     = dynamic(0x0F5A2B, 0x8FE0AA)

    // Clay: things that need the user's attention
    static let warning       = dynamic(0xB4462A, 0xF08F68)
    static let warningTint   = dynamic(0xFCEBE5, 0x3A2219)
    static let warningInk    = dynamic(0x8A3218, 0xF5B08F)

    // Red: errors, cancel, Not Now
    static let danger        = dynamic(0xB42318, 0xEF6A5F)
    static let dangerTint    = dynamic(0xFCEBEA, 0x3A1A18)
    static let dangerInk     = dynamic(0x8F1C13, 0xF5A39B)

    // Text and icons that sit ON a filled button (white in light mode, dark in dark mode)
    static let onFill        = dynamic(0xFFFFFF, 0x04201B)

    // Ink: the main buttons and the one standout banner on a screen.
    // Near-black in light mode; it flips to light in dark mode so it never disappears.
    static let ink           = dynamic(0x12302A, 0xE6F0EC)
    static let onInk         = dynamic(0x5CD6C5, 0x0F766E)   // bright teal text and icons on ink
    static let onInkText     = dynamic(0xF2F6F4, 0x12302A)   // titles on ink
    static let onInkFaint    = dynamic(0xA3B8B1, 0x4A5F59)   // small text on ink

    // Job status colors (used by Job.status.color)
    static let statusOpen       = primary                         // waiting for workers
    static let statusInProgress = dynamic(0x2F5AA8, 0x8FB0EA)     // on the way / working
    static let statusPending    = warning                         // needs payment or action
    static let statusCompleted  = accent                          // done and paid
    
    // Soft card shadow, and the dark layer behind pop-ups
    static let shadow        = dynamic(0x12302A, 0x000000)
    static let scrim         = Color.black.opacity(0.55)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Spacing

enum HandzSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner radius

enum HandzRadius {
    static let sm: CGFloat = 12   // small tiles, photos
    static let md: CGFloat = 16   // text fields, inner boxes
    static let lg: CGFloat = 26   // cards and tiles
    static let xl: CGFloat = 32   // bottom sheets, pop-ups
}

// MARK: - Fonts
// Headings use Varela Round (the font file in the app). If the file is missing,
// they fall back to Apple's rounded font, so the app never breaks.
// All other text uses Apple's rounded system font.
// Everything grows and shrinks with the user's text-size setting.

enum HandzTypography {
    static let largeTitle   = heading(32, relativeTo: .largeTitle)
    static let title        = heading(26, relativeTo: .title)
    static let sectionTitle = heading(20, relativeTo: .title3)

    static let headline     = Font.system(.headline, design: .rounded)                    // 17 semibold
    static let body         = Font.system(.body, design: .rounded)                        // 17
    static let callout      = Font.system(.callout, design: .rounded)                     // 16
    static let caption      = Font.system(.footnote, design: .rounded)                    // 13
    static let captionBold  = Font.system(.footnote, design: .rounded).weight(.semibold)  // 13 semibold
    static let button       = Font.system(.headline, design: .rounded).weight(.bold)

    // Small bold labels above big numbers ("THIS WEEK"), shown in capitals
    static let eyebrow      = Font.system(.caption, design: .rounded).weight(.bold)

    // Money and timers: fixed-width digits so numbers don't jiggle when they change
    static let money        = Font.system(.title, design: .rounded).weight(.bold).monospacedDigit()
    static let moneySmall   = Font.system(.headline, design: .rounded).monospacedDigit()

    static let headingFontName = "VarelaRound-Regular"

    private static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if UIFont(name: headingFontName, size: size) != nil {
            return Font.custom(headingFontName, size: size, relativeTo: style)
        }
        return Font.system(style, design: .rounded).weight(.semibold)
    }
}

// MARK: - Motion
// Springs feel natural. If the user turned on Reduce Motion in iPhone settings,
// every movement becomes a simple fade.

enum HandzMotion {
    static let quick    = Animation.spring(response: 0.25, dampingFraction: 0.9)   // presses, toggles
    static let standard = Animation.spring(response: 0.4, dampingFraction: 0.85)   // cards, sheets, lists
    static let bouncy   = Animation.spring(response: 0.45, dampingFraction: 0.7)   // big moments only
    static let exit     = Animation.easeIn(duration: 0.18)                          // closing is faster than opening
    static let fade     = Animation.easeInOut(duration: 0.2)
    static let staggerStep: Double = 0.04                                           // delay between list items

    static func safe(_ animation: Animation) -> Animation {
        UIAccessibility.isReduceMotionEnabled ? fade : animation
    }
}

/// Use this instead of `withAnimation` so Reduce Motion is respected everywhere.
func withHandzAnimation<Result>(_ animation: Animation = HandzMotion.standard,
                                _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(HandzMotion.safe(animation), body)
}

// MARK: - Vibration (haptics)
// Call these right when the thing happens (from the screen or its view model).

enum HandzHaptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }    // small taps, tabs
    static func press()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }   // I'm Interested, Hire
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }            // picking a day, a chip
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) } // paid, job done
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) } // late-cancel fee
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }   // wrong code
}

// MARK: - Buttons

/// Big filled pill button. Ink (near-black) with bright teal text by default,
/// red when `isDestructive`, or any color you pass (then the text is white).
/// `compact` is for two buttons side by side.
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool
    var color: Color?
    var compact: Bool
    @Environment(\.isEnabled) var isEnabled

    init(isDestructive: Bool = false, color: Color? = nil, compact: Bool = false) {
        self.isDestructive = isDestructive
        self.color = color
        self.compact = compact
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandzTypography.button)
            .foregroundColor(textColor)
            .multilineTextAlignment(.center)
            .lineLimit(compact ? 1 : nil)
            .minimumScaleFactor(compact ? 0.8 : 1)
            .frame(maxWidth: .infinity, minHeight: compact ? 54 : 56)
            .padding(.horizontal, compact ? HandzSpacing.md : HandzSpacing.lg)
            .background(Capsule().fill(fillColor))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }

    private var fillColor: Color {
        if isDestructive { return HandzColor.danger }
        return color ?? HandzColor.ink
    }

    private var textColor: Color {
        (isDestructive || color != nil) ? HandzColor.onFill : HandzColor.onInk
    }
}

/// White pill button for the second choice on a screen.
struct SecondaryButtonStyle: ButtonStyle {
    var compact: Bool
    @Environment(\.isEnabled) var isEnabled

    init(compact: Bool = false) {
        self.compact = compact
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandzTypography.button)
            .foregroundColor(HandzColor.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(compact ? 1 : nil)
            .minimumScaleFactor(compact ? 0.8 : 1)
            .frame(maxWidth: .infinity, minHeight: compact ? 54 : 56)
            .padding(.horizontal, compact ? HandzSpacing.md : HandzSpacing.lg)
            .background(Capsule().fill(HandzColor.surface))
            .overlay(Capsule().stroke(HandzColor.border, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}

/// For tappable cards and rows: a gentle press-down, no color change.
struct HandzPressStyle: ButtonStyle {
    init() {}

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}

// MARK: - Cards

struct CardBackground: ViewModifier {
    var padding: CGFloat
    @Environment(\.colorScheme) var colorScheme

    init(padding: CGFloat = HandzSpacing.md) {
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .fill(HandzColor.surface)
                    .shadow(color: HandzColor.shadow.opacity(colorScheme == .dark ? 0 : 0.06),
                            radius: 18, x: 0, y: 8)
            )
            .overlay(
                // In dark mode shadows don't show, so cards get a thin outline instead
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .stroke(HandzColor.border, lineWidth: colorScheme == .dark ? 1 : 0)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = HandzSpacing.md) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// The light green-grey background behind every screen.
    func handzScreenBackground() -> some View {
        background(HandzColor.background.ignoresSafeArea())
    }
}

// MARK: - Status chips ("On the way", "2 of 2 hired", "Paid")

struct HandzChip: View {
    enum Kind { case info, success, attention, danger, neutral }

    let text: String
    var icon: String? = nil          // SF Symbol name, e.g. "checkmark"
    var kind: Kind = .info

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(HandzTypography.captionBold)
                .lineLimit(1)
        }
        .foregroundColor(colors.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(colors.fill))
    }

    private var colors: (text: Color, fill: Color) {
        switch kind {
        case .info:      return (HandzColor.primaryInk, HandzColor.primaryTint)
        case .success:   return (HandzColor.accentInk, HandzColor.accentTint)
        case .attention: return (HandzColor.warningInk, HandzColor.warningTint)
        case .danger:    return (HandzColor.dangerInk, HandzColor.dangerTint)
        case .neutral:   return (HandzColor.textSecondary, HandzColor.background)
        }
    }
}

// MARK: - Text fields
// Teal outline while typing, red outline when there's a mistake.

struct HandzFieldStyle: ViewModifier {
    var isFocused: Bool
    var hasError: Bool

    init(isFocused: Bool, hasError: Bool) {
        self.isFocused = isFocused
        self.hasError = hasError
    }

    func body(content: Content) -> some View {
        content
            .font(HandzTypography.body)
            .foregroundColor(HandzColor.textPrimary)
            .padding(.horizontal, HandzSpacing.md)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: (isFocused || hasError) ? 2 : 1)
            )
            .animation(HandzMotion.quick, value: isFocused)
            .animation(HandzMotion.quick, value: hasError)
    }

    private var borderColor: Color {
        if hasError { return HandzColor.danger }
        return isFocused ? HandzColor.primary : HandzColor.textFaint
    }
}

extension View {
    func handzField(isFocused: Bool = false, hasError: Bool = false) -> some View {
        modifier(HandzFieldStyle(isFocused: isFocused, hasError: hasError))
    }
}

// MARK: - Loading placeholders (skeletons)
// Shows grey, softly pulsing shapes in place of real content while it loads.

struct HandzPulse: ViewModifier {
    var active: Bool
    @State private var dimmed = false

    init(active: Bool) {
        self.active = active
    }

    func body(content: Content) -> some View {
        content
            .opacity(active && dimmed ? 0.45 : 1)
            .onAppear { startIfNeeded() }
            .onChange(of: active) { _ in startIfNeeded() }
    }

    private func startIfNeeded() {
        guard active, !UIAccessibility.isReduceMotionEnabled else {
            dimmed = false
            return
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            dimmed = true
        }
    }
}

extension View {
    func loadingPlaceholder(_ isLoading: Bool) -> some View {
        self
            .redacted(reason: isLoading ? .placeholder : [])
            .modifier(HandzPulse(active: isLoading))
            .allowsHitTesting(!isLoading)
    }
}

// MARK: - Shake (wrong code, failed check-in)
// Add 1 to the trigger inside withAnimation(.linear(duration: 0.4)) to shake once.

struct HandzShake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = 8 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

extension View {
    func handzShake(_ trigger: Int) -> some View {
        modifier(HandzShake(animatableData: CGFloat(trigger)))
    }
}
