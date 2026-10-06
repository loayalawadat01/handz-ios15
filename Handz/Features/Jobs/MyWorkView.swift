import SwiftUI

@MainActor
final class MyWorkViewModel: ObservableObject {
    @Published var assignments: [MyAssignment] = []
    @Published var earnings: EarningsSummary?
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let a = JobWorkersRepository.shared.myAssignments()
            async let e = PaymentsRepository.shared.earnings()
            let loadedAssignments = try await a
            let loadedEarnings = try await e
            withHandzAnimation {
                assignments = loadedAssignments
                earnings = loadedEarnings
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        hasLoadedOnce = true
    }

    var workingNow: [MyAssignment] {
        assignments.filter { $0.status == .active && $0.startedAt != nil && $0.completedAt == nil }
    }

    var today: [MyAssignment] {
        assignments.filter { a in
            guard a.status == .active, a.startedAt == nil else { return false }
            if a.isFlexibleSchedule == 1 { return true }
            guard let date = a.scheduledAt else { return false }
            return Calendar.current.isDateInToday(date) || date < Date()
        }
    }

    var upcoming: [MyAssignment] {
        assignments.filter { a in
            guard a.status == .active, a.startedAt == nil, a.isFlexibleSchedule != 1,
                  let date = a.scheduledAt else { return false }
            return !Calendar.current.isDateInToday(date) && date > Date()
        }
        .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    var finished: [MyAssignment] {
        assignments.filter { $0.completedAt != nil }
    }
}

struct MyWorkView: View {
    @StateObject private var viewModel = MyWorkViewModel()
    @Environment(\.handzTabBar) private var tabBar

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                earningsCard

                if !viewModel.hasLoadedOnce && viewModel.isLoading {
                    HandzLoadingList(count: 3)
                } else if let errorMessage = viewModel.errorMessage, viewModel.assignments.isEmpty {
                    HandzErrorCard(message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                } else if viewModel.assignments.isEmpty {
                    HandzEmptyState(
                        icon: "calendar",
                        title: "No jobs yet",
                        message: "When a customer hires you, the job shows up here with everything you need for the day.",
                        actionTitle: tabBar == nil ? nil : "Find work",
                        action: { tabBar?.select(.findWork) }
                    )
                } else {
                    section("Working now", viewModel.workingNow)
                    section("Today", viewModel.today)
                    section("Upcoming", viewModel.upcoming)
                    section("Finished", viewModel.finished)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("My Work")
        .onAppear { Task { await viewModel.load() } }
        .handzRefreshable { await viewModel.load() }
    }

    // MARK: - Earnings (opens the Earnings screen)

    private var earningsCard: some View {
        NavigationLink {
            EarningsView()
        } label: {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last 7 days")
                        .font(HandzTypography.captionBold)
                        .opacity(0.9)
                    Text(money(viewModel.earnings?.last7Days ?? 0))
                        .font(HandzTypography.money)
                        .handzNumericTextTransition()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Pending")
                        .font(HandzTypography.captionBold)
                        .opacity(0.9)
                    Text(money(viewModel.earnings?.pending ?? 0))
                        .font(HandzTypography.moneySmall)
                        .handzNumericTextTransition()
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .opacity(0.9)
                    .padding(.leading, 6)
                    .accessibilityHidden(true)
            }
            .foregroundColor(HandzColor.onFill)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(HandzColor.primary)
            )
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your earnings")
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ title: String, _ items: [MyAssignment]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HandzSectionHeader(title, count: items.count)
                ForEach(items) { item in
                    NavigationLink {
                        JobDetailView(jobId: item.jobId)
                    } label: {
                        row(item)
                    }
                    .buttonStyle(HandzPressStyle())
                }
            }
            .transition(.opacity)
        }
    }

    private func row(_ item: MyAssignment) -> some View {
        let status = statusChip(item)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: HandzSpacing.sm) {
                Text(item.jobTitle)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: HandzSpacing.sm)
                HandzChip(text: status.text, icon: status.icon, kind: status.kind)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(scheduleText(item), systemImage: "calendar")
                if let city = item.city {
                    Label([item.area, city].compactMap { $0 }.joined(separator: ", "),
                          systemImage: "mappin.and.ellipse")
                }
            }
            .font(HandzTypography.caption.weight(.semibold))
            .foregroundColor(HandzColor.textSecondary)

            if let rate = item.targetRate {
                Text(item.completedAt == nil
                     ? "You earn \(money(rate * 0.925))"
                     : "You earned \(money(rate * 0.925))")
                    .font(HandzTypography.callout.weight(.bold))
                    .foregroundColor(HandzColor.accentInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func scheduleText(_ item: MyAssignment) -> String {
        guard let date = item.scheduledAt else { return "Flexible timing" }
        return ScheduleDisplay.text(scheduledAt: date, isFlexible: item.isFlexibleSchedule == 1)
    }

    private func statusChip(_ item: MyAssignment) -> (text: String, icon: String?, kind: HandzChip.Kind) {
        if item.completedAt == nil {
            return item.startedAt == nil
                ? ("Hired", nil, .neutral)
                : ("Working", "hammer", .info)
        }
        switch item.jobStatus {
        case .awaitingPayment, .paymentOverdue: return ("Awaiting payment", "clock", .attention)
        case .paid: return ("Paid", "checkmark", .success)
        case .completed: return ("Complete", "checkmark", .success)
        default: return ("Finished", nil, .neutral)
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}
