import SwiftUI
import UIKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showingForgotPassword = false
    @State private var showPassword = false
    @State private var shakeCount = 0
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable { case email, password }
    @FocusState private var focused: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    HandzFormField("Email") {
                        TextField("name@example.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }
                            .handzField(isFocused: focused == .email, hasError: viewModel.errorMessage != nil)
                    }

                    HandzFormField("Password") {
                        passwordField
                    }

                    HStack {
                        if let errorMessage = viewModel.errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                .font(HandzTypography.caption.weight(.semibold))
                                .foregroundColor(HandzColor.dangerInk)
                                .transition(.opacity)
                        }
                        Spacer(minLength: 8)
                        Button("Forgot password?") {
                            showingForgotPassword = true
                        }
                        .font(HandzTypography.callout.weight(.semibold))
                        .foregroundColor(HandzColor.primary)
                        .frame(minHeight: 44)
                    }
                }
                .handzShake(shakeCount)

                Button {
                    logInTapped()
                } label: {
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(HandzColor.onFill)
                            Text("Logging in…")
                        }
                    } else {
                        Text("Log In")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canSubmit || viewModel.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.top, HandzSpacing.xl)
            .padding(.bottom, HandzSpacing.lg)
            .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.errorMessage)
        }
        .handzScrollDismissesKeyboard()
        .handzScreenBackground()
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(HandzColor.onFill)
                .frame(width: 64, height: 64)
                .background(Circle().fill(HandzColor.primary))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(HandzTypography.largeTitle)
                    .foregroundColor(HandzColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Log in to see your jobs and messages.")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
    }

    private var passwordField: some View {
        HStack(spacing: 8) {
            Group {
                if showPassword {
                    TextField("Your password", text: $viewModel.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Your password", text: $viewModel.password)
                }
            }
            .textContentType(.password)
            .focused($focused, equals: .password)
            .submitLabel(.go)
            .onSubmit { logInTapped() }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(HandzColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
        }
        .handzField(isFocused: focused == .password, hasError: viewModel.errorMessage != nil)
    }

    private func logInTapped() {
        guard viewModel.canSubmit, !viewModel.isLoading else { return }
        focused = nil
        HandzHaptics.press()
        Task {
            await viewModel.logIn()
            await MainActor.run {
                if viewModel.errorMessage == nil {
                    dismiss()
                } else {
                    HandzHaptics.error()
                    if !UIAccessibility.isReduceMotionEnabled {
                        withAnimation(.linear(duration: 0.4)) { shakeCount += 1 }
                    }
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
