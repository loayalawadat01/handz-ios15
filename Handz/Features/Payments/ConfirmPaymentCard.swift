import SwiftUI
import StripePaymentSheet

/// Opens Stripe's payment form so the customer can confirm a hold that
/// didn't go through on its own: their bank wanted them to approve it, or
/// the card was declined and they want to use another one.
@MainActor
final class ConfirmPaymentViewModel: ObservableObject {
    @Published var isPreparing = false
    @Published var errorMessage: String?

    private var paymentSheet: PaymentSheet?
    private var paymentId: String?
    private var paymentIntentId: String?
    private let repository = PaymentsRepository.shared

    /// Prepares Stripe's form and opens it. `onConfirmed` runs once the payment is held.
    func start(paymentId: String, onConfirmed: @escaping () -> Void) async {
        guard !isPreparing else { return }
        isPreparing = true
        errorMessage = nil
        do {
            let session = try await repository.startConfirming(paymentId: paymentId)
            STPAPIClient.shared.publishableKey = session.publishableKey
            self.paymentId = paymentId
            paymentIntentId = session.paymentIntentId

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Handz"
            configuration.customer = .init(id: session.customerId, ephemeralKeySecret: session.ephemeralKey)
            configuration.applePay = HandzApplePay.configuration
            configuration.primaryButtonLabel = "Hold \(session.amount.formatted(.currency(code: "USD")))"

            let sheet = PaymentSheet(
                paymentIntentClientSecret: session.paymentIntentClientSecret,
                configuration: configuration
            )
            paymentSheet = sheet
            let opened = await StripeSheet.present(sheet) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }
                    if await self.finish(result) { onConfirmed() }
                }
            }
            if !opened {
                errorMessage = "Couldn't open the payment form. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPreparing = false
    }

    /// Returns true when the payment is now held.
    func finish(_ result: PaymentSheetResult) async -> Bool {
        switch result {
        case .completed:
            guard let paymentId, let paymentIntentId else { return false }
            do {
                try await repository.finishConfirming(paymentId: paymentId, paymentIntentId: paymentIntentId)
                HandzHaptics.success()
                return true
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        case .canceled:
            return false
        case .failed(let error):
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Shown on a job when a payment needs attention.
/// The customer gets a "Confirm payment" button; the worker is told to wait.
struct ConfirmPaymentCard: View {
    let payment: Payment
    let isOwner: Bool
    /// Set to this payment's id to open the payment form right away (after hiring).
    @Binding var autoStartPaymentId: String?
    var onConfirmed: () -> Void

    @StateObject private var viewModel = ConfirmPaymentViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: HandzSpacing.sm) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOwner ? "creditcard.trianglebadge.exclamationmark" : "hourglass")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(HandzColor.warningInk)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isOwner ? "Confirm your payment" : "Waiting on the customer's payment")
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                    Text(message)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.danger)
            }

            if isOwner {
                Button {
                    Task { await viewModel.start(paymentId: payment.id, onConfirmed: onConfirmed) }
                } label: {
                    if viewModel.isPreparing {
                        ProgressView().tint(HandzColor.onFill)
                    } else {
                        Text("Confirm payment")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isPreparing)
            }
        }
        .padding(HandzSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(HandzColor.warningTint)
        )
        .task(id: autoStartPaymentId) {
            guard isOwner, autoStartPaymentId == payment.id else { return }
            autoStartPaymentId = nil
            // Clearing the id above ends this task (and would cancel the
            // network call), so the form is opened in a task of its own.
            Task { await viewModel.start(paymentId: payment.id, onConfirmed: onConfirmed) }
        }
    }

    private var message: String {
        let amount = payment.totalChargedToCustomer.formatted(.currency(code: "USD"))
        if !isOwner {
            return "Don't head over yet. We'll let you know as soon as the payment is confirmed."
        }
        if payment.holdProblem == "needs_confirmation" {
            return "Your bank needs you to approve the \(amount) hold for this job. The worker can't start until it's confirmed."
        }
        return "Your card was declined for the \(amount) hold. Use another card so the worker can start."
    }
}
