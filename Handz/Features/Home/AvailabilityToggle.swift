import SwiftUI

/// The worker's Online / Offline pill on Home (it sits next to "Find work").
/// Online: pop-ups for new jobs as they're posted. Offline: no pop-ups
/// (jobs are still in Find Work). Going online never brings a pile of old jobs.
/// Offline it's a dark "Go online" button; online it's a white "Go offline" one.
struct AvailabilityToggle: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isOnline: Bool { authSession.currentUser?.isAvailable != false }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isOnline {
                toggleButton.buttonStyle(SecondaryButtonStyle(compact: true))
            } else {
                toggleButton.buttonStyle(PrimaryButtonStyle(compact: true))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(HandzMotion.safe(HandzMotion.standard), value: isOnline)
    }

    private var toggleButton: some View {
        Button {
            Task { await toggle() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(isOnline ? HandzColor.textPrimary : HandzColor.onInk)
                } else {
                    Image(systemName: isOnline ? "moon.zzz" : "bolt.fill")
                        .accessibilityHidden(true)
                }
                Text(isOnline ? "Go offline" : "Go online")
            }
        }
        .disabled(isSaving)
        .accessibilityLabel(isOnline ? "Online for job pop-ups" : "Offline, no job pop-ups")
        .accessibilityHint(isOnline ? "Double tap to go offline" : "Double tap to go online")
    }

    private func toggle() async {
        isSaving = true
        errorMessage = nil
        let goingOnline = !isOnline
        do {
            try await PreferencesRepository.shared.setAvailability(goingOnline)
            await authSession.refreshCurrentUser()
            HandzHaptics.tap()
            if !goingOnline { DispatchPoller.shared.dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

/// "Online · New jobs pop up as they're posted", with a soft pulsing dot.
struct AvailabilityStatusLine: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isOnline: Bool { authSession.currentUser?.isAvailable != false }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((isOnline ? HandzColor.accent : HandzColor.textFaint).opacity(0.3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isOnline && pulse ? 1.25 : 0.8)
                    .opacity(isOnline && pulse ? 0.2 : 0.8)
                Circle()
                    .fill(isOnline ? HandzColor.accent : HandzColor.textFaint)
                    .frame(width: 8, height: 8)
            }
            .accessibilityHidden(true)

            Text(isOnline ? "Online · New jobs pop up as they're posted" : "Offline · No job pop-ups right now")
                .font(HandzTypography.caption.weight(.semibold))
                .foregroundColor(HandzColor.textSecondary)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
