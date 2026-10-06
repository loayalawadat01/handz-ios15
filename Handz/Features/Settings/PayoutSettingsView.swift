import SwiftUI

struct PayoutSettingsView: View {
    @State private var connected = false
    @State private var payoutsEnabled = false
    @State private var isLoading = true
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var onboardingURL: IdentifiableURL?

    var body: some View {
        Form {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Section {
                    statusRow
                }

                Section {
                    Text("Handz uses Stripe to send your earnings to your bank account. Setup takes a few minutes and is handled securely by Stripe. Handz never sees your bank details.")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(HandzColor.danger)
                    }
                }

                if !payoutsEnabled {
                    Section {
                        Button {
                            Task { await startOnboarding() }
                        } label: {
                            if isStarting {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text(connected ? "Finish setting up payouts" : "Set up payouts")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isStarting)
                    }
                }
            }
        }
        .navigationTitle("Payouts")
        .task { await loadStatus() }
        .sheet(item: $onboardingURL, onDismiss: {
            Task { await loadStatus() }
        }) { item in
            SafariView(url: item.url)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if payoutsEnabled {
            Label("Payouts are set up", systemImage: "checkmark.circle.fill")
                .foregroundColor(HandzColor.accent)
        } else if connected {
            Label("Setup started but not finished", systemImage: "exclamationmark.circle.fill")
                .foregroundColor(HandzColor.warning)
        } else {
            Label("Payouts not set up yet", systemImage: "banknote")
                .foregroundColor(HandzColor.textSecondary)
        }
    }

    private func loadStatus() async {
        do {
            let status = try await ConnectRepository.shared.status()
            connected = status.connected
            payoutsEnabled = status.payoutsEnabled
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startOnboarding() async {
        isStarting = true
        errorMessage = nil
        do {
            let url = try await ConnectRepository.shared.startOnboarding()
            onboardingURL = IdentifiableURL(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }
}
