import SwiftUI
import UIKit

/// The pop-up a worker sees when a new job near them matches their skills.
/// - Slides up over the app (the background dims).
/// - "I'm Interested" turns into a green "Sent" check with a vibration, then the pop-up closes.
/// - "Not Now" just closes it.
/// - If sending fails, the reason shows right above the buttons.
struct JobDispatchPopupView: View {
    let job: DispatchJob
    /// Sends the "I'm interested" request. Returns nil when it worked, or the error message.
    var onInterested: () async -> String?
    var onNotNow: () -> Void
    /// Called after the short "Sent" moment, to close the pop-up.
    var onDone: () -> Void
    /// Reports how tall the pop-up needs to be, so the sheet fits it exactly.
    var onHeightChange: (CGFloat) -> Void

    private enum Phase { case idle, sending, sent }

    @State private var phase: Phase = .idle
    @State private var errorMessage: String?
    @State private var contentHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0

    init(job: DispatchJob,
         onInterested: @escaping () async -> String?,
         onNotNow: @escaping () -> Void,
         onDone: @escaping () -> Void,
         onHeightChange: @escaping (CGFloat) -> Void = { _ in }) {
        self.job = job
        self.onInterested = onInterested
        self.onNotNow = onNotNow
        self.onDone = onDone
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        // Scrolls only when the text is very large and it can't fit on screen.
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                topRow
                titleBlock
                if job.targetRate != nil {
                    earningsBlock
                }
                detailsBlock
                if !job.description.isEmpty {
                    Text(job.description)
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                customerRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 4)
            .background(heightReader { contentHeight = $0; reportHeight() })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
                .background(heightReader { barHeight = $0; reportHeight() })
        }
        .background(HandzColor.surface.ignoresSafeArea())
    }

    private func heightReader(_ update: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { update(geometry.size.height) }
                .onChange(of: geometry.size.height) { update($0) }
        }
    }

    private func reportHeight() {
        guard contentHeight > 0, barHeight > 0 else { return }
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
        onHeightChange(contentHeight + barHeight + bottomInset)
    }

    // MARK: - Top: "New job near you" + distance

    private var topRow: some View {
        HStack {
            HandzChip(text: "New job near you", icon: "bell", kind: .attention)
            Spacer()
            if let miles = job.distanceMiles {
                Text("\(String(format: "%.1f", miles)) mi away")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
    }

    // MARK: - Category + title

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 44, height: 44)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(categoryName)
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)
                Text(job.title)
                    .font(HandzTypography.sectionTitle)
                    .foregroundColor(HandzColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    // MARK: - Money

    private var earningsBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("You'll earn")
                    .font(HandzTypography.captionBold)
                Text(money(workerEarns))
                    .font(HandzTypography.money)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Job pays \(money(jobPay))")
                    .font(HandzTypography.caption.weight(.semibold))
                Text("minus 7.5% Handz fee")
                    .font(HandzTypography.caption)
            }
            .multilineTextAlignment(.trailing)
        }
        .foregroundColor(HandzColor.accentInk)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(HandzColor.accentTint)
        )
        .accessibilityElement(children: .combine)
    }

    /// Pay is one flat amount per worker for the whole job.
    private var jobPay: Double { job.targetRate ?? 0 }

    private var workerEarns: Double {
        (jobPay * 0.925 * 100).rounded() / 100
    }

    // MARK: - When, where, how many

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailRow(icon: "calendar",
                      main: job.scheduledAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()),
                      sub: "About \(String(format: "%g", job.durationHours)) hour\(job.durationHours == 1 ? "" : "s")")
            detailRow(icon: "mappin.and.ellipse",
                      main: locationText,
                      sub: "Exact address is shared once you're hired")
            detailRow(icon: "person.2",
                      main: "\(job.workersNeeded) worker\(job.workersNeeded == 1 ? "" : "s") needed",
                      sub: nil)
        }
    }

    private func detailRow(icon: String, main: String, sub: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(HandzColor.textSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(main)
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textPrimary)
                if let sub = sub {
                    Text(sub)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var locationText: String {
        if let area = job.area, !area.isEmpty {
            return "\(area), \(job.city)"
        }
        return "\(job.city), \(job.state)"
    }

    // MARK: - Who posted it

    private var customerRow: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 40, height: 40)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.customerName)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                HStack(spacing: 4) {
                    if let rating = job.customerRating {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(HandzColor.warning)
                            .accessibilityHidden(true)
                        Text("\(String(format: "%.1f", rating)) · \(job.customerReviewCount) review\(job.customerReviewCount == 1 ? "" : "s")")
                    } else {
                        Text("New on Handz")
                    }
                }
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(HandzColor.border).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        let letters = job.customerName.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: - Buttons (pinned to the bottom)

    private var actionBar: some View {
        VStack(spacing: 10) {
            if let errorMessage = errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            HStack(spacing: 12) {
                if phase != .sent {
                    Button {
                        HandzHaptics.tap()
                        onNotNow()
                    } label: {
                        Text("Not Now")
                    }
                    .buttonStyle(NotNowButtonStyle())
                    .disabled(phase == .sending)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                Button {
                    Task { await sendInterest() }
                } label: {
                    interestedLabel
                }
                .buttonStyle(PrimaryButtonStyle(color: HandzColor.accent))
                .accessibilityHint("Tells the customer you'd like this job")
            }

            Text("The customer picks who to hire. We'll tell you if it's you.")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, HandzSpacing.sm)
        .background(
            HandzColor.surface
                .overlay(alignment: .top) { Rectangle().fill(HandzColor.border).frame(height: 1) }
                .ignoresSafeArea()
        )
        .animation(HandzMotion.safe(HandzMotion.bouncy), value: phase)
        .animation(HandzMotion.safe(HandzMotion.standard), value: errorMessage)
    }

    @ViewBuilder
    private var interestedLabel: some View {
        switch phase {
        case .idle:
            Label("I'm Interested", systemImage: "checkmark")
        case .sending:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(HandzColor.onFill)
                Text("Sending…")
            }
        case .sent:
            Label("Sent", systemImage: "checkmark.circle.fill")
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    @MainActor
    private func sendInterest() async {
        guard phase == .idle else { return }
        HandzHaptics.press()
        withHandzAnimation(HandzMotion.quick) {
            errorMessage = nil
            phase = .sending
        }

        if let error = await onInterested() {
            HandzHaptics.error()
            withHandzAnimation {
                phase = .idle
                errorMessage = error
            }
            return
        }

        HandzHaptics.success()
        withHandzAnimation(HandzMotion.bouncy) { phase = .sent }
        UIAccessibility.post(notification: .announcement,
                             argument: "Sent. The customer will decide who to hire.")
        try? await Task.sleep(nanoseconds: 900_000_000)
        onDone()
    }

    // MARK: - Helpers

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }

    /// "moving_help" -> "Moving help"
    private var categoryName: String {
        let words = job.category.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Apple's built-in icons instead of emoji.
    private var categoryIcon: String {
        let c = job.category.lowercased()
        if c.contains("clean") { return "sparkles" }
        if c.hasPrefix("car_") || c.contains("tire_") { return "car" }
        if c.contains("bartend") || c.contains("catering") { return "fork.knife" }
        if c.contains("moving") || c.contains("hauling") || c.contains("junk") { return "shippingbox" }
        if c.contains("paint") { return "paintbrush" }
        if c.contains("garden") || c.contains("lawn") || c.contains("yard") || c.contains("landscap") { return "leaf" }
        if c.contains("delivery") || c.contains("courier") || c.contains("driv") { return "car" }
        if c.contains("tech") || c.contains("it_") || c.contains("computer") { return "desktopcomputer" }
        if c.contains("pet") || c.contains("dog") { return "pawprint" }
        if c.contains("electric") { return "bolt" }
        if c.contains("plumb") { return "drop" }
        if c.contains("assembl") || c.contains("carpent") || c.contains("handy") { return "hammer" }
        if c.contains("tutor") || c.contains("teach") || c.contains("instruct") { return "book" }
        return "wrench.and.screwdriver"
    }
}

/// Soft red "Not Now" pill, fixed width so "I'm Interested" gets the extra room.
private struct NotNowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandzTypography.button)
            .foregroundColor(HandzColor.danger)
            .frame(width: 120)
            .frame(minHeight: 52)
            .background(Capsule().fill(HandzColor.dangerTint))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}
