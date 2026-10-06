import SwiftUI

struct IdentityStatus: Decodable {
    let status: String          // unverified, pending, verified, failed
    let url: String?            // the Stripe page to open, when starting
}

/// Talks to /api/identity.
final class IdentityRepository {
    static let shared = IdentityRepository()
    private init() {}

    func status() async throws -> IdentityStatus {
        try await APIClient.shared.request("/identity/status")
    }

    func start() async throws -> IdentityStatus {
        try await APIClient.shared.request("/identity/start", method: .post)
    }
}

/// Workers confirm who they are with Stripe: a photo of their ID and a selfie.
/// Customers then see an "ID verified" badge on their profile and offers.
struct IdentityVerificationView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var status = "unverified"
    @State private var isLoading = true
    @State private var isStarting = false
    @State private var errorMessage: String?
    @State private var verificationURL: IdentifiableURL?

    var body: some View {
        Form {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Section {
                    statusRow
                }

                Section {
                    Text("Customers let you into their homes, so they want to know who you are. Stripe checks a photo of your driver's license, ID card or passport against a selfie. It takes about 2 minutes. Handz never stores your ID photos.")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(HandzColor.danger)
                    }
                }

                if status != "verified" && status != "pending" {
                    Section {
                        Button {
                            Task { await start() }
                        } label: {
                            if isStarting {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text(status == "failed" ? "Try again" : "Verify my ID")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(isStarting)
                    }
                }
            }
        }
        .navigationTitle("ID verification")
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $verificationURL, onDismiss: {
            Task { await load() }
        }) { item in
            SafariView(url: item.url)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case "verified":
            Label("Your ID is verified", systemImage: "checkmark.seal.fill")
                .foregroundColor(HandzColor.accent)
        case "pending":
            Label("Stripe is checking your ID. This usually takes a few minutes.", systemImage: "hourglass")
                .foregroundColor(HandzColor.warning)
        case "failed":
            Label("We couldn't verify your ID. Please try again with a clear photo.", systemImage: "exclamationmark.circle.fill")
                .foregroundColor(HandzColor.danger)
        default:
            Label("Not verified yet", systemImage: "person.text.rectangle")
                .foregroundColor(HandzColor.textSecondary)
        }
    }

    private func load() async {
        do {
            let result = try await IdentityRepository.shared.status()
            let becameVerified = result.status == "verified" && status != "verified" && !isLoading
            status = result.status
            if becameVerified {
                HandzHaptics.success()
                await authSession.refreshCurrentUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func start() async {
        isStarting = true
        errorMessage = nil
        do {
            let result = try await IdentityRepository.shared.start()
            status = result.status
            if let link = result.url, let url = URL(string: link) {
                verificationURL = IdentifiableURL(url: url)
            } else if result.status == "verified" {
                HandzHaptics.success()
                await authSession.refreshCurrentUser()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }
}
