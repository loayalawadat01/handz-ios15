import SwiftUI

struct MyPostedJobsView: View {
    @Environment(\.handzTabBar) private var tabBar

    @State private var jobs: [Job] = []
    @State private var isLoading = true
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var filter: Filter = .active

    private enum Filter: CaseIterable {
        case active, done, cancelled

        var title: String {
            switch self {
            case .active: return "Active"
            case .done: return "Done"
            case .cancelled: return "Cancelled"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterChips
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("My Jobs")
        .onAppear { Task { await load() } }
        .handzRefreshable { await load() }
    }

    // MARK: - Active / Done / Cancelled

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { option in
                HandzSelectChip("\(option.title) \(count(for: option))", isSelected: filter == option) {
                    withHandzAnimation(HandzMotion.quick) { filter = option }
                }
            }
        }
    }

    private func filteredJobs(for option: Filter) -> [Job] {
        switch option {
        case .active:
            return jobs
                .filter { [.open, .offerAccepted, .inProgress, .awaitingPayment, .paymentOverdue, .paid, .disputed].contains($0.status) }
                .sorted { $0.scheduledAt < $1.scheduledAt }
        case .done:
            return jobs
                .filter { $0.status == .completed }
                .sorted { $0.scheduledAt > $1.scheduledAt }
        case .cancelled:
            return jobs
                .filter { [.cancelled, .expired, .paymentFailed].contains($0.status) }
                .sorted { $0.scheduledAt > $1.scheduledAt }
        }
    }

    private func count(for option: Filter) -> Int {
        filteredJobs(for: option).count
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        let shown = filteredJobs(for: filter)
        if isLoading && !hasLoaded {
            HandzLoadingList(count: 3)
        } else if let errorMessage = errorMessage, jobs.isEmpty {
            HandzErrorCard(message: errorMessage) {
                Task { await load() }
            }
        } else if shown.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(shown) { job in
                    NavigationLink {
                        JobDetailView(jobId: job.id)
                    } label: {
                        JobCardView(job: job)
                    }
                    .buttonStyle(HandzPressStyle())
                }
            }
            .animation(HandzMotion.safe(HandzMotion.standard), value: shown.map(\.id))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch filter {
        case .active:
            HandzEmptyState(
                icon: "briefcase",
                title: jobs.isEmpty ? "No jobs yet" : "No active jobs",
                message: "Post a job and workers near you will hear about it right away.",
                actionTitle: tabBar == nil ? nil : "Post a job",
                action: { tabBar?.select(.post) }
            )
        case .done:
            HandzEmptyState(
                icon: "checkmark.circle",
                title: "No finished jobs yet",
                message: "Jobs you've completed and paid for will show up here."
            )
        case .cancelled:
            HandzEmptyState(
                icon: "xmark.circle",
                title: "Nothing cancelled",
                message: "Cancelled and expired jobs will show up here."
            )
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await JobsRepository.shared.myJobs()
            withHandzAnimation { jobs = loaded }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        hasLoaded = true
    }
}

struct MyPostedJobsView_Previews: PreviewProvider {
    static var previews: some View {
        HandzNavigationStack { MyPostedJobsView() }
    }
}
