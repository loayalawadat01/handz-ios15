import SwiftUI
import UIKit
import StripePaymentSheet

@MainActor
final class PaymentMethodViewModel: ObservableObject {
    @Published var cards: [SavedCard] = []
    @Published var isLoading = true
    @Published var isPreparing = false
    @Published var busyCardId: String?
    @Published var errorMessage: String?

    private var paymentSheet: PaymentSheet?
    private var setupIntentId: String?
    private let repository = PaymentsRepository.shared

    func loadCards() async {
        do {
            cards = try await repository.cards()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startAddingCard() async {
        isPreparing = true
        errorMessage = nil
        do {
            let setup = try await repository.startAddingCard()
            STPAPIClient.shared.publishableKey = setup.publishableKey
            setupIntentId = setup.setupIntentId

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Handz"
            configuration.customer = .init(id: setup.customerId, ephemeralKeySecret: setup.ephemeralKey)
            configuration.applePay = HandzApplePay.configuration

            let sheet = PaymentSheet(
                setupIntentClientSecret: setup.setupIntentClientSecret,
                configuration: configuration
            )
            paymentSheet = sheet
            let opened = await StripeSheet.present(sheet) { [weak self] result in
                Task { @MainActor in
                    self?.handleResult(result)
                }
            }
            if !opened {
                errorMessage = "Couldn't open the card form. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPreparing = false
    }

    func handleResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            guard let setupIntentId else { return }
            Task {
                do {
                    cards = try await repository.finishAddingCard(setupIntentId: setupIntentId)
                    HandzHaptics.success()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    func makeDefault(_ card: SavedCard) async {
        busyCardId = card.id
        errorMessage = nil
        do {
            cards = try await repository.makeDefault(cardId: card.id)
            HandzHaptics.tap()
        } catch {
            errorMessage = error.localizedDescription
        }
        busyCardId = nil
    }

    func remove(_ card: SavedCard) async {
        busyCardId = card.id
        errorMessage = nil
        do {
            cards = try await repository.remove(cardId: card.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        busyCardId = nil
    }
}

/// Apple Pay in the card form. Turned on once you add an Apple Pay merchant
/// ID in your Apple Developer account and Xcode (Signing & Capabilities →
/// Apple Pay), then put it here, e.g. "merchant.com.handz.app".
enum HandzApplePay {
    static let merchantId: String? = nil

    static var configuration: PaymentSheet.ApplePayConfiguration? {
        guard let merchantId else { return nil }
        return .init(merchantId: merchantId, merchantCountryCode: "US")
    }
}

/// Opens Stripe's form on top of whatever screen is showing.
/// Stripe's SwiftUI `.paymentSheet(isPresented:)` only opens when the flag
/// turns on after the form already exists. We make the form and want it open
/// in the same moment, so that modifier never opened it. Opening it directly
/// avoids that.
@MainActor
enum StripeSheet {
    /// Returns false when there's no screen to open it from.
    static func present(_ sheet: PaymentSheet, completion: @escaping (PaymentSheetResult) -> Void) async -> Bool {
        // If a popup is still opening or closing, give it a moment to finish
        // first, or the form would be dropped.
        var top = topViewController()
        var waits = 0
        while let current = top, current.isBeingPresented || current.isBeingDismissed, waits < 10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waits += 1
            top = topViewController()
        }
        guard let top = top else { return false }
        sheet.present(from: top, completion: completion)
        return true
    }

    /// The screen on top: the window's root, then whatever it has open on top of it.
    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        var top = (windows.first(where: { $0.isKeyWindow }) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

struct PaymentMethodView: View {
    @StateObject private var viewModel = PaymentMethodViewModel()
    @State private var cardToRemove: SavedCard?

    var body: some View {
        Form {
            Section {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.cards.isEmpty {
                    Text("No card added yet.")
                        .foregroundColor(HandzColor.textSecondary)
                } else {
                    ForEach(viewModel.cards) { card in
                        cardRow(card)
                    }
                }
            } header: {
                Text("Your cards")
            } footer: {
                if viewModel.cards.count > 1 {
                    Text("Tap a card to use it for your jobs.")
                }
            }

            Section {
                Text("When you hire a worker, we hold their pay on your default card 12 hours before the job starts. You're only charged when the work is done, and the hold is released if the job is cancelled. Your card details are stored securely by Stripe, never by Handz.")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(HandzColor.danger)
                }
            }

            Section {
                Button {
                    Task { await viewModel.startAddingCard() }
                } label: {
                    if viewModel.isPreparing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label(viewModel.cards.isEmpty ? "Add a card" : "Add another card", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isPreparing)
            }
        }
        .navigationTitle("Payment Method")
        .task { await viewModel.loadCards() }
        .confirmationDialog(
            "Remove this card?",
            isPresented: Binding(get: { cardToRemove != nil }, set: { if !$0 { cardToRemove = nil } }),
            titleVisibility: .visible,
            presenting: cardToRemove
        ) { card in
            Button("Remove \(card.brand.capitalized) •••• \(card.last4)", role: .destructive) {
                Task { await viewModel.remove(card) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func cardRow(_ card: SavedCard) -> some View {
        Button {
            guard !card.isDefault else { return }
            Task { await viewModel.makeDefault(card) }
        } label: {
            HStack(spacing: HandzSpacing.md) {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(HandzColor.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(card.brand.capitalized) •••• \(card.last4)")
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                    Text("Expires \(card.expMonth)/\(card.expYear)")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }
                Spacer()
                if viewModel.busyCardId == card.id {
                    ProgressView()
                } else if card.isDefault {
                    HandzChip(text: "Default", icon: "checkmark", kind: .success)
                }
            }
        }
        .disabled(viewModel.busyCardId != nil)
        .swipeActions {
            Button(role: .destructive) {
                cardToRemove = card
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .contextMenu {
            if !card.isDefault {
                Button {
                    Task { await viewModel.makeDefault(card) }
                } label: {
                    Label("Use for my jobs", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive) {
                cardToRemove = card
            } label: {
                Label("Remove card", systemImage: "trash")
            }
        }
        .accessibilityHint(card.isDefault ? "Default card" : "Double tap to use this card for your jobs")
    }
}
