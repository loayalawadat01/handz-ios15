//
//  FormComponents.swift
//  Handz
//
//  Shared pieces for forms (sign-up, Post a Job, settings):
//  labelled fields with errors under them, a step bar, day buttons,
//  choice cards, chips and a checkbox.
//

import SwiftUI

// MARK: - Labelled field with hint or error underneath

struct HandzFormField<Content: View>: View {
    let label: String
    var hint: String?
    var error: String?
    let content: Content

    init(_ label: String, hint: String? = nil, error: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.label = label
        self.hint = hint
        self.error = error
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textPrimary)

            content

            if let error = error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let hint = hint {
                Text(hint)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .animation(HandzMotion.safe(HandzMotion.quick), value: error)
    }
}

// MARK: - Step bar ("Step 2 of 3")

struct HandzStepBar: View {
    let current: Int   // starts at 1
    let total: Int

    init(current: Int, total: Int) {
        self.current = current
        self.total = max(total, 1)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? HandzColor.primary : HandzColor.border)
                    .frame(height: 6)
            }
        }
        .animation(HandzMotion.safe(HandzMotion.standard), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current) of \(total)")
    }
}

// MARK: - Day buttons (today + the next days)

/// A row of day buttons instead of a full calendar. Keeps the chosen time of day.
struct HandzDayPicker: View {
    @Binding var selection: Date
    let daysAhead: Int

    init(selection: Binding<Date>, daysAhead: Int) {
        self._selection = selection
        self.daysAhead = daysAhead
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayButton(day)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = Calendar.current.isDate(day, inSameDayAs: selection)
        return Button {
            pick(day)
        } label: {
            VStack(spacing: 2) {
                Text(topLabel(day))
                    .font(HandzTypography.captionBold)
                Text(day.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(day.formatted(.dateTime.month(.abbreviated)))
                    .font(HandzTypography.caption)
            }
            .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.textPrimary)
            .frame(width: 64, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? HandzColor.primary : HandzColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HandzColor.border, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0...daysAhead).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private func topLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tmrw" }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }

    private func pick(_ day: Date) {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: selection)
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = time.hour
        parts.minute = time.minute
        guard let newDate = calendar.date(from: parts) else { return }
        HandzHaptics.select()
        withHandzAnimation(HandzMotion.quick) { selection = newDate }
    }
}

// MARK: - Big choice card (e.g. "Hire workers" / "Find work")

struct HandzChoiceCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    init(icon: String, title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            HandzHaptics.select()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.primaryInk)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(isSelected ? HandzColor.primary : HandzColor.primaryTint))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                    Text(subtitle)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.primary : HandzColor.textFaint)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .fill(isSelected ? HandzColor.primaryTint : HandzColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .stroke(isSelected ? HandzColor.primary : HandzColor.border, lineWidth: isSelected ? 2 : 1)
            )
            .animation(HandzMotion.safe(HandzMotion.quick), value: isSelected)
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Small selectable chip (gender, options)

struct HandzSelectChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            HandzHaptics.select()
            action()
        } label: {
            Text(title)
                .font(HandzTypography.callout.weight(.semibold))
                .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Capsule().fill(isSelected ? HandzColor.primary : HandzColor.surface))
                .overlay(Capsule().stroke(HandzColor.border, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Radio row (one choice from a short list)

struct HandzRadioRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            HandzHaptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.primary : HandzColor.textFaint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Checkbox with text (terms)

struct HandzCheckbox<Content: View>: View {
    @Binding var isOn: Bool
    var hasError: Bool
    let label: Content

    init(isOn: Binding<Bool>, hasError: Bool = false, @ViewBuilder label: () -> Content) {
        self._isOn = isOn
        self.hasError = hasError
        self.label = label()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                HandzHaptics.select()
                withHandzAnimation(HandzMotion.quick) { isOn.toggle() }
            } label: {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isOn ? HandzColor.primary : (hasError ? HandzColor.danger : HandzColor.textFaint))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(HandzPressStyle())
            .accessibilityLabel(isOn ? "Agreed" : "Not agreed")
            .accessibilityAddTraits(isOn ? .isSelected : [])

            label
                .padding(.top, 10)
        }
    }
}

// MARK: - Helpers

extension String {
    /// The text without spaces or new lines at either end.
    var handzTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
