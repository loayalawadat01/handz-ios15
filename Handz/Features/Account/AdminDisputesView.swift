import SwiftUI

// MARK: - List of reported problems (Handz admins only)

@MainActor
final class AdminDisputesViewModel: ObservableObject {
    @Published var disputes: [AdminDispute] = []
    @Published var showingOpen = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            disputes = try await AdminRepository.shared.disputes(open: showingOpen)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct AdminDisputesView: View {
    @StateObject private var viewModel = AdminDisputesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Show", selection: $viewModel.showingOpen) {
                    Text("To decide").tag(true)
                    Text("Decided").tag(false)
                }
                .pickerStyle(.segmented)

                if viewModel.isLoading && viewModel.disputes.isEmpty {
                    HandzLoadingList(count: 3)
                } else if let error = viewModel.errorMessage {
                    HandzErrorCard(message: error) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.disputes.isEmpty {
                    Text(viewModel.showingOpen ? "Nothing to decide right now." : "No decided problems yet.")
                        .font(HandzTypography.body)
                        .foregroundColor(HandzColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, HandzSpacing.xl)
                } else {
                    ForEach(viewModel.disputes) { dispute in
                        NavigationLink {
                            AdminDisputeDetailView(dispute: dispute) {
                                Task { await viewModel.load() }
                            }
                        } label: {
                            disputeRow(dispute)
                        }
                        .buttonStyle(HandzPressStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Reported problems")
        .task { await viewModel.load() }
        .handzRefreshable { await viewModel.load() }
        .onChange(of: viewModel.showingOpen) { _ in
            Task { await viewModel.load() }
        }
    }

    private func disputeRow(_ dispute: AdminDispute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dispute.jobTitle)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let label = dispute.resolutionLabel {
                    HandzChip(text: label, kind: .neutral)
                } else {
                    HandzChip(text: dispute.issueLabel, kind: dispute.isBankChargeback ? .danger : .attention)
                }
            }
            Text(dispute.reason)
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("Reported by \(dispute.raisedByName ?? dispute.raisedByRole) · \(dispute.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Deciding one problem

struct AdminDisputeDetailView: View {
    @State private var dispute: AdminDispute
    var onDecided: () -> Void

    @State private var decision: AdminDecision?
    @State private var refundText = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingConfirm = false

    init(dispute: AdminDispute, onDecided: @escaping () -> Void) {
        _dispute = State(initialValue: dispute)
        self.onDecided = onDecided
    }

    var body: some View {
        Form {
            Section("Problem") {
                labeled("Job", dispute.jobTitle)
                labeled("Type", dispute.issueLabel)
                labeled("Reported by", "\(dispute.raisedByName ?? "Someone") (\(dispute.raisedByRole))")
                labeled("Customer", dispute.customerName ?? "—")
                labeled("Worker", dispute.workerName ?? "—")
                Text(dispute.reason)
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let payment = dispute.payment {
                Section("Money") {
                    labeled("Customer pays", money(payment.totalChargedToCustomer))
                    labeled("Worker gets", money(payment.workerPayoutAmount))
                    labeled("Status", payment.status.displayLabel)
                    if payment.refundedAmount > 0 {
                        labeled("Already refunded", money(payment.refundedAmount))
                    }
                }
            }

            if dispute.isOpen {
                decisionSections
            } else {
                Section("Decision") {
                    labeled("Outcome", dispute.resolutionLabel ?? dispute.status.displayLabel)
                    if let refund = dispute.refundAmount {
                        labeled("Refunded", money(refund))
                    }
                    if let notes = dispute.resolutionNotes {
                        Text(notes).foregroundColor(HandzColor.textSecondary)
                    }
                }
            }
        }
        .navigationTitle("Decide")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(confirmTitle, isPresented: $showingConfirm, titleVisibility: .visible) {
            Button("Confirm", role: decision == .dismiss ? nil : .destructive) {
                Task { await save() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Both people get a notification. This can't be undone.")
        }
    }

    @ViewBuilder
    private var decisionSections: some View {
        if dispute.isBankChargeback {
            Section {
                Text("The customer's bank is handling this. Answer it in your Stripe dashboard (Payments → Disputes) before the deadline, then mark it done here.")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                decisionButton("Mark as done", .dismiss)
            }
        } else {
            Section {
                if dispute.payment != nil {
                    decisionButton("Full refund to the customer", .fullRefund)
                    decisionButton("Partial refund", .partialRefund)
                    if decision == .partialRefund {
                        TextField("Refund amount, e.g. 40", text: $refundText)
                            .keyboardType(.decimalPad)
                        if let available = dispute.payment?.refundableAmount {
                            Text("Up to \(money(available)). The worker and Handz give back their share in proportion.")
                                .font(HandzTypography.caption)
                                .foregroundColor(HandzColor.textSecondary)
                        }
                    }
                    decisionButton("Pay the worker, no refund", .payWorker)
                }
                decisionButton("Close without changes", .dismiss)
            } header: {
                Text("What should happen?")
            }

            Section("Note to both people (optional)") {
                HandzGrowingTextField("Why you decided this", text: $notes, lines: 2...5)
            }
        }

        if let errorMessage {
            Section {
                Text(errorMessage).foregroundColor(HandzColor.danger)
            }
        }

        Section {
            Button {
                errorMessage = nil
                if decision == .partialRefund && refundAmount == nil {
                    errorMessage = "Enter how much to refund."
                    return
                }
                showingConfirm = true
            } label: {
                if isSaving {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Save decision").frame(maxWidth: .infinity)
                }
            }
            .disabled(decision == nil || isSaving)
        }
    }

    private func decisionButton(_ title: String, _ value: AdminDecision) -> some View {
        Button {
            decision = value
        } label: {
            HStack {
                Text(title).foregroundColor(HandzColor.textPrimary)
                Spacer()
                if decision == value {
                    Image(systemName: "checkmark").foregroundColor(HandzColor.primary)
                }
            }
        }
        .accessibilityAddTraits(decision == value ? .isSelected : [])
    }

    private var refundAmount: Double? {
        Double(refundText.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "."))
    }

    private var confirmTitle: String {
        switch decision {
        case .fullRefund: return "Refund \(money(dispute.payment?.refundableAmount ?? 0)) to the customer?"
        case .partialRefund: return "Refund \(money(refundAmount ?? 0)) to the customer?"
        case .payWorker: return "Pay the worker and close this?"
        case .dismiss, .none: return "Close this problem?"
        }
    }

    private func save() async {
        guard let decision else { return }
        isSaving = true
        do {
            dispute = try await AdminRepository.shared.resolve(
                disputeId: dispute.id,
                decision: decision,
                amount: decision == .partialRefund ? refundAmount : nil,
                notes: notes
            )
            HandzHaptics.success()
            onDecided()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundColor(HandzColor.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(HandzTypography.callout)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}
