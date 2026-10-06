//
//  StyleComponents.swift
//  Handz
//
//  The clean "money app" style used on Home, Payments and Receipts:
//  big numbers with small cents, small capital labels, white tiles,
//  one dark ink banner, and simple lists. Colors still come from HandzColor.
//

import SwiftUI

// MARK: - Big amount ("$1,210" big, ".75" smaller)

struct HandzAmountText: View {
    let amount: Double
    var size: CGFloat
    var color: Color
    var prefix: String

    init(_ amount: Double, size: CGFloat = 46, color: Color = HandzColor.textPrimary, prefix: String = "") {
        self.amount = amount
        self.size = size
        self.color = color
        self.prefix = prefix
    }

    var body: some View {
        let parts = HandzMoney.split(amount)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(prefix + parts.whole)
                .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
            Text(parts.cents)
                .font(.system(size: size * 0.55, weight: .bold, design: .rounded).monospacedDigit())
                .opacity(0.5)
        }
        .foregroundColor(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prefix + HandzMoney.text(amount))
    }
}

enum HandzMoney {
    private static let style = FloatingPointFormatStyle<Double>.Currency(code: "USD").locale(Locale(identifier: "en_US"))

    /// "$1,210.75"
    static func text(_ amount: Double) -> String {
        amount.formatted(style)
    }

    /// ("$1,210", ".75")
    static func split(_ amount: Double) -> (whole: String, cents: String) {
        let full = text(amount)
        guard let dot = full.lastIndex(of: ".") else { return (full, "") }
        return (String(full[..<dot]), String(full[dot...]))
    }
}

/// Counts an amount up (or down) to a new value when it changes inside withAnimation.
/// Use it like: EmptyView().modifier(CountingAmount(amount: shown, size: 46))
struct CountingAmount: ViewModifier, Animatable {
    var amount: Double
    var size: CGFloat
    var color: Color
    var prefix: String

    init(amount: Double, size: CGFloat = 46, color: Color = HandzColor.textPrimary, prefix: String = "") {
        self.amount = amount
        self.size = size
        self.color = color
        self.prefix = prefix
    }

    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func body(content: Content) -> some View {
        HandzAmountText(amount, size: size, color: color, prefix: prefix)
    }
}

// MARK: - Small capital label above a number ("THIS WEEK")

struct HandzEyebrow: View {
    let text: String
    var color: Color

    init(_ text: String, color: Color = HandzColor.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(HandzTypography.eyebrow)
            .tracking(0.8)
            .foregroundColor(color)
    }
}

// MARK: - Round icon in a soft circle

struct HandzIconBubble: View {
    let icon: String
    var text: Color
    var fill: Color
    var size: CGFloat

    init(_ icon: String, text: Color = HandzColor.primaryInk, fill: Color = HandzColor.primaryTint, size: CGFloat = 42) {
        self.icon = icon
        self.text = text
        self.fill = fill
        self.size = size
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(text)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .accessibilityHidden(true)
    }
}

// MARK: - Tile (two per row): icon, a bold title and one line under it

struct HandzTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var highlight: Bool

    init(icon: String, title: String, subtitle: String, highlight: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.highlight = highlight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(highlight ? HandzColor.onFill : HandzColor.primaryInk)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(highlight ? HandzColor.primary : HandzColor.primaryTint)
                    )
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(HandzColor.textFaint)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 14)

            Text(title)
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(HandzTypography.caption)
                .foregroundColor(highlight ? HandzColor.primaryInk : HandzColor.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .cardStyle(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

/// Two tiles side by side.
struct HandzTileRow<Left: View, Right: View>: View {
    let left: Left
    let right: Right

    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            left.frame(maxWidth: .infinity)
            right.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - The one dark ink banner on a screen

struct HandzInkBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    var trailing: String?

    init(icon: String, title: String, subtitle: String, trailing: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(HandzColor.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(HandzColor.onInk))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.onInkText)
                    .lineLimit(2)
                Text(subtitle)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.onInkFaint)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(HandzTypography.moneySmall.weight(.bold))
                    .foregroundColor(HandzColor.onInk)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundColor(HandzColor.onInk)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(HandzColor.ink)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Clean list: rows inside one white card, no lines between them

struct HandzListGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 0)
    }
}

struct HandzListRow<Leading: View>: View {
    let title: String
    let subtitle: String
    var trailing: String?
    var trailingDetail: String?
    var trailingColor: Color
    var showsChevron: Bool
    let leading: Leading

    init(title: String,
         subtitle: String,
         trailing: String? = nil,
         trailingDetail: String? = nil,
         trailingColor: Color = HandzColor.textPrimary,
         showsChevron: Bool = false,
         @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.trailingDetail = trailingDetail
        self.trailingColor = trailingColor
        self.showsChevron = showsChevron
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if trailing != nil || trailingDetail != nil {
                VStack(alignment: .trailing, spacing: 3) {
                    if let trailing {
                        Text(trailing)
                            .font(HandzTypography.moneySmall.weight(.bold))
                            .foregroundColor(trailingColor)
                    }
                    if let trailingDetail {
                        Text(trailingDetail)
                            .font(HandzTypography.caption)
                            .foregroundColor(HandzColor.textFaint)
                    }
                }
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(HandzColor.textFaint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Soft highlight while a list row is pressed.
struct HandzRowPressStyle: ButtonStyle {
    init() {}

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? HandzColor.background : Color.clear)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}

// MARK: - Section title with an optional "See all"

struct HandzSectionTitle: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(HandzTypography.callout.weight(.bold))
                    .foregroundColor(HandzColor.primary)
                    .frame(minHeight: 44)
            }
        }
    }
}
