import SwiftUI
import UIKit

private struct JobToOpen: Identifiable {
    let id: String
}

/// Shows urgent alerts ("Your worker is running late", "Payment needed")
/// as a friendly card in the middle of the screen, over the whole app,
/// with "View job" (opens the job) and "Dismiss".
struct AlertPopupContainer<Content: View>: View {
    @ObservedObject private var poller = AlertPoller.shared
    @State private var jobToOpen: JobToOpen?
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var isShowingAlert: Bool { poller.pendingAlert != nil }

    var body: some View {
        ZStack {
            content()
                // While the card is up, VoiceOver only reads the card.
                .accessibilityHidden(isShowingAlert)

            if let alert = poller.pendingAlert {
                HandzColor.scrim
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityHidden(true)

                UrgentAlertCard(
                    notification: alert,
                    onView: { open(alert) },
                    onDismiss: { dismissAlert() }
                )
                .transition(cardTransition)
                .zIndex(1)
            }
        }
        .animation(HandzMotion.safe(HandzMotion.standard), value: poller.pendingAlert?.id)
        .onChange(of: poller.pendingAlert?.id) { newId in
            guard newId != nil, let alert = poller.pendingAlert else { return }
            if alert.isWarning {
                HandzHaptics.warning()
            } else {
                HandzHaptics.success()
            }
        }
        .sheet(item: $jobToOpen) { item in
            NavigationStack {
                JobDetailView(jobId: item.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { jobToOpen = nil }
                        }
                    }
            }
            .environmentObject(AuthSession.shared)
            .tint(HandzColor.primary)
        }
    }

    /// Pops in gently; just fades when Reduce Motion is on.
    private var cardTransition: AnyTransition {
        if UIAccessibility.isReduceMotionEnabled {
            return .opacity
        }
        return .scale(scale: 0.9).combined(with: .opacity)
    }

    private func open(_ alert: AppNotification) {
        HandzHaptics.tap()
        Task { try? await NotificationsRepository.shared.markRead(id: alert.id) }
        poller.dismiss()
        if let jobId = alert.jobId {
            jobToOpen = JobToOpen(id: jobId)
        }
    }

    private func dismissAlert() {
        HandzHaptics.tap()
        poller.dismiss()
    }
}

// MARK: - The card

struct UrgentAlertCard: View {
    let notification: AppNotification
    var onView: () -> Void
    var onDismiss: () -> Void
    @State private var shown = false

    init(notification: AppNotification, onView: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.notification = notification
        self.onView = onView
        self.onDismiss = onDismiss
    }

    private var isWarning: Bool { notification.isWarning }
    private var hasJob: Bool { notification.jobId != nil }
    private var fill: Color { isWarning ? HandzColor.warning : HandzColor.primary }
    private var halo: Color { isWarning ? HandzColor.warningTint : HandzColor.primaryTint }

    /// Warnings without their own icon get a clock with "!" instead of a plain bell.
    private var symbol: String {
        if isWarning && notification.iconName == "bell.fill" {
            return "clock.badge.exclamationmark"
        }
        return notification.iconName
    }

    var body: some View {
        VStack(spacing: 14) {
            icon

            HandzChip(
                text: isWarning ? "Needs your attention" : "Job update",
                icon: isWarning ? "exclamationmark" : "bell",
                kind: isWarning ? .attention : .info
            )

            Text(notification.title)
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let message = notification.body {
                Text(message)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            buttons
                .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(cardBackground)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withHandzAnimation(HandzMotion.bouncy) { shown = true }
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(halo)
                .frame(width: 92, height: 92)
                .scaleEffect(shown ? 1 : 0.6)
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(HandzColor.onFill)
                .frame(width: 64, height: 64)
                .background(Circle().fill(fill))
                .scaleEffect(shown ? 1 : 0.5)
        }
        .opacity(shown ? 1 : 0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 6) {
            if hasJob {
                Button("View job", action: onView)
                    .buttonStyle(PrimaryButtonStyle(color: isWarning ? HandzColor.warning : nil))
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(AlertQuietButtonStyle())
            } else {
                Button("Got it", action: onDismiss)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: HandzRadius.xl, style: .continuous)
            .fill(HandzColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.xl, style: .continuous)
                    .stroke(HandzColor.border, lineWidth: 1)
            )
            .shadow(color: HandzColor.shadow.opacity(0.22), radius: 30, x: 0, y: 14)
    }
}

/// Plain text button for the second, quieter choice ("Dismiss").
private struct AlertQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandzTypography.button)
            .foregroundColor(HandzColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}
