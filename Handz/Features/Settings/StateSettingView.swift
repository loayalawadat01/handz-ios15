import SwiftUI

/// Account → Settings → Your state. Workers see jobs in this state.
struct StateSettingView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss
    @State private var savingCode: String?
    @State private var errorMessage: String?

    private var current: String? { authSession.currentUser?.state }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(HandzColor.danger)
                }
            }
            Section {
                ForEach(USState.all) { state in
                    Button {
                        Task { await choose(state.code) }
                    } label: {
                        HStack {
                            Text(state.name).foregroundColor(HandzColor.textPrimary)
                            Spacer()
                            if savingCode == state.code {
                                ProgressView()
                            } else if current == state.code {
                                Image(systemName: "checkmark").foregroundColor(HandzColor.primary)
                            }
                        }
                    }
                    .disabled(savingCode != nil)
                    .accessibilityAddTraits(current == state.code ? .isSelected : [])
                }
            } footer: {
                Text(authSession.currentUser?.role == "worker"
                     ? "You'll see jobs and get pop-ups for this state."
                     : "New jobs you post use the state of their address.")
            }
        }
        .navigationTitle("Your state")
    }

    private func choose(_ code: String) async {
        guard code != current else { return }
        savingCode = code
        errorMessage = nil
        do {
            try await PreferencesRepository.shared.updateState(code)
            await authSession.refreshCurrentUser()
            HandzHaptics.tap()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        savingCode = nil
    }
}

/// On Home: asks older accounts to pick their state, or says when Handz
/// isn't open in their state yet.
struct StateNoticeCard: View {
    @EnvironmentObject private var authSession: AuthSession

    var body: some View {
        if let user = authSession.currentUser {
            if user.state == nil {
                NavigationLink {
                    StateSettingView()
                } label: {
                    notice(icon: "mappin.circle.fill",
                           title: "Which state do you live in?",
                           text: user.role == "worker" ? "Add it so you see jobs near you." : "Add it so we can match you with workers near you.",
                           showsChevron: true)
                }
                .buttonStyle(HandzPressStyle())
            } else if user.stateSupported == false {
                notice(icon: "clock.badge.checkmark",
                       title: "Handz isn't in \(USState.name(for: user.state) ?? "your state") yet",
                       text: "We'll let you know as soon as we launch there.",
                       showsChevron: false)
            }
        }
    }

    private func notice(icon: String, title: String, text: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(HandzColor.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text(text)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }
}
