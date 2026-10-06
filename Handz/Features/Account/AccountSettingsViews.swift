import SwiftUI
import UIKit

// MARK: Edit name

struct EditNameView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var name: String = ""
    @State private var originalName: String = ""
    @State private var touched = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var shakes = 0

    init() {}

    private var trimmed: String { name.handzTrimmed }

    private var nameError: String? {
        touched && trimmed.isEmpty ? "Please enter your name." : nil
    }

    private var canSave: Bool {
        !trimmed.isEmpty && trimmed != originalName && !isSaving
    }

    private var initials: String {
        let letters = trimmed.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                previewCard

                HandzFormField("Full name",
                               hint: "Use the name people will know you by.",
                               error: nameError) {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { saveTapped() }
                        .handzField(isFocused: focused, hasError: nameError != nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SettingsActionBar(
                title: "Save name",
                busyTitle: "Saving…",
                isBusy: isSaving,
                isEnabled: canSave,
                error: errorMessage,
                shakes: shakes,
                action: saveTapped
            )
        }
        .handzScreenBackground()
        .navigationTitle("Edit Name")
        .navigationBarTitleDisplayMode(.inline)
        .hidesHandzTabBar()
        .onAppear {
            let current = authSession.currentUser?.name ?? ""
            name = current
            originalName = current.handzTrimmed
        }
        .onChange(of: focused) { isFocused in
            if !isFocused { touched = true }
        }
    }

    /// Shows how the name will look to other people, updating as you type.
    private var previewCard: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(HandzColor.primaryInk)
                .frame(width: 56, height: 56)
                .background(Circle().fill(HandzColor.primaryTint))
                .animation(HandzMotion.safe(HandzMotion.quick), value: initials)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("How others see you")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                Text(trimmed.isEmpty ? "Your name" : trimmed)
                    .font(HandzTypography.sectionTitle)
                    .foregroundColor(trimmed.isEmpty ? HandzColor.textFaint : HandzColor.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .cardStyle(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func saveTapped() {
        guard canSave else {
            if trimmed.isEmpty {
                touched = true
                HandzHaptics.error()
                withHandzAnimation(HandzMotion.quick) { shakes += 1 }
            }
            return
        }
        focused = false
        HandzHaptics.press()
        Task { await save() }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await PreferencesRepository.shared.updateName(trimmed)
            await authSession.refreshCurrentUser()
            HandzHaptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HandzHaptics.error()
            withHandzAnimation(HandzMotion.quick) { shakes += 1 }
        }
        isSaving = false
    }
}

// MARK: Change password

struct ChangePasswordView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case current, new, confirm
    }

    @FocusState private var focused: Field?
    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var showPasswords = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var success = false
    @State private var shakes = 0

    init() {}

    private var isLongEnough: Bool { newPassword.count >= 8 }
    private var matches: Bool { !confirm.isEmpty && newPassword == confirm }

    private var canSave: Bool {
        !current.isEmpty && isLongEnough && matches && !isSaving
    }

    /// Only complain about the confirm field once they've typed enough or moved on.
    private var confirmError: String? {
        let doneTyping = focused != .confirm || confirm.count >= newPassword.count
        if !confirm.isEmpty && newPassword != confirm && doneTyping {
            return "Passwords don't match."
        }
        return nil
    }

    var body: some View {
        Group {
            if success {
                SettingsSuccessView(
                    icon: "checkmark",
                    title: "Password changed",
                    message: "Next time you log in, use your new password.",
                    buttonTitle: "Done"
                ) {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                form
            }
        }
        .handzScreenBackground()
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .hidesHandzTabBar()
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HandzFormField("Current password") {
                    passwordField("Your current password", text: $current,
                                  field: .current, contentType: .password, hasError: false)
                }

                HandzFormField("New password") {
                    passwordField("At least 8 characters", text: $newPassword,
                                  field: .new, contentType: .newPassword, hasError: false)
                }

                HandzFormField("Confirm new password", error: confirmError) {
                    passwordField("Type it again", text: $confirm,
                                  field: .confirm, contentType: .newPassword,
                                  hasError: confirmError != nil)
                }

                VStack(alignment: .leading, spacing: 8) {
                    rule("At least 8 characters", met: isLongEnough)
                    rule("Both new passwords match", met: matches)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                        .fill(HandzColor.surface)
                )
                .animation(HandzMotion.safe(HandzMotion.quick), value: isLongEnough)
                .animation(HandzMotion.safe(HandzMotion.quick), value: matches)
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SettingsActionBar(
                title: "Change password",
                busyTitle: "Saving…",
                isBusy: isSaving,
                isEnabled: canSave,
                error: errorMessage,
                shakes: shakes,
                action: saveTapped
            )
        }
    }

    private func passwordField(_ placeholder: String, text: Binding<String>, field: Field,
                               contentType: UITextContentType, hasError: Bool) -> some View {
        HStack(spacing: 8) {
            Group {
                if showPasswords {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textContentType(contentType)
            .focused($focused, equals: field)
            .submitLabel(field == .confirm ? .done : .next)
            .onSubmit { advance(from: field) }

            Button {
                HandzHaptics.tap()
                showPasswords.toggle()
            } label: {
                Image(systemName: showPasswords ? "eye.slash" : "eye")
                    .foregroundColor(HandzColor.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(showPasswords ? "Hide passwords" : "Show passwords")
        }
        .handzField(isFocused: focused == field, hasError: hasError)
    }

    private func rule(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(met ? HandzColor.accent : HandzColor.textFaint)
            Text(text)
                .font(HandzTypography.caption.weight(met ? .semibold : .regular))
                .foregroundColor(met ? HandzColor.accentInk : HandzColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text), \(met ? "done" : "not yet")")
    }

    private func advance(from field: Field) {
        switch field {
        case .current: focused = .new
        case .new: focused = .confirm
        case .confirm: saveTapped()
        }
    }

    private func saveTapped() {
        guard canSave else { return }
        focused = nil
        HandzHaptics.press()
        Task { await save() }
    }

    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            try await authSession.changePassword(current: current, new: newPassword)
            HandzHaptics.success()
            withHandzAnimation(HandzMotion.standard) { success = true }
        } catch {
            errorMessage = error.localizedDescription
            HandzHaptics.error()
            withHandzAnimation(HandzMotion.quick) { shakes += 1 }
        }
        isSaving = false
    }
}

// MARK: Blocked users

struct BlockedUsersView: View {
    @State private var blocked: [BlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var unblockingId: String?
    @State private var userToUnblock: BlockedUser?

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
            .animation(HandzMotion.safe(HandzMotion.standard), value: blocked.map(\.id))
        }
        .handzScreenBackground()
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog(confirmTitle, isPresented: showingConfirm, titleVisibility: .visible) {
            if let user = userToUnblock {
                Button("Unblock \(user.name)") {
                    Task { await unblock(user) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can block them again any time from their profile.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && blocked.isEmpty {
            HandzLoadingList(count: 2)
        } else if let errorMessage = errorMessage, blocked.isEmpty {
            HandzErrorCard(message: errorMessage) {
                Task { await load() }
            }
        } else if blocked.isEmpty {
            HandzEmptyState(
                icon: "hand.raised",
                title: "No one blocked",
                message: "If you block someone from their profile, they'll show up here. You can unblock them any time."
            )
        } else {
            Text("Unblock someone if you'd like to work with them again.")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)

            if let actionError = actionError {
                Label(actionError, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
            }

            VStack(spacing: 10) {
                ForEach(blocked) { user in
                    row(user)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
    }

    private func row(_ user: BlockedUser) -> some View {
        HStack(spacing: 12) {
            Text(initials(of: user.name))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(HandzColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(HandzColor.background))
                .accessibilityHidden(true)

            Text(user.name)
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if unblockingId == user.id {
                ProgressView()
                    .frame(width: 96, height: 44)
            } else {
                Button("Unblock") {
                    HandzHaptics.tap()
                    userToUnblock = user
                }
                .buttonStyle(UnblockPillStyle())
                .accessibilityLabel("Unblock \(user.name)")
            }
        }
        .cardStyle(padding: 14)
    }

    private var confirmTitle: String {
        "Unblock \(userToUnblock?.name ?? "this person")?"
    }

    private var showingConfirm: Binding<Bool> {
        Binding(
            get: { userToUnblock != nil },
            set: { if !$0 { userToUnblock = nil } }
        )
    }

    private func initials(of name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    @MainActor
    private func load() async {
        do {
            let users = try await SafetyRepository.shared.blockedUsers()
            withHandzAnimation {
                blocked = users
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func unblock(_ user: BlockedUser) async {
        unblockingId = user.id
        actionError = nil
        do {
            try await SafetyRepository.shared.unblock(userId: user.id)
            HandzHaptics.success()
            withHandzAnimation {
                blocked.removeAll { $0.id == user.id }
            }
        } catch {
            HandzHaptics.error()
            actionError = error.localizedDescription
        }
        unblockingId = nil
    }
}

/// Small teal pill for "Unblock".
private struct UnblockPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.primaryInk)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Capsule().fill(HandzColor.primaryTint))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}

// MARK: Report a user

struct ReportUserView: View {
    let userId: String
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var detailsFocused: Bool

    @State private var reason: String?
    @State private var details = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var sent = false
    @State private var shakes = 0

    init(userId: String, userName: String) {
        self.userId = userId
        self.userName = userName
    }

    private struct ReportReason: Identifiable {
        let value: String
        let label: String
        let icon: String
        var id: String { value }
    }

    private let reasons: [ReportReason] = [
        ReportReason(value: "no_show", label: "Didn't show up", icon: "person.fill.xmark"),
        ReportReason(value: "harassment", label: "Harassment", icon: "exclamationmark.bubble"),
        ReportReason(value: "unsafe_behavior", label: "Unsafe behavior", icon: "exclamationmark.shield"),
        ReportReason(value: "fraud", label: "Fraud or scam", icon: "dollarsign.circle"),
        ReportReason(value: "inappropriate_content", label: "Inappropriate content", icon: "eye.slash"),
        ReportReason(value: "other", label: "Other", icon: "ellipsis.circle"),
    ]

    var body: some View {
        HandzNavigationStack {
            Group {
                if sent {
                    SettingsSuccessView(
                        icon: "checkmark.shield.fill",
                        title: "Report sent",
                        message: "Thanks for letting us know. Our team will review it.",
                        buttonTitle: "Done"
                    ) {
                        dismiss()
                    }
                    .transition(.opacity)
                } else {
                    form
                }
            }
            .handzScreenBackground()
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !sent {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .tint(HandzColor.primary)
        .interactiveDismissDisabled(isSending)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("If anyone is in danger, call 911 first.", systemImage: "phone.fill")
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                            .fill(HandzColor.dangerTint)
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Why are you reporting \(userName)?")
                        .font(HandzTypography.sectionTitle)
                        .foregroundColor(HandzColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(reasons) { item in
                        reasonRow(item)
                    }
                }

                HandzFormField("Details (optional)",
                               hint: "Dates, places or what was said help our team.") {
                    HandzGrowingTextField("What happened?", text: $details, lines: 3...6)
                        .focused($detailsFocused)
                        .padding(.vertical, 14)
                        .handzField(isFocused: detailsFocused)
                }

                Label("Your report goes to the Handz team for review.", systemImage: "lock")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SettingsActionBar(
                title: reason == nil ? "Choose a reason" : "Submit report",
                busyTitle: "Sending…",
                isBusy: isSending,
                isEnabled: reason != nil && !isSending,
                isDestructive: true,
                error: errorMessage,
                shakes: shakes,
                action: sendTapped
            )
        }
    }

    private func reasonRow(_ item: ReportReason) -> some View {
        let isSelected = reason == item.value
        return Button {
            HandzHaptics.select()
            withHandzAnimation(HandzMotion.quick) { reason = item.value }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.primaryInk)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isSelected ? HandzColor.primary : HandzColor.primaryTint))
                    .accessibilityHidden(true)
                Text(item.label)
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.primary : HandzColor.textFaint)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(isSelected ? HandzColor.primaryTint : HandzColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .stroke(isSelected ? HandzColor.primary : HandzColor.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sendTapped() {
        guard reason != nil, !isSending else { return }
        detailsFocused = false
        HandzHaptics.press()
        Task { await send() }
    }

    @MainActor
    private func send() async {
        guard let reason = reason else { return }
        isSending = true
        errorMessage = nil
        let trimmed = details.handzTrimmed
        do {
            try await SafetyRepository.shared.report(
                userId: userId, reason: reason, details: trimmed.isEmpty ? nil : trimmed
            )
            HandzHaptics.success()
            withHandzAnimation(HandzMotion.standard) { sent = true }
        } catch {
            errorMessage = error.localizedDescription
            HandzHaptics.error()
            withHandzAnimation(HandzMotion.quick) { shakes += 1 }
        }
        isSending = false
    }
}

// MARK: - Shared pieces for these screens

/// The button that stays at the bottom, with any error shown just above it.
private struct SettingsActionBar: View {
    let title: String
    let busyTitle: String
    let isBusy: Bool
    let isEnabled: Bool
    let isDestructive: Bool
    let error: String?
    let shakes: Int
    let action: () -> Void

    init(title: String, busyTitle: String, isBusy: Bool, isEnabled: Bool,
         isDestructive: Bool = false, error: String?, shakes: Int,
         action: @escaping () -> Void) {
        self.title = title
        self.busyTitle = busyTitle
        self.isBusy = isBusy
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.error = error
        self.shakes = shakes
        self.action = action
    }

    var body: some View {
        VStack(spacing: 8) {
            if let error = error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .handzShake(shakes)
            }

            Button(action: action) {
                if isBusy {
                    HStack(spacing: 8) {
                        ProgressView().tint(HandzColor.onFill)
                        Text(busyTitle)
                    }
                } else {
                    Text(title)
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDestructive: isDestructive))
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(
            HandzColor.background
                .overlay(alignment: .top) { Rectangle().fill(HandzColor.border).frame(height: 1) }
                .ignoresSafeArea()
        )
    }
}

/// Friendly "it worked" screen (replaces the old pop-up alerts).
private struct SettingsSuccessView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void
    @State private var shown = false

    init(icon: String, title: String, message: String, buttonTitle: String,
         action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(systemName: icon)
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(HandzColor.onFill)
                .frame(width: 96, height: 96)
                .background(Circle().fill(HandzColor.accent))
                .scaleEffect(shown ? 1 : 0.4)
                .opacity(shown ? 1 : 0)
                .accessibilityHidden(true)

            Text(title)
                .font(HandzTypography.title)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(buttonTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withHandzAnimation(HandzMotion.bouncy) { shown = true }
        }
    }
}

// MARK: Change phone number

struct EditPhoneView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    @State private var phone: String = ""
    @State private var original: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var shakes = 0

    private var digits: String { phone.filter { $0.isNumber } }
    private var isValid: Bool { (10...15).contains(digits.count) }
    private var canSave: Bool { isValid && digits != original && !isSaving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HandzFormField("Phone number",
                               hint: "Only shared with the person you're working with, from hiring until a day after the job.",
                               error: !phone.isEmpty && !isValid ? "Enter a full phone number." : nil) {
                    TextField("(404) 555-0123", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focused)
                        .handzField(isFocused: focused, hasError: !phone.isEmpty && !isValid)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScrollDismissesKeyboard()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SettingsActionBar(
                title: "Save phone number",
                busyTitle: "Saving…",
                isBusy: isSaving,
                isEnabled: canSave,
                error: errorMessage,
                shakes: shakes,
                action: { Task { await save() } }
            )
        }
        .handzScreenBackground()
        .navigationTitle("Phone Number")
        .navigationBarTitleDisplayMode(.inline)
        .hidesHandzTabBar()
        .onAppear {
            let current = authSession.currentUser?.phone ?? ""
            phone = current
            original = current.filter { $0.isNumber }
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        focused = false
        isSaving = true
        errorMessage = nil
        do {
            try await PreferencesRepository.shared.updatePhone(digits)
            await authSession.refreshCurrentUser()
            HandzHaptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            HandzHaptics.error()
            withHandzAnimation(HandzMotion.quick) { shakes += 1 }
        }
        isSaving = false
    }
}
