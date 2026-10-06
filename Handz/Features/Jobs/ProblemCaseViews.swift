//
//  ProblemCaseViews.swift
//  Handz
//
//  "Something's wrong" and the problem case tracker on the job page.
//  When the customer reports a problem during the job, the pay goes on hold.
//  Both people follow the same tracker: Reported -> Their side -> Handz decision.
//  The person the report is about can tell their side; Handz reads both.
//

import SwiftUI

// MARK: - The customer's "Something's wrong" button

struct SomethingWrongButton: View {
    let subtitle: String
    let action: () -> Void

    init(subtitle: String = "Tell us before the worker finishes. The pay goes on hold until Handz decides.",
         action: @escaping () -> Void) {
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(HandzColor.dangerTint))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Something's wrong?")
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                    Text(subtitle)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(HandzColor.textFaint)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .fill(HandzColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .stroke(HandzColor.danger.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Report a problem to Handz.")
    }
}

// MARK: - Every case on this job

struct ProblemCasesSection: View {
    let disputes: [Dispute]
    let currentUserId: String?
    let onChanged: () -> Void

    @State private var tellingSideOf: Dispute?

    init(disputes: [Dispute], currentUserId: String?, onChanged: @escaping () -> Void) {
        self.disputes = disputes
        self.currentUserId = currentUserId
        self.onChanged = onChanged
    }

    var body: some View {
        if !disputes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(disputes) { dispute in
                    ProblemCaseCard(dispute: dispute, currentUserId: currentUserId) {
                        tellingSideOf = dispute
                    }
                }
            }
            .sheet(item: $tellingSideOf) { dispute in
                TellYourSideSheet(dispute: dispute) {
                    onChanged()
                }
            }
        }
    }
}

// MARK: - One case: what was reported, the tracker, and what happens next

struct ProblemCaseCard: View {
    let dispute: Dispute
    let currentUserId: String?
    let onTellSide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownStep = 0

    init(dispute: Dispute, currentUserId: String?, onTellSide: @escaping () -> Void) {
        self.dispute = dispute
        self.currentUserId = currentUserId
        self.onTellSide = onTellSide
    }

    private var iReported: Bool { dispute.raisedBy == currentUserId }
    /// A chargeback the customer started with their bank: Handz answers it in Stripe.
    private var isBankChargeback: Bool { dispute.issueType == "bank_chargeback" }
    private var isAboutMe: Bool { dispute.againstUserId == currentUserId }
    private var answered: Bool { dispute.hasResponse == true || dispute.respondedAt != nil }

    /// 1 = reported, 2 = the other side answered, 3 = Handz decided.
    private var step: Int {
        if !dispute.isOpen { return 3 }
        return answered ? 2 : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            CaseTracker(steps: trackerSteps, reached: shownStep)
            message
            if dispute.canRespond == true && !isBankChargeback {
                Button(action: onTellSide) {
                    Label(answered ? "Edit your side" : "Tell your side", systemImage: "text.bubble")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .onAppear {
            if reduceMotion {
                shownStep = step
            } else {
                withAnimation(HandzMotion.standard.delay(0.2)) { shownStep = step }
            }
        }
        .onChange(of: step) { newStep in
            withHandzAnimation(HandzMotion.bouncy) { shownStep = newStep }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HandzIconBubble("exclamationmark.bubble.fill",
                            text: dispute.isOpen ? HandzColor.warningInk : HandzColor.accentInk,
                            fill: dispute.isOpen ? HandzColor.warningTint : HandzColor.accentTint)
            VStack(alignment: .leading, spacing: 2) {
                Text(dispute.issueLabel)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text(iReported ? "You reported this" : "Reported by \(dispute.raisedByName ?? "the other person")")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
            Spacer(minLength: 8)
            if dispute.payPaused == true {
                HandzChip(text: "Pay on hold", icon: "pause.fill", kind: .attention)
            } else if !dispute.isOpen {
                HandzChip(text: "Decided", icon: "checkmark", kind: .success)
            } else {
                HandzChip(text: "Reviewing", kind: .info)
            }
        }
    }

    private var sideHint: String {
        if answered {
            return "Handz has your side and is reviewing both. You'll get a notification with the decision."
        }
        if dispute.payPaused == true {
            return "Tell your side so Handz can decide fairly. The pay stays on hold until then."
        }
        return "Tell your side so Handz can decide fairly."
    }

    private var trackerSteps: [CaseTracker.Step] {
        let sideLabel = isAboutMe ? "Your side" : "Their side"
        let sideDetail = answered ? (isAboutMe ? "Sent" : "Answered") : "Waiting"
        let decision = dispute.decisionText ?? "Pending"
        return [
            .init(title: "Reported", detail: dispute.createdAt.formatted(date: .abbreviated, time: .shortened)),
            .init(title: sideLabel, detail: sideDetail),
            .init(title: "Handz decision", detail: decision),
        ]
    }

    @ViewBuilder
    private var message: some View {
        if !dispute.isOpen {
            VStack(alignment: .leading, spacing: 6) {
                Text(dispute.decisionText ?? "Handz closed this report.")
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textPrimary)
                if let notes = dispute.resolutionNotes, !notes.isEmpty {
                    Text("Note from Handz: \(notes)")
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if isBankChargeback {
            Text("The customer asked their bank to take this payment back. Handz is answering the bank with the job's records. You'll get a notification with the result.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if isAboutMe {
            VStack(alignment: .leading, spacing: 8) {
                Text("What they said")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)
                Text(dispute.reason)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textPrimary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                            .fill(HandzColor.background)
                    )
                Text(sideHint)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(dispute.payPaused == true
                 ? "Nothing is charged until Handz decides. We asked the other person for their side, and you'll both get a notification with the decision."
                 : "Handz is reviewing this. You'll get a notification with the decision.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - The three-step tracker (like a delivery tracker)

struct CaseTracker: View {
    struct Step {
        let title: String
        let detail: String
    }

    let steps: [Step]
    let reached: Int   // how many steps are done (0...steps.count)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        connector(filled: index > 0 && index < reached, hidden: index == 0)
                        dot(done: index < reached, current: index == reached - 1)
                        connector(filled: index + 1 < reached, hidden: index == steps.count - 1)
                    }
                    Text(steps[index].title)
                        .font(HandzTypography.captionBold)
                        .foregroundColor(index < reached ? HandzColor.textPrimary : HandzColor.textFaint)
                        .multilineTextAlignment(.center)
                    Text(steps[index].detail)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
    }

    private var spokenSummary: String {
        var parts: [String] = []
        for index in steps.indices {
            let status: String = index < reached ? steps[index].detail : "not yet"
            parts.append("\(steps[index].title): \(status)")
        }
        return parts.joined(separator: ". ")
    }

    private func dot(done: Bool, current: Bool) -> some View {
        ZStack {
            Circle()
                .fill(done ? HandzColor.primary : HandzColor.surface)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(done ? HandzColor.primary : HandzColor.border, lineWidth: 2))
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(HandzColor.onFill)
            }
        }
        .scaleEffect(current ? 1.12 : 1)
    }

    private func connector(filled: Bool, hidden: Bool) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(HandzColor.border)
            Capsule().fill(HandzColor.primary).scaleEffect(x: filled ? 1 : 0.001, y: 1, anchor: .leading)
        }
        .frame(height: 3)
        .opacity(hidden ? 0 : 1)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - "Tell your side"

struct TellYourSideSheet: View {
    let dispute: Dispute
    let onSent: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private let limit = 2000

    init(dispute: Dispute, onSent: @escaping () -> Void) {
        self.dispute = dispute
        self.onSent = onSent
        _text = State(initialValue: dispute.response ?? "")
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HandzNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HandzEyebrow("What they said")
                        Text(dispute.reason)
                            .font(HandzTypography.callout)
                            .foregroundColor(HandzColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 0)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your side")
                            .font(HandzTypography.headline)
                            .foregroundColor(HandzColor.textPrimary)
                        Text("Say what happened, calmly and with facts: times, what was agreed, what you did. Only Handz reads this.")
                            .font(HandzTypography.caption)
                            .foregroundColor(HandzColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextEditor(text: $text)
                            .focused($focused)
                            .frame(minHeight: 160)
                            .padding(8)
                            .handzHideScrollBackground()
                            .background(
                                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                                    .fill(HandzColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                                    .stroke(focused ? HandzColor.primary : HandzColor.textFaint, lineWidth: focused ? 2 : 1)
                            )
                            .onChange(of: text) { value in
                                // Counted the same way the server counts.
                                if value.utf16.count > limit {
                                    var cut = value
                                    while cut.utf16.count > limit { cut.removeLast() }
                                    text = cut
                                }
                            }
                        Text("\(text.utf16.count) / \(limit)")
                            .font(HandzTypography.caption)
                            .foregroundColor(HandzColor.textFaint)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(HandzTypography.callout)
                            .foregroundColor(HandzColor.danger)
                    }

                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView().tint(HandzColor.onInk)
                        } else {
                            Text("Send to Handz")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmed.count < 10 || isSending)
                }
                .padding(20)
            }
            .handzScrollDismissesKeyboard()
            .handzScreenBackground()
            .navigationTitle("Tell your side")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Wait for the sheet to finish sliding up, then open the keyboard.
                try? await Task.sleep(nanoseconds: 500_000_000)
                focused = true
            }
        }
    }

    @MainActor
    private func send() async {
        isSending = true
        errorMessage = nil
        do {
            _ = try await DisputesRepository.shared.respond(disputeId: dispute.id, response: trimmed)
            HandzHaptics.success()
            onSent()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HandzHaptics.error()
        }
        isSending = false
    }
}
