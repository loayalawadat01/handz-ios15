import SwiftUI

/// Light, dark, or follow the phone. Saved on this phone.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Automatic"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Account → Settings (gear icon): your details, password, look, notifications,
/// privacy, help, and logging out.
struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @AppStorage(AppAppearance.storageKey) private var appearance: String = AppAppearance.system.rawValue
    @State private var showingLogOutConfirm = false
    @State private var showingTerms = false

    private var user: AuthUser? { authSession.currentUser }
    private var isWorker: Bool { user?.role == "worker" }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("Your details") {
                link("Name", value: user?.name, icon: "person") { EditNameView() }
                link("Phone number", value: formattedPhone, icon: "phone") { EditPhoneView() }
                link("State", value: USState.name(for: user?.state), icon: "map") { StateSettingView() }
                if isWorker {
                    link("My location", value: nil, icon: "location") { HomeLocationView() }
                }
            }

            Section("Security") {
                link("Change password", value: nil, icon: "key") { ChangePasswordView() }
            }

            Section {
                Picker(selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                } label: {
                    Label("Dark mode", systemImage: "moon")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Automatic follows your phone's setting.")
            }

            if isWorker {
                Section("Notifications") {
                    link("Job notifications", value: nil, icon: "bell.badge") { NotificationPreferencesView() }
                }
            }

            Section("Privacy & safety") {
                link("Blocked users", value: nil, icon: "hand.raised") { BlockedUsersView() }
            }

            Section("Help") {
                link("How Handz works", value: nil, icon: "questionmark.circle") { HowHandzWorksView() }
                Button {
                    showingTerms = true
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                        .foregroundColor(HandzColor.textPrimary)
                }
                HStack {
                    Label("App version", systemImage: "info.circle")
                    Spacer()
                    Text(appVersion).foregroundColor(HandzColor.textSecondary)
                }
                .foregroundColor(HandzColor.textPrimary)
                .accessibilityElement(children: .combine)
            }

            Section {
                Button(role: .destructive) {
                    showingLogOutConfirm = true
                } label: {
                    Label("Log out", systemImage: "arrow.right.square")
                }
                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Label("Delete account", systemImage: "trash")
                        .foregroundColor(HandzColor.danger)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Log out of Handz?", isPresented: $showingLogOutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                authSession.logOut()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingTerms) {
            TermsView()
        }
    }

    private var formattedPhone: String? {
        guard let digits = user?.phone, digits.count == 10 else { return user?.phone }
        let a = digits.prefix(3), b = digits.dropFirst(3).prefix(3), c = digits.suffix(4)
        return "(\(a)) \(b)-\(c)"
    }

    private func link<Destination: View>(_ title: String, value: String?, icon: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                    .foregroundColor(HandzColor.textPrimary)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .foregroundColor(HandzColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
