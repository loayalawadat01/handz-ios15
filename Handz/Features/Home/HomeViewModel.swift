import Foundation
import SwiftUI

enum HireWorkMode: String {
    case hire
    case work
}

/// One row in the Home screen's "Needs your attention" section.
struct AttentionItem: Identifiable {
    enum Destination {
        case jobDetail(jobId: String)
        case payment(jobId: String, deadline: Date?)
    }

    /// Sets the row's icon colors: clay = needs you, teal = info, green = good news, red = problem.
    enum Tone {
        case attention, info, success, danger, neutral
    }

    let id: String
    let icon: String
    let tone: Tone
    let title: String
    let subtitle: String
    let destination: Destination
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var myJobs: [Job] = []
    @Published var myOffers: [MyOffer] = []
    @Published var myAssignments: [MyAssignment] = []
    @Published var earnings: EarningsSummary?
    /// Your payments (as a worker or as a customer, matching your role), newest first.
    @Published var payments: [Payment] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var hasLoadedOnce: Bool = false
    @Published var errorMessage: String?
    @Published var mode: HireWorkMode = .hire

    private(set) var role: String = "customer"

    private let jobsRepository: JobsRepository
    private let offersRepository: OffersRepository
    private let jobWorkersRepository: JobWorkersRepository

    init(
        jobsRepository: JobsRepository = .shared,
        offersRepository: OffersRepository = .shared,
        jobWorkersRepository: JobWorkersRepository = .shared
    ) {
        self.jobsRepository = jobsRepository
        self.offersRepository = offersRepository
        self.jobWorkersRepository = jobWorkersRepository
    }

    func setInitialMode(forRole role: String) {
        self.role = role
        mode = role == "worker" ? .work : .hire
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            if role == "worker" {
                async let offers = offersRepository.myOffers()
                async let assignments = jobWorkersRepository.myAssignments()
                let loadedOffers = try await offers
                let loadedAssignments = try await assignments
                withHandzAnimation {
                    myOffers = loadedOffers
                    myAssignments = loadedAssignments
                }
                // Earnings are a bonus on Home: if they fail, the rest still shows
                if let summary = try? await PaymentsRepository.shared.earnings() {
                    withHandzAnimation { earnings = summary }
                }
            } else {
                let loadedJobs = try await jobsRepository.myJobs()
                withHandzAnimation { myJobs = loadedJobs }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // Payments and receipts are a bonus on Home too.
        if let mine = try? await PaymentsRepository.shared.myPayments() {
            let list = role == "worker" ? mine.asWorker : mine.asCustomer
            withHandzAnimation {
                payments = list.sorted { ($0.capturedAt ?? $0.createdAt) > ($1.capturedAt ?? $1.createdAt) }
            }
        }

        if let notifications = try? await NotificationsRepository.shared.list() {
            unreadCount = notifications.unreadCount
        }

        isLoading = false
        hasLoadedOnce = true
    }

    // MARK: - Payments and receipts

    var recentPayments: [Payment] {
        Array(payments.prefix(3))
    }

    /// A payment charged in the last 7 days whose receipt you haven't opened yet.
    var newReceipt: Payment? {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return payments.first { payment in
            payment.status == .succeeded
                && (payment.capturedAt ?? .distantPast) > cutoff
                && !ReceiptSeenStore.shared.isSeen(payment.id)
        }
    }

    // MARK: - Hire side

    var activeJobsCount: Int {
        myJobs.filter { ![.completed, .cancelled].contains($0.status) }.count
    }

    /// Jobs that are booked or still looking for workers, soonest first.
    var upcomingJobs: [Job] {
        myJobs
            .filter { [.open, .offerAccepted].contains($0.status) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    // MARK: - Worker side

    var activeOffersCount: Int {
        myOffers.filter { $0.status == .pending }.count
    }

    var pendingOffers: [MyOffer] {
        myOffers.filter { $0.status == .pending }
    }

    /// The next booked job that hasn't started (including ones starting soon).
    var nextAssignment: MyAssignment? {
        myAssignments
            .filter { $0.status == .active && $0.startedAt == nil }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
            .first
    }

    /// Booked jobs that haven't started yet (the ones starting very soon show under "Needs your attention").
    var upcomingAssignments: [MyAssignment] {
        myAssignments
            .filter { $0.status == .active && $0.startedAt == nil && !isStartingSoon($0) }
            .sorted { ($0.scheduledAt ?? .distantFuture) < ($1.scheduledAt ?? .distantFuture) }
    }

    private func isStartingSoon(_ assignment: MyAssignment) -> Bool {
        guard let date = assignment.scheduledAt, (assignment.isFlexibleSchedule ?? 0) == 0 else { return false }
        return date.timeIntervalSinceNow < 2 * 3600
    }

    // MARK: - Needs your attention

    /// Everything the user should act on right now, most urgent first.
    var attentionItems: [AttentionItem] {
        role == "worker" ? workerAttentionItems : customerAttentionItems
    }

    private var customerAttentionItems: [AttentionItem] {
        var items: [AttentionItem] = []

        for job in myJobs where job.status == .disputed {
            items.append(AttentionItem(
                id: "problem-\(job.id)",
                icon: "pause.circle",
                tone: .attention,
                title: "Problem being reviewed",
                subtitle: "\(job.title) · Pay is on hold until Handz decides",
                destination: .jobDetail(jobId: job.id)
            ))
        }

        for job in myJobs where job.status == .awaitingPayment || job.status == .paymentOverdue {
            items.append(AttentionItem(
                id: "pay-\(job.id)",
                icon: "creditcard",
                tone: .danger,
                title: job.status == .paymentOverdue ? "Payment overdue" : "Payment due",
                subtitle: job.title,
                destination: .payment(jobId: job.id, deadline: job.paymentDeadlineAt)
            ))
        }

        for job in myJobs where job.status == .open && job.offerCount > 0 {
            let count = job.offerCount
            items.append(AttentionItem(
                id: "applicants-\(job.id)",
                icon: "person.2",
                tone: .attention,
                title: "\(count) worker\(count == 1 ? " is" : "s are") interested",
                subtitle: "\(job.title) · Pick who to hire",
                destination: .jobDetail(jobId: job.id)
            ))
        }

        for job in myJobs where job.status == .paid {
            items.append(AttentionItem(
                id: "complete-\(job.id)",
                icon: "checkmark.circle",
                tone: .success,
                title: "Mark job complete",
                subtitle: "\(job.title) · Then rate your worker",
                destination: .jobDetail(jobId: job.id)
            ))
        }

        for job in myJobs where job.status == .inProgress {
            items.append(AttentionItem(
                id: "working-\(job.id)",
                icon: "hammer",
                tone: .info,
                title: "Work in progress",
                subtitle: "\(job.title) · Tap to follow along",
                destination: .jobDetail(jobId: job.id)
            ))
        }

        return items
    }

    private var workerAttentionItems: [AttentionItem] {
        var items: [AttentionItem] = []

        // The customer pressed "Something's wrong": most urgent, so it's first.
        for a in myAssignments where a.jobStatus == .disputed && a.status != .cancelled {
            items.append(AttentionItem(
                id: "paused-\(a.id)",
                icon: "pause.circle",
                tone: .danger,
                title: "Pay on hold",
                subtitle: "\(a.jobTitle) · A problem was reported. Open the job for details",
                destination: .jobDetail(jobId: a.jobId)
            ))
        }

        for a in myAssignments where a.status == .active && a.startedAt == nil && isStartingSoon(a) {
            items.append(AttentionItem(
                id: "start-\(a.id)",
                icon: "figure.walk",
                tone: .attention,
                title: "Starting soon",
                subtitle: "\(a.jobTitle) · Check in when you arrive",
                destination: .jobDetail(jobId: a.jobId)
            ))
        }

        for a in myAssignments where a.status == .active && a.startedAt != nil && a.completedAt == nil && a.jobStatus != .disputed {
            items.append(AttentionItem(
                id: "progress-\(a.id)",
                icon: "hammer",
                tone: .info,
                title: "Working now",
                subtitle: "\(a.jobTitle) · Finish when you're done",
                destination: .jobDetail(jobId: a.jobId)
            ))
        }

        for a in myAssignments where a.completedAt != nil && [.awaitingPayment, .paymentOverdue].contains(a.jobStatus) {
            items.append(AttentionItem(
                id: "waiting-\(a.id)",
                icon: "clock",
                tone: .neutral,
                title: "Waiting for payment",
                subtitle: a.jobTitle,
                destination: .jobDetail(jobId: a.jobId)
            ))
        }

        for a in myAssignments where a.jobStatus == .completed && a.hasReviewed == 0 {
            items.append(AttentionItem(
                id: "review-\(a.id)",
                icon: "star",
                tone: .success,
                title: "Leave a review",
                subtitle: a.jobTitle,
                destination: .jobDetail(jobId: a.jobId)
            ))
        }

        return items
    }
}
