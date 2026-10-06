import SwiftUI

/// Every payment you made or got. Each one opens its receipt.
struct PaymentHistoryView: View {
    @StateObject private var viewModel = PaymentHistoryViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HandzSpacing.lg) {
                if viewModel.isLoading && viewModel.asWorker.isEmpty && viewModel.asCustomer.isEmpty {
                    HandzLoadingList(count: 4)
                } else if let errorMessage = viewModel.errorMessage {
                    HandzErrorCard(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.asWorker.isEmpty && viewModel.asCustomer.isEmpty {
                    HandzEmptyState(
                        icon: "doc.text",
                        title: "No payments yet",
                        message: "Money you earn or pay for jobs will show up here, with a receipt for each one."
                    )
                } else {
                    hero
                    if !viewModel.asWorker.isEmpty {
                        section(title: "Money earned", payments: viewModel.asWorker, isWorkerView: true)
                    }
                    if !viewModel.asCustomer.isEmpty {
                        section(title: "Money paid", payments: viewModel.asCustomer, isWorkerView: false)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Payments")
        .task {
            await viewModel.load()
            withAnimation(reduceMotion ? HandzMotion.fade : HandzMotion.standard) { appeared = true }
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Big total at the top

    private var hero: some View {
        let earned = total(viewModel.asWorker, isWorkerView: true)
        let paid = total(viewModel.asCustomer, isWorkerView: false)
        let showsEarned = !viewModel.asWorker.isEmpty
        return VStack(alignment: .leading, spacing: 6) {
            HandzEyebrow(showsEarned ? "Earned on Handz" : "Paid on Handz")
            HandzAmountText(showsEarned ? earned : paid,
                            color: showsEarned ? HandzColor.accentInk : HandzColor.textPrimary)
                .handzNumericTextTransition()
            if showsEarned && !viewModel.asCustomer.isEmpty {
                Text("You also paid \(HandzMoney.text(paid)) as a customer")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            } else {
                Text("Tap any payment to see its receipt")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .padding(.top, HandzSpacing.sm)
    }

    // MARK: - A list of payments

    private func section(title: String, payments: [Payment], isWorkerView: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HandzSectionTitle(title)

            HandzListGroup {
                ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                    NavigationLink {
                        ReceiptView(paymentId: payment.id)
                    } label: {
                        PaymentListRow(payment: payment, isWorkerView: isWorkerView)
                    }
                    .buttonStyle(HandzRowPressStyle())
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 10)
                    .animation(
                        reduceMotion ? HandzMotion.fade
                            : HandzMotion.standard.delay(Double(min(index, 10)) * HandzMotion.staggerStep),
                        value: appeared
                    )
                }
            }
        }
    }

    private func total(_ payments: [Payment], isWorkerView: Bool) -> Double {
        payments
            .filter { $0.status == .succeeded }
            .reduce(0) { $0 + (isWorkerView ? $1.workerKeepsAfterRefunds : $1.customerPaidAfterRefunds) }
    }
}

/// One payment in a list: arrow in a circle, job, date and status, amount.
struct PaymentListRow: View {
    let payment: Payment
    let isWorkerView: Bool

    init(payment: Payment, isWorkerView: Bool) {
        self.payment = payment
        self.isWorkerView = isWorkerView
    }

    var body: some View {
        HandzListRow(
            title: payment.jobTitle ?? "Job",
            subtitle: subtitle,
            trailing: trailingText,
            trailingDetail: payment.receiptNumber == nil ? nil : "Receipt",
            trailingColor: amountColor,
            showsChevron: true
        ) {
            HandzIconBubble(isWorkerView ? "arrow.down.left" : "arrow.up.right",
                            text: isWorkerView ? HandzColor.accentInk : HandzColor.primaryInk,
                            fill: isWorkerView ? HandzColor.accentTint : HandzColor.primaryTint)
        }
    }

    private var amount: Double {
        isWorkerView ? payment.workerKeepsAfterRefunds : payment.customerPaidAfterRefunds
    }

    private var trailingText: String {
        let sign = isWorkerView && payment.status == .succeeded ? "+" : ""
        return sign + HandzMoney.text(amount)
    }

    private var amountColor: Color {
        guard payment.status == .succeeded else { return HandzColor.textSecondary }
        return isWorkerView ? HandzColor.accentInk : HandzColor.textPrimary
    }

    private var subtitle: String {
        let date = (payment.capturedAt ?? payment.createdAt).formatted(date: .abbreviated, time: .omitted)
        var status = payment.status.displayLabel
        if let refunded = payment.refundedAmount, refunded > 0, payment.status == .succeeded {
            status = "Refunded \(HandzMoney.text(refunded))"
        }
        if payment.kind == "LATE_CANCEL_FEE" {
            status = "Late-cancel fee · " + status
        }
        return "\(date) · \(status)"
    }
}

struct PaymentHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack { PaymentHistoryView() }
    }
}
