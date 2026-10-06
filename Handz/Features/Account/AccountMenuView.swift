import SwiftUI

struct AccountMenuView: View {
    @EnvironmentObject private var authSession: AuthSession

    private var isWorker: Bool { authSession.currentUser?.role == "worker" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileCard

                menuSection("Activity") {
                    row("Notifications", icon: "bell", tone: .info) { NotificationsView() }
                    row(isWorker ? "Pay and receipts" : "Payments and receipts", icon: "doc.text", tone: .success) {
                        PaymentHistoryView()
                    }
                    row("My reports", icon: "exclamationmark.bubble", tone: .attention, isLast: true) { MyReportsView() }
                }

                if isWorker {
                    workerSection
                } else {
                    menuSection("Paying") {
                        row("Payment method", icon: "creditcard", tone: .success, isLast: true) { PaymentMethodView() }
                    }
                }

                menuSection("Help") {
                    row("How Handz works", icon: "questionmark.circle", tone: .info, isLast: true) {
                        HowHandzWorksView()
                    }
                }

                if authSession.currentUser?.isAdmin == true {
                    menuSection("Handz admin") {
                        row("Reported problems", icon: "checkmark.shield", tone: .attention, isLast: true) {
                            AdminDisputesView()
                        }
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Account")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    // MARK: - Profile card

    @ViewBuilder
    private var profileCard: some View {
        if let user = authSession.currentUser {
            NavigationLink {
                ProfileView(userId: user.id, userName: user.name)
            } label: {
                HStack(spacing: 14) {
                    AvatarView(photoPath: user.photoUrl, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(HandzTypography.sectionTitle)
                            .foregroundColor(HandzColor.textPrimary)
                        HandzChip(text: isWorker ? "Worker" : "Hiring",
                                  icon: isWorker ? "briefcase" : "person.2",
                                  kind: .info)
                        Text("View my profile")
                            .font(HandzTypography.caption.weight(.semibold))
                            .foregroundColor(HandzColor.primary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(HandzColor.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    // MARK: - Worker section

    private var workerSection: some View {
        menuSection("Work") {
            row("Earnings", icon: "chart.bar", tone: .success) { EarningsView() }
            row("Jobs you applied to", icon: "paperplane", tone: .info) { MyAppliedJobsView() }
            row("Saved jobs", icon: "bookmark", tone: .info) { SavedJobsView() }
            row("Payouts", icon: "banknote", tone: .success) { PayoutSettingsView() }
            row("ID verification", icon: "checkmark.seal", tone: .info, isLast: true) { IdentityVerificationView() }
        }
    }

    // MARK: - Building blocks

    private func menuSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textSecondary)
                .textCase(.uppercase)
                .padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                content()
            }
            .clipShape(RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous))
            .background(sectionBackground)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
            .fill(HandzColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                    .stroke(HandzColor.border, lineWidth: 1)
            )
    }

    private func row<Destination: View>(_ title: String, icon: String, tone: HandzChip.Kind,
                                        isLast: Bool = false,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            rowLabel(title, icon: icon, tone: tone, titleColor: HandzColor.textPrimary,
                     showsChevron: true, isLast: isLast)
        }
        .buttonStyle(MenuRowStyle())
    }

    private func rowLabel(_ title: String, icon: String, tone: HandzChip.Kind, titleColor: Color,
                          showsChevron: Bool, isLast: Bool) -> some View {
        let colors = toneColors(tone)
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(colors.text)
                .frame(width: 34, height: 34)
                .background(Circle().fill(colors.fill))
                .accessibilityHidden(true)
            Text(title)
                .font(HandzTypography.body)
                .foregroundColor(titleColor)
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(HandzColor.border)
                    .frame(height: 1)
                    .padding(.leading, 60)
            }
        }
    }

    private func toneColors(_ tone: HandzChip.Kind) -> (text: Color, fill: Color) {
        switch tone {
        case .info:      return (HandzColor.primaryInk, HandzColor.primaryTint)
        case .success:   return (HandzColor.accentInk, HandzColor.accentTint)
        case .attention: return (HandzColor.warningInk, HandzColor.warningTint)
        case .danger:    return (HandzColor.dangerInk, HandzColor.dangerTint)
        case .neutral:   return (HandzColor.textSecondary, HandzColor.background)
        }
    }
}

/// Rows in a grouped card: a soft highlight while pressed instead of shrinking.
private struct MenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? HandzColor.background : Color.clear)
            .animation(HandzMotion.quick, value: configuration.isPressed)
    }
}

struct AccountMenuView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack {
            AccountMenuView()
                .environmentObject(AuthSession.shared)
        }
    }
}
