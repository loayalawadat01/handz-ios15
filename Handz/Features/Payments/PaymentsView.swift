import SwiftUI

struct PaymentsView: View {
    @StateObject private var viewModel: PaymentsViewModel
    private let isOwner: Bool

    // paymentDeadline is no longer used (payment is automatic now); kept
    // so existing screens that open this view don't need changing.
    init(jobId: String, paymentDeadline: Date?, isOwner: Bool) {
        _viewModel = StateObject(wrappedValue: PaymentsViewModel(jobId: jobId))
        self.isOwner = isOwner
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && viewModel.payments.isEmpty {
                    HandzLoadingList(count: 1)
                } else if let errorMessage = viewModel.errorMessage, viewModel.payments.isEmpty {
                    HandzErrorCard(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.payments.isEmpty {
                    HandzEmptyState(
                        icon: "creditcard",
                        title: "No payments yet",
                        message: isOwner
                            ? "When you hire someone, their pay is held on your card and shows up here."
                            : "When you're hired, the customer's payment hold for your pay shows up here."
                    )
                } else {
                    ForEach(viewModel.payments) { payment in
                        if isOwner {
                            customerCard(payment)
                        } else {
                            workerCard(payment)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
            .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.payments.map(\.status))
        }
        .handzScreenBackground()
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Customer

    private func customerCard(_ payment: Payment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(payment.kind == "LATE_CANCEL_FEE" ? "Late-cancellation fee" : "Worker pay",
                       icon: "creditcard", status: payment.status)

            HandzAmountText(payment.customerPaidAfterRefunds, size: 40)

            VStack(spacing: 8) {
                row("Worker's pay", payment.workerAmount)
                row("Service fee (\(String(format: "%g", payment.platformFeePercent))%)", payment.platformFeeAmount)
                if payment.stripeFeeAmount > 0 {
                    row("Card processing", payment.stripeFeeAmount)
                }
                Rectangle().fill(HandzColor.border).frame(height: 1)
                row("Total", payment.totalChargedToCustomer, bold: true)
                if let refunded = payment.refundedAmount, refunded > 0 {
                    row("Refunded to you", -refunded)
                    row("You paid", payment.customerPaidAfterRefunds, bold: true)
                }
            }

            noteBox(customerNote(payment), kind: noteKind(payment))
            receiptButton(payment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Worker

    private func workerCard(_ payment: Payment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(payment.kind == "LATE_CANCEL_FEE" ? "Late-cancellation payment" : "Your pay",
                       icon: "banknote", status: payment.status)

            HandzAmountText(payment.workerKeepsAfterRefunds, size: 40, color: HandzColor.accentInk)

            noteBox(workerNote(payment), kind: noteKind(payment))
            receiptButton(payment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Pieces

    /// Charged payments (and released holds) have a receipt.
    @ViewBuilder
    private func receiptButton(_ payment: Payment) -> some View {
        if payment.status == .succeeded || payment.status == .canceled {
            NavigationLink {
                ReceiptView(paymentId: payment.id)
            } label: {
                Label("View receipt", systemImage: "doc.text")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func cardHeader(_ title: String, icon: String, status: PaymentStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 40, height: 40)
                .background(Circle().fill(HandzColor.primaryTint))
                .accessibilityHidden(true)
            Text(title)
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.textPrimary)
            Spacer(minLength: 8)
            HandzChip(text: status.displayLabel, kind: statusKind(status))
        }
    }

    private func noteBox(_ text: String, kind: HandzChip.Kind) -> some View {
        let colors = noteColors(kind)
        return Text(text)
            .font(HandzTypography.callout)
            .foregroundColor(colors.text)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(colors.fill)
            )
    }

    private func row(_ label: String, _ amount: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(money(amount))
                .monospacedDigit()
        }
        .font(bold ? HandzTypography.headline : HandzTypography.callout)
        .foregroundColor(bold ? HandzColor.textPrimary : HandzColor.textSecondary)
    }

    private func statusKind(_ status: PaymentStatus) -> HandzChip.Kind {
        switch status {
        case .authorized: return .info
        case .succeeded: return .success
        case .canceled: return .neutral
        case .failed: return .danger
        case .pending, .simulated: return .neutral
        }
    }

    private func noteKind(_ payment: Payment) -> HandzChip.Kind {
        payment.needsCustomerAction ? .attention : statusKind(payment.status)
    }

    private func noteColors(_ kind: HandzChip.Kind) -> (text: Color, fill: Color) {
        switch kind {
        case .info:      return (HandzColor.primaryInk, HandzColor.primaryTint)
        case .success:   return (HandzColor.accentInk, HandzColor.accentTint)
        case .attention: return (HandzColor.warningInk, HandzColor.warningTint)
        case .danger:    return (HandzColor.dangerInk, HandzColor.dangerTint)
        case .neutral:   return (HandzColor.textSecondary, HandzColor.background)
        }
    }

    private func customerNote(_ payment: Payment) -> String {
        switch payment.status {
        case .pending where payment.needsCustomerAction:
            return "This payment needs you. Go back to the job and tap Confirm payment."
        case .pending:
            if let due = payment.holdDueAt {
                return "We'll hold this on your card \(due.formatted(date: .abbreviated, time: .shortened)), 12 hours before the job. You're only charged when the work is done."
            }
            return "We'll hold this on your card 12 hours before the job."
        case .authorized: return "This amount is held on your card. You'll only be charged when the work is done."
        case .succeeded:
            if let refunded = payment.refundedAmount, refunded > 0 {
                return "Charged to your card. \(money(refunded)) was refunded to you."
            }
            return "Charged to your card."
        case .canceled: return "The hold was released. You weren't charged."
        case .failed: return "We couldn't charge your card. Please update your payment method."
        case .simulated: return "Processing."
        }
    }

    private func workerNote(_ payment: Payment) -> String {
        switch payment.status {
        case .pending where payment.needsCustomerAction:
            return "The customer's payment isn't confirmed yet. Don't head over until it is. We'll let you know."
        case .pending:
            return "The customer's card is checked. The money is held 12 hours before the job and paid to you when you finish."
        case .authorized: return "The customer's card has a hold for this amount. It's paid to you when you finish the job."
        case .succeeded: return "Sent to your payout account."
        case .canceled: return "This job was cancelled, so no payment was made."
        case .failed: return "The customer's card couldn't be charged. We're following up with them."
        case .simulated: return "Processing."
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}
