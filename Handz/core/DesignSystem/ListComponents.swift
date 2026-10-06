//
//  ListComponents.swift
//  Handz
//
//  Shared pieces for list screens (My Jobs, Find Work, My Work, Messages, Payments):
//  friendly empty states, loading placeholders and an error card with "Try again".
//

import SwiftUI

// MARK: - Empty state ("No jobs yet" + what to do next)

struct HandzEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(icon: String, title: String, message: String,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 64, height: 64)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)

            Text(title)
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

// MARK: - Loading placeholders (pulsing grey cards)

struct HandzLoadingList: View {
    var count: Int

    init(count: Int = 3) {
        self.count = count
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Help moving a two bedroom flat")
                        .font(HandzTypography.headline)
                    Text("Sat, Oct 4 · 9:00 AM · Decatur")
                        .font(HandzTypography.caption)
                    Text("2 workers · 4 hours")
                        .font(HandzTypography.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
        .loadingPlaceholder(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

// MARK: - Error card with "Try again"

struct HandzErrorCard: View {
    let message: String
    let retry: () -> Void

    init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.dangerInk)
            Button("Try again", action: retry)
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Section header with an optional count ("Upcoming · 3")

struct HandzSectionHeader: View {
    let title: String
    var count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
            if let count = count {
                Text("\(count)")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.primaryInk)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Capsule().fill(HandzColor.primaryTint))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
