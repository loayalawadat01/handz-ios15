import SwiftUI

/// Home, in the clean "money app" style: a big number or headline at the top,
/// two dark pill buttons, two tiles, one dark banner for the most important
/// thing, then simple lists (upcoming jobs, recent payments with receipts).
struct HomeView: View {
    @EnvironmentObject private var authSession: AuthSession
    @Environment(\.handzTabBar) private var tabBar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = HomeViewModel()

    @State private var appeared = false
    @State private var showingPostJob = false      // backup if the tab bar isn't available
    @State private var showingFindWork = false
    @State private var showingPayments = false

    private var isWorker: Bool { authSession.currentUser?.role == "worker" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HandzSpacing.lg) {
                    entrance(header, order: 0)
                    entrance(StateNoticeCard(), order: 0)
                    entrance(heroSection, order: 1)
                    entrance(tiles, order: 2)
                    entrance(bannerSection, order: 3)

                    if !otherAttentionItems.isEmpty {
                        entrance(attentionSection, order: 3)
                    }

                    if let message = viewModel.errorMessage {
                        errorCard(message)
                    }

                    if !viewModel.hasLoadedOnce && viewModel.isLoading {
                        placeholderCards
                    } else {
                        entrance(isWorker ? AnyView(workerSections) : AnyView(hireSections), order: 4)
                    }

                    if !viewModel.recentPayments.isEmpty {
                        entrance(paymentsSection, order: 5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, HandzSpacing.sm)
                .padding(.bottom, HandzSpacing.xl)
            }
            .handzScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .handzTabBarRoom()
            .onAppear {
                appeared = true
                viewModel.setInitialMode(forRole: authSession.currentUser?.role ?? "customer")
                Task { await viewModel.loadData() }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .navigationDestination(isPresented: $showingPostJob) { PostJobView() }
            .navigationDestination(isPresented: $showingFindWork) { BrowseJobsView() }
            .navigationDestination(isPresented: $showingPayments) { PaymentHistoryView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: HandzSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                Text(firstName)
                    .font(HandzTypography.largeTitle)
                    .foregroundColor(HandzColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: HandzSpacing.sm)

            NavigationLink {
                NotificationsView()
            } label: {
                bellIcon
            }
            .buttonStyle(HandzPressStyle())
            .accessibilityLabel(viewModel.unreadCount > 0
                                ? "Notifications, \(viewModel.unreadCount) unread"
                                : "Notifications")

            Button {
                tabBar?.select(.account)
            } label: {
                AvatarView(photoPath: authSession.currentUser?.photoUrl, size: 44)
            }
            .buttonStyle(HandzPressStyle())
            .accessibilityLabel("Your account")
        }
        .padding(.top, HandzSpacing.sm)
    }

    private var bellIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(HandzColor.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(HandzColor.surface))

            if viewModel.unreadCount > 0 {
                Circle()
                    .fill(HandzColor.warning)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(HandzColor.surface, lineWidth: 2))
                    .offset(x: -8, y: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(HandzMotion.safe(HandzMotion.bouncy), value: viewModel.unreadCount > 0)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        default:      return "Good evening,"
        }
    }

    private var firstName: String {
        let name = authSession.currentUser?.name ?? ""
        return name.split(separator: " ").first.map(String.init) ?? "there"
    }

    // MARK: - Top: big number (worker) or headline (customer), and two pill buttons

    @ViewBuilder
    private var heroSection: some View {
        if isWorker {
            workerHero
        } else {
            hireHero
        }
    }

    private var workerHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HandzEyebrow("Earned this week")
                HandzAmountText(viewModel.earnings?.last7Days ?? 0)
                    .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.earnings?.last7Days)
                if let pending = viewModel.earnings?.pending, pending > 0 {
                    Text("\(HandzMoney.text(pending)) more coming to you")
                        .font(HandzTypography.caption.weight(.semibold))
                        .foregroundColor(HandzColor.accentInk)
                }
            }
            .accessibilityElement(children: .combine)

            AvailabilityStatusLine()

            HStack(alignment: .top, spacing: 12) {
                AvailabilityToggle()
                Button {
                    if let tabBar = tabBar {
                        tabBar.select(.findWork)
                    } else {
                        showingFindWork = true
                    }
                } label: {
                    Label("Find work", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hireHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HandzEyebrow("Need a hand?")
                Text("Post a job and hear from neighbors who can help.")
                    .font(HandzTypography.title)
                    .foregroundColor(HandzColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button {
                    if let tabBar = tabBar {
                        tabBar.select(.post)
                    } else {
                        showingPostJob = true
                    }
                } label: {
                    Label("Post a job", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle(compact: true))

                Button {
                    tabBar?.select(.myJobs)
                } label: {
                    Label("My jobs", systemImage: "list.bullet")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .disabled(tabBar == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Two tiles

    @ViewBuilder
    private var tiles: some View {
        if isWorker {
            HandzTileRow {
                nextJobTile
            } right: {
                NavigationLink {
                    EarningsView()
                } label: {
                    HandzTile(icon: "chart.bar.fill",
                              title: HandzMoney.text(viewModel.earnings?.last30Days ?? 0),
                              subtitle: "Earned in the last 30 days")
                }
                .buttonStyle(HandzPressStyle())
            }
        } else {
            HandzTileRow {
                Button {
                    tabBar?.select(.myJobs)
                } label: {
                    HandzTile(icon: "briefcase.fill",
                              title: "\(viewModel.activeJobsCount) active job\(viewModel.activeJobsCount == 1 ? "" : "s")",
                              subtitle: interestedText,
                              highlight: totalInterested > 0)
                }
                .buttonStyle(HandzPressStyle())
            } right: {
                NavigationLink {
                    PaymentHistoryView()
                } label: {
                    HandzTile(icon: "doc.text.fill",
                              title: "Receipts",
                              subtitle: "Payments and receipts")
                }
                .buttonStyle(HandzPressStyle())
            }
        }
    }

    @ViewBuilder
    private var nextJobTile: some View {
        if let next = viewModel.nextAssignment {
            NavigationLink {
                JobDetailView(jobId: next.jobId)
            } label: {
                HandzTile(icon: "calendar", title: next.jobTitle, subtitle: scheduleText(for: next), highlight: true)
            }
            .buttonStyle(HandzPressStyle())
        } else {
            Button {
                if let tabBar = tabBar {
                    tabBar.select(.findWork)
                } else {
                    showingFindWork = true
                }
            } label: {
                HandzTile(icon: "calendar", title: "No job booked", subtitle: "Find work near you")
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    private var totalInterested: Int {
        viewModel.myJobs.filter { $0.status == .open }.reduce(0) { $0 + $1.offerCount }
    }

    private var interestedText: String {
        let count = totalInterested
        if count == 0 { return "Waiting for workers" }
        return "\(count) worker\(count == 1 ? "" : "s") interested"
    }

    // MARK: - The one dark banner: the most important thing right now

    private enum Banner {
        case receipt(Payment)
        case attention(AttentionItem)
        case verifyID
        case guide
    }

    private var banner: Banner {
        if let payment = viewModel.newReceipt { return .receipt(payment) }
        if let first = viewModel.attentionItems.first { return .attention(first) }
        if isWorker && authSession.currentUser?.identityVerified != true { return .verifyID }
        return .guide
    }

    /// Attention items not already shown in the banner.
    private var otherAttentionItems: [AttentionItem] {
        if case .attention(let first) = banner {
            return viewModel.attentionItems.filter { $0.id != first.id }
        }
        return viewModel.attentionItems
    }

    @ViewBuilder
    private var bannerSection: some View {
        switch banner {
        case .receipt(let payment):
            NavigationLink {
                ReceiptView(paymentId: payment.id)
            } label: {
                HandzInkBanner(icon: "doc.text.fill",
                               title: "Your receipt is ready",
                               subtitle: payment.jobTitle ?? "Tap to see it",
                               trailing: HandzMoney.text(isWorker ? payment.workerKeepsAfterRefunds : payment.customerPaidAfterRefunds))
            }
            .buttonStyle(HandzPressStyle())
        case .attention(let item):
            NavigationLink {
                destinationView(for: item.destination)
            } label: {
                HandzInkBanner(icon: item.icon, title: item.title, subtitle: item.subtitle)
            }
            .buttonStyle(HandzPressStyle())
        case .verifyID:
            NavigationLink {
                IdentityVerificationView()
            } label: {
                HandzInkBanner(icon: "person.text.rectangle",
                               title: "Verify your ID",
                               subtitle: "Customers trust verified workers. It takes 2 minutes.")
            }
            .buttonStyle(HandzPressStyle())
        case .guide:
            NavigationLink {
                HowHandzWorksView(startWithWorkerGuide: isWorker)
            } label: {
                HandzInkBanner(icon: "lightbulb.fill",
                               title: "How Handz works",
                               subtitle: isWorker ? "Get hired, check in, get paid." : "Post, hire, pay only when it's done.")
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    // MARK: - Needs your attention (the rest)

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HandzSectionTitle("Needs your attention")

            HandzListGroup {
                ForEach(otherAttentionItems) { item in
                    NavigationLink {
                        destinationView(for: item.destination)
                    } label: {
                        HandzListRow(title: item.title, subtitle: item.subtitle, showsChevron: true) {
                            iconBubble(item.icon, tone: item.tone)
                        }
                    }
                    .buttonStyle(HandzRowPressStyle())
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(HandzMotion.safe(HandzMotion.standard), value: otherAttentionItems.map(\.id))
    }

    private func iconBubble(_ icon: String, tone: AttentionItem.Tone) -> some View {
        let colors = toneColors(tone)
        return HandzIconBubble(icon, text: colors.text, fill: colors.fill)
    }

    private func toneColors(_ tone: AttentionItem.Tone) -> (text: Color, fill: Color) {
        switch tone {
        case .attention: return (HandzColor.warningInk, HandzColor.warningTint)
        case .info:      return (HandzColor.primaryInk, HandzColor.primaryTint)
        case .success:   return (HandzColor.accentInk, HandzColor.accentTint)
        case .danger:    return (HandzColor.dangerInk, HandzColor.dangerTint)
        case .neutral:   return (HandzColor.textSecondary, HandzColor.background)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: AttentionItem.Destination) -> some View {
        switch destination {
        case .jobDetail(let jobId):
            JobDetailView(jobId: jobId)
        case .payment(let jobId, let deadline):
            PaymentsView(jobId: jobId, paymentDeadline: deadline, isOwner: true)
        }
    }

    // MARK: - Hire side: upcoming jobs

    private var hireSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            HandzSectionTitle("Upcoming", actionTitle: tabBar == nil ? nil : "See all") {
                tabBar?.select(.myJobs)
            }

            if viewModel.upcomingJobs.isEmpty {
                emptyCard(icon: "calendar",
                          title: "No upcoming jobs",
                          message: "Jobs you post will show up here, with who's coming and when.")
            } else {
                HandzListGroup {
                    ForEach(viewModel.upcomingJobs.prefix(3)) { job in
                        NavigationLink {
                            JobDetailView(jobId: job.id)
                        } label: {
                            jobListRow(job)
                        }
                        .buttonStyle(HandzRowPressStyle())
                    }
                }
            }
        }
    }

    private func jobListRow(_ job: Job) -> some View {
        let when = ScheduleDisplay.text(scheduledAt: job.scheduledAt, isFlexible: job.isFlexibleSchedule != 0)
        let workers = job.workersNeeded == 1 ? "1 worker" : "\(job.workersNeeded) workers"
        return HandzListRow(
            title: job.title,
            subtitle: "\(when) · \(place(city: job.city, area: job.area))",
            trailing: hiringText(job),
            trailingDetail: workers,
            trailingColor: hiringColor(job)
        ) {
            HandzIconBubble("calendar")
        }
    }

    private func hiringText(_ job: Job) -> String {
        if job.status == .open && job.acceptedWorkersCount == 0 {
            return job.offerCount > 0 ? "\(job.offerCount) interested" : "Waiting"
        }
        return "\(job.acceptedWorkersCount) of \(job.workersNeeded) hired"
    }

    private func hiringColor(_ job: Job) -> Color {
        if job.status == .open && job.acceptedWorkersCount == 0 {
            return job.offerCount > 0 ? HandzColor.warningInk : HandzColor.textSecondary
        }
        return job.acceptedWorkersCount >= job.workersNeeded ? HandzColor.accentInk : HandzColor.primaryInk
    }

    // MARK: - Worker side: upcoming work and applications

    private var workerSections: some View {
        VStack(alignment: .leading, spacing: HandzSpacing.lg) {
            VStack(alignment: .leading, spacing: 12) {
                HandzSectionTitle("Upcoming work", actionTitle: tabBar == nil ? nil : "See all") {
                    tabBar?.select(.myWork)
                }

                if viewModel.upcomingAssignments.isEmpty {
                    emptyCard(icon: "calendar",
                              title: "No jobs booked yet",
                              message: "When a customer hires you, the job shows up here.")
                } else {
                    HandzListGroup {
                        ForEach(viewModel.upcomingAssignments.prefix(3)) { assignment in
                            NavigationLink {
                                JobDetailView(jobId: assignment.jobId)
                            } label: {
                                assignmentRow(assignment)
                            }
                            .buttonStyle(HandzRowPressStyle())
                        }
                    }
                }
            }

            if !viewModel.pendingOffers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HandzSectionTitle("Waiting to hear back (\(viewModel.pendingOffers.count))")

                    HandzListGroup {
                        ForEach(viewModel.pendingOffers.prefix(3)) { offer in
                            NavigationLink {
                                JobDetailView(jobId: offer.jobId)
                            } label: {
                                HandzListRow(
                                    title: offer.jobTitle,
                                    subtitle: ScheduleDisplay.text(scheduledAt: offer.scheduledAt, isFlexible: false),
                                    trailing: HandzMoney.text(offer.amount),
                                    trailingDetail: "You asked"
                                ) {
                                    HandzIconBubble("hourglass", text: HandzColor.warningInk, fill: HandzColor.warningTint)
                                }
                            }
                            .buttonStyle(HandzRowPressStyle())
                        }
                    }
                }
            }
        }
    }

    private func assignmentRow(_ assignment: MyAssignment) -> some View {
        // Pay is a flat amount per worker; workers keep it minus the 7.5% Handz fee
        let earn = assignment.targetRate.map { HandzMoney.text($0 * 0.925) }
        return HandzListRow(
            title: assignment.jobTitle,
            subtitle: "\(scheduleText(for: assignment)) · \(place(city: assignment.city, area: assignment.area))",
            trailing: earn,
            trailingDetail: earn == nil ? nil : "You earn",
            trailingColor: HandzColor.accentInk
        ) {
            HandzIconBubble("calendar")
        }
    }

    private func scheduleText(for assignment: MyAssignment) -> String {
        guard let date = assignment.scheduledAt else { return "Flexible timing" }
        return ScheduleDisplay.text(scheduledAt: date, isFlexible: (assignment.isFlexibleSchedule ?? 0) != 0)
    }

    // MARK: - Recent payments (each opens its receipt)

    private var paymentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HandzSectionTitle(isWorker ? "Recent pay" : "Recent payments", actionTitle: "See all") {
                showingPayments = true
            }

            HandzListGroup {
                ForEach(viewModel.recentPayments) { payment in
                    NavigationLink {
                        ReceiptView(paymentId: payment.id)
                    } label: {
                        PaymentListRow(payment: payment, isWorkerView: isWorker)
                    }
                    .buttonStyle(HandzRowPressStyle())
                }
            }
        }
    }

    // MARK: - Shared pieces

    private func emptyCard(icon: String, title: String, message: String) -> some View {
        HStack(spacing: 14) {
            HandzIconBubble(icon, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text(message)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.dangerInk)
            Button("Try again") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Grey, softly pulsing cards while Home loads for the first time.
    private var placeholderCards: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    Text("Help moving a two bedroom flat")
                        .font(HandzTypography.headline)
                    Text("Sat, Oct 4 · 9:00 AM · Decatur")
                        .font(HandzTypography.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
        }
        .loadingPlaceholder(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private func place(city: String?, area: String?) -> String {
        let parts = [area, city].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Location shared after hiring" : parts.joined(separator: ", ")
    }

    /// Sections fade and rise in one after another the first time Home opens.
    private func entrance<V: View>(_ view: V, order: Int) -> some View {
        view
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? HandzMotion.fade
                    : HandzMotion.standard.delay(Double(order) * HandzMotion.staggerStep * 2),
                value: appeared
            )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthSession.shared)
    }
}
