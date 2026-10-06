import SwiftUI

/// Account deletion with password confirmation (required by Apple for
/// App Store approval). The backend refuses if the user has jobs in
/// progress or unpaid payments.
struct DeleteAccountView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var password: String = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showingFinalConfirm = false

    var body: some View {
        Form {
            Section {
                Text("Deleting your account permanently removes your name, email, photo, bio, and location. Your open jobs will be cancelled and pending applications withdrawn. Past job and payment records stay, shown as \"Deleted user.\"")
                    .font(HandzTypography.body)
                Text("This cannot be undone.")
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.danger)
            }

            Section("Confirm your password") {
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(HandzColor.danger)
                }
            }

            Section {
                Button(role: .destructive) {
                    showingFinalConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Delete My Account").frame(maxWidth: .infinity)
                    }
                }
                .disabled(password.isEmpty || isDeleting)
            }
        }
        .navigationTitle("Delete Account")
        .alert("Delete your account?", isPresented: $showingFinalConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await authSession.deleteAccount(password: password)
            // logOut() inside deleteAccount sends the app back to Welcome.
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }
}
