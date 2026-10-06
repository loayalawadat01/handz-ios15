import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = ForgotPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch viewModel.step {
                case .enterEmail:
                    Section {
                        Text("Enter the email you signed up with. We'll send you a 6-digit code.")
                            .font(HandzTypography.body)
                        TextField("Email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    errorSection
                    Section {
                        Button {
                            Task { await viewModel.sendCode() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Send Code").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!viewModel.canSendCode)
                    }

                case .enterCode:
                    Section {
                        Text("If \(viewModel.email) has an account, we sent a code to it. It expires in 15 minutes.")
                            .font(HandzTypography.body)
                        TextField("6-digit code", text: $viewModel.code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        SecureField("New password (8+ characters)", text: $viewModel.newPassword)
                            .textContentType(.newPassword)
                    }
                    errorSection
                    Section {
                        Button {
                            Task { await viewModel.resetPassword() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Reset Password").frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(!viewModel.canReset)

                        Button("Send a new code") {
                            Task { await viewModel.sendCode() }
                        }
                        .disabled(viewModel.isLoading)
                    }

                case .done:
                    Section {
                        Label("Your password was reset.", systemImage: "checkmark.circle.fill")
                            .foregroundColor(HandzColor.accent)
                        Text("You can now log in with your new password.")
                            .font(HandzTypography.body)
                    }
                    Section {
                        Button("Back to Log In") { dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                Text(errorMessage).foregroundColor(HandzColor.danger)
            }
        }
    }
}
