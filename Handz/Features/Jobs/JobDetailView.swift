import SwiftUI
import UIKit

struct JobDetailView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: JobDetailViewModel
    @State private var showingETAOptions = false
    @State private var workerToRemove: JobWorker?
    @State private var showingCancelOpenJobConfirm = false
    @State private var showingCloseOffersConfirm = false
    @State private var photoViewer: PhotoViewerState?
    @State private var locationShake = 0
    @State private var chatPartner: ChatPartner?
    @State private var offerToHire: Offer?
    @FocusState private var noteFocused: Bool

    init(jobId: String) {
        _viewModel = StateObject(wrappedValue: JobDetailViewModel(jobId: jobId))
    }

    private var currentUserId: String? { authSession.currentUser?.id }
    private var job: Job? { viewModel.job }
    private var isOwner: Bool { job?.customerId == currentUserId }
    private var myAssignment: JobWorker? { viewModel.workers.first(where: { $0.workerId == currentUserId }) }
    private var myOffer: Offer? { viewModel.offers.first(where: { $0.workerId == currentUserId }) }
    private var hiredWorkers: [JobWorker] { viewModel.workers.filter { $0.status != .cancelled } }

    var body: some View {
        withDialogs(withSheets(withFeedback(baseView)))
            .receiptAutoPresenter(jobId: viewModel.jobId, trigger: receiptCheckKey)
    }

    /// Changes when a worker finishes or the job's status changes, so a new receipt pops up then.
    private var receiptCheckKey: String {
        let finished = viewModel.workers.filter { $0.completedAt != nil }.count
        return "\(viewModel.job?.status.rawValue ?? "loading")-\(finished)"
    }

    // MARK: - Message button (top right)

    /// Someone you can message from this job.
    private struct ChatPartner: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// The customer for a hired worker; the hired workers for the customer.
    /// Messaging opens once someone is hired, so it's empty before that.
    private var chatPartners: [ChatPartner] {
        guard let job else { return [] }
        if isOwner {
            var seen = Set<String>()
            return hiredWorkers.compactMap { worker in
                guard seen.insert(worker.workerId).inserted else { return nil }
                return ChatPartner(id: worker.workerId, name: worker.workerName ?? "Worker")
            }
        }
        if myAssignment != nil {
            return [ChatPartner(id: job.customer.id, name: job.customer.name)]
        }
        return []
    }

    @ViewBuilder
    private var messageButton: some View {
        let partners = chatPartners
        if partners.count == 1, let partner = partners.first {
            Button {
                chatPartner = partner
            } label: {
                Image(systemName: "message.fill")
            }
            .accessibilityLabel("Message \(partner.name)")
        } else if partners.count > 1 {
            Menu {
                ForEach(partners) { partner in
                    Button(partner.name) { chatPartner = partner }
                }
            } label: {
                Image(systemName: "message.fill")
            }
            .accessibilityLabel("Message a worker")
        }
    }

    // MARK: - Screen

    private var isWatchingWorkerArrive: Bool {
        isOwner && hiredWorkers.contains { $0.status == .active && $0.onTheWayAt != nil && $0.startedAt == nil }
    }

    /// The worker's phone shares its position while they're on the way to this job.
    @MainActor
    private func syncLiveLocationSharing() {
        guard let mine = myAssignment else { return }
        let sharer = LiveLocationSharer.shared
        if mine.status == .active && mine.onTheWayAt != nil && mine.startedAt == nil {
            sharer.start(jobWorkerId: mine.id)
        } else if sharer.jobWorkerId == mine.id {
            sharer.stop()
        }
    }

    /// A hold that didn't go through: the customer confirms it, the worker waits.
    @ViewBuilder
    private var paymentAttention: some View {
        let mine = viewModel.paymentsNeedingAction.filter { isOwner || $0.workerId == currentUserId }
        ForEach(mine) { payment in
            ConfirmPaymentCard(
                payment: payment,
                isOwner: isOwner,
                autoStartPaymentId: $viewModel.paymentToConfirm,
                onConfirmed: {
                    Task { @MainActor in
                        viewModel.successMessage = "Payment confirmed."
                        await viewModel.load()
                    }
                }
            )
        }
    }

    private var baseView: some View {
        ScrollView {
            if viewModel.isLoading && job == nil {
                loadingPlaceholderView
            } else if let errorMessage = viewModel.errorMessage, job == nil {
                loadErrorView(errorMessage)
            } else if let job {
                jobContent(job)
            }
        }
        .handzScreenBackground()
        .navigationTitle("Job details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                messageButton
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { chatPartner != nil },
            set: { if !$0 { chatPartner = nil } }
        )) {
            if let partner = chatPartner {
                ChatView(otherUserId: partner.id, otherUserName: partner.name)
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onChange(of: viewModel.workers) { _ in syncLiveLocationSharing() }
        // While a worker is on the way, the customer's map updates every 20 seconds.
        .task(id: isWatchingWorkerArrive) {
            while isWatchingWorkerArrive && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { break }
                await viewModel.load()
            }
        }
        .overlay(alignment: .top) {
            ZStack { successBanner }
                .animation(HandzMotion.safe(HandzMotion.standard), value: viewModel.successMessage)
        }
    }

    // The page is built from three groups, so Xcode can check it quickly
    // (and stays under SwiftUI's limit of 10 pieces per group).
    private func jobContent(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            topGroup(job)
            peopleGroup(job)
            aboutGroup(job)
        }
        .padding(.horizontal, 20)
        .padding(.top, HandzSpacing.sm)
        .padding(.bottom, HandzSpacing.lg)
        .animation(HandzMotion.safe(HandzMotion.standard), value: job.status)
    }

    /// 1. What the job is, and 2. what to do now.
    @ViewBuilder
    private func topGroup(_ job: Job) -> some View {
        header(job)
        if isClosedOut(job) {
            terminalBanner(job)
        }
        paymentAttention
        // Problem reports and their tracker sit at the top, where both people see them first.
        ProblemCasesSection(disputes: viewModel.disputes, currentUserId: currentUserId) {
            Task { await viewModel.load() }
        }
        nextStepCard(job)
        if let errorMessage = viewModel.errorMessage {
            inlineError(errorMessage)
        }
    }

    /// You already reported a problem on this job that Handz hasn't decided yet
    /// (its tracker is at the top of the page, so there's nothing more to report).
    private var hasOpenReportOfMine: Bool {
        viewModel.disputes.contains { $0.raisedBy == currentUserId && $0.isOpen }
    }

    private func somethingWrongSubtitle(_ job: Job) -> String {
        guard isOwner else { return "Tell Handz what happened. We'll review it with both sides." }
        if [.offerAccepted, .inProgress].contains(job.status) {
            return "Tell us before the worker finishes. The pay goes on hold until Handz decides."
        }
        return "Tell Handz what went wrong. We'll review it and can refund you."
    }

    /// 3. People (choose workers, your worker or customer, codes) and 4. progress.
    @ViewBuilder
    private func peopleGroup(_ job: Job) -> some View {
        if isOwner {
            ownerOffersSection(job)
        }
        peopleSection(job)
        if isOwner {
            generateCodeSection(job)
        }
        statusArea(job)
    }

    /// 5. Everything about the job, applying, and 6. reports and the rest.
    @ViewBuilder
    private func aboutGroup(_ job: Job) -> some View {
        details(job)
        if !isOwner {
            workerApplySection(job)
        }
        moreOptionsSection(job)
    }

    // MARK: - Vibrations, banners and announcements

    private func withFeedback<V: View>(_ view: V) -> some View {
        view
            // Success messages show as a banner that hides itself after 3 seconds
            .task(id: viewModel.successMessage) {
                await autoHideSuccessBanner()
            }
            .onChange(of: viewModel.successMessage) { message in
                guard let message = message else { return }
                HandzHaptics.success()
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            // Wrong place when starting: error vibration and the warning shakes
            .onChange(of: viewModel.startFailedAttempts) { attempts in
                guard attempts > 0 else { return }
                HandzHaptics.error()
                if !UIAccessibility.isReduceMotionEnabled {
                    withAnimation(.linear(duration: 0.4)) { locationShake += 1 }
                }
            }
            .onChange(of: viewModel.generatedStartCode) { code in
                if code != nil { HandzHaptics.success() }
            }
            .onChange(of: viewModel.generatedCompletionCode) { code in
                if code != nil { HandzHaptics.success() }
            }
    }

    @MainActor
    private func autoHideSuccessBanner() async {
        guard viewModel.successMessage != nil else { return }
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            return   // a newer message replaced this one; let it stay
        }
        withHandzAnimation(HandzMotion.exit) { viewModel.successMessage = nil }
    }

    @ViewBuilder
    private var successBanner: some View {
        if let message = viewModel.successMessage {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(HandzColor.accent)
                    .accessibilityHidden(true)
                Text(message)
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(HandzColor.surface)
                    .shadow(color: HandzColor.shadow.opacity(0.18), radius: 14, x: 0, y: 6)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .onTapGesture {
                withHandzAnimation(HandzMotion.exit) { viewModel.successMessage = nil }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Loading and errors

    private var loadingPlaceholderView: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(HandzColor.border)
                .frame(height: 200)
            Text("Help moving a two bedroom flat")
                .font(HandzTypography.title)
            Text("Saturday, October 4 at 9:00 AM")
                .font(HandzTypography.callout)
            VStack(alignment: .leading, spacing: 8) {
                Text("Next step")
                Text("Waiting for interested workers to apply")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .padding(20)
        .loadingPlaceholder(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading job")
    }

    private func loadErrorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.dangerInk)
            Button("Try again") { Task { await viewModel.load() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .padding(20)
    }

    private func inlineError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.dangerInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.dangerTint)
            )
            .transition(.opacity)
    }

    // MARK: - Rules shared with the server

    // Mirrors the server rule: within 2h of start, or worker on the way / started.
    private func isLateCancel(for worker: JobWorker) -> Bool {
        guard let job else { return false }
        if worker.startedAt != nil || worker.onTheWayAt != nil { return true }
        if job.isFlexibleSchedule != 0 { return false }
        return job.scheduledAt.timeIntervalSinceNow < 2 * 60 * 60
    }

    private var lateCancelFeeTotal: Double {
        guard let rate = job?.targetRate else { return 0 }
        let lateWorkers = viewModel.workers.filter { $0.status == .active && isLateCancel(for: $0) }
        return Double(lateWorkers.count) * rate * 0.25
    }

    /// What hiring means for the customer's card, before they say yes.
    private func hireConfirmationMessage(for offer: Offer) -> String {
        let name = offer.workerName ?? "the worker"
        // Same math as the server: pay + 7.5% service fee + estimated card processing.
        let withFee = offer.amount * 1.075
        let total = ((withFee + withFee * 0.029 + 0.30) * 100).rounded() / 100
        let holdTime: String = {
            guard let job, job.isFlexibleSchedule == 0,
                  job.scheduledAt.timeIntervalSinceNow > 12 * 60 * 60 else {
                return "right away"
            }
            return "12 hours before the job"
        }()
        return "About \(money(total)) will be held on your card \(holdTime). You're only charged when \(name) finishes the work.\n\nCancelling less than 2 hours before the start costs 25% of their pay."
    }

    private var removeDialogBinding: Binding<Bool> {
        Binding(
            get: { workerToRemove != nil },
            set: { if !$0 { workerToRemove = nil } }
        )
    }

    // MARK: - Header (photos, title, status)

    private func header(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let photos = job.photos, !photos.isEmpty {
                photoCarousel(photos)
            }

            HStack(alignment: .top, spacing: 12) {
                Text(job.title)
                    .font(HandzTypography.title)
                    .foregroundColor(HandzColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                HandzChip(text: job.status.displayLabel, kind: statusKind(job.status))
            }

            keyFacts(job)

            if !isOwner, let requested = job.requestedWorkerId, requested == currentUserId {
                HandzChip(text: "\(job.customer.name) requested you", icon: "star.fill", kind: .success)
            }

            // Once hired, the customer shows under "Your customer" instead.
            if !isOwner && myAssignment == nil {
                postedByRow(job)
            }
        }
    }

    /// When, how long, pay and where, at a glance.
    private func keyFacts(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            factRow("calendar", ScheduleDisplay.text(scheduledAt: job.scheduledAt, isFlexible: job.isFlexibleSchedule != 0)
                    + " · " + hoursText(job.durationHours))
            if let rate = job.targetRate {
                factRow("dollarsign.circle",
                        isOwner ? "\(money(rate)) per worker"
                                : "\(money(rate)) pay · you keep \(money(rate * 0.925))")
            }
            factRow("mappin.and.ellipse", "\(job.city), \(job.state)" + (job.area.map { " · \($0)" } ?? ""))
        }
    }

    private func factRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func postedByRow(_ job: Job) -> some View {
        NavigationLink {
            ProfileView(userId: job.customer.id, userName: job.customer.name)
        } label: {
            HStack(spacing: 12) {
                initialsCircle(job.customer.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Posted by")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                    Text(job.customer.name)
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                    .accessibilityHidden(true)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(HandzPressStyle())
        .accessibilityHint("Opens their profile")
    }

    /// Swipe through the job's photos; tap one to see it full screen.
    private func photoCarousel(_ photos: [String]) -> some View {
        TabView {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, path in
                Button {
                    photoViewer = PhotoViewerState(paths: photos, index: index)
                } label: {
                    Color.clear
                        .frame(height: 220)
                        .overlay(
                            AsyncImage(url: PhotoURL.full(from: path)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                HandzColor.border
                            }
                        )
                        .clipped()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Job photo \(index + 1) of \(photos.count)")
                .accessibilityHint("Opens the photo full screen")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous))
    }

    private func statusKind(_ status: JobStatus) -> HandzChip.Kind {
        switch status {
        case .open, .offerAccepted, .inProgress:
            return .info
        case .awaitingPayment, .paymentOverdue:
            return .attention
        case .paid, .completed:
            return .success
        case .cancelled, .expired, .disputed, .paymentFailed:
            return .danger
        default:
            return .neutral
        }
    }

    // MARK: - Status (tracker or banner)

    @ViewBuilder
    private func statusArea(_ job: Job) -> some View {
        switch job.status {
        case .cancelled, .expired, .disputed, .paymentFailed:
            EmptyView() // shown at the top instead
        default:
            if (isOwner || myAssignment != nil) && progressStep(job) >= 0 {
                HandzJobTimeline(currentStep: progressStep(job),
                                 steps: timelineSteps(job),
                                 note: timelineNote)
                    .cardStyle()
            }
        }
    }

    private func isClosedOut(_ job: Job) -> Bool {
        [.cancelled, .expired, .disputed, .paymentFailed].contains(job.status)
    }

    private func progressStep(_ job: Job) -> Int {
        let worker = isOwner ? hiredWorkers.first : myAssignment
        switch job.status {
        case .offerAccepted:
            return worker?.onTheWayAt != nil ? 1 : 0
        case .inProgress:
            if worker?.completedAt != nil { return 3 }
            if worker?.startedAt != nil { return 2 }
            return worker?.onTheWayAt != nil ? 1 : 0
        case .awaitingPayment, .paymentOverdue:
            return 3
        case .paid:
            return 4
        case .completed:
            return 5
        default:
            return -1
        }
    }

    /// The words under each step of the progress line.
    private func timelineSteps(_ job: Job) -> [JobTimelineStep] {
        let worker = isOwner ? hiredWorkers.first : myAssignment
        let step = progressStep(job)

        let hiredDetail: String? = worker.map { timelineTime($0.createdAt) }

        let onTheWayDetail: String = {
            if step == 1, let eta = worker?.etaMinutes {
                return "Arriving in about \(eta) min"
            }
            if let at = worker?.onTheWayAt {
                return timelineTime(at)
            }
            return isOwner ? "You'll see when they head your way" : "Tap \u{201C}On my way\u{201D} when you leave"
        }()

        let startedDetail: String = {
            if let at = worker?.startedAt {
                return "Started " + timelineTime(at, midSentence: true)
            }
            if job.isFlexibleSchedule != 0 {
                return "Flexible timing"
            }
            return "Starts " + timelineTime(job.scheduledAt, midSentence: true)
        }()

        let finishedDetail: String = {
            if let at = worker?.completedAt {
                return timelineTime(at)
            }
            return "About \(hoursText(job.durationHours)) of work"
        }()

        let paidDetail: String = {
            if step >= 4 {
                return isOwner ? "Charged to your card" : "Sent to your payout account"
            }
            return isOwner ? "Charged automatically when the work is done" : "Paid automatically when you finish"
        }()

        let completeDetail: String = {
            if step >= 5 {
                return "All done. Thanks for using Handz!"
            }
            return isOwner ? "Mark it complete and leave a review" : "The customer closes out the job"
        }()

        return [
            JobTimelineStep(title: isOwner ? "Worker hired" : "You're hired", detail: hiredDetail),
            JobTimelineStep(title: "On the way", detail: onTheWayDetail),
            JobTimelineStep(title: "Work started", detail: startedDetail),
            JobTimelineStep(title: "Work finished", detail: finishedDetail),
            JobTimelineStep(title: "Paid", detail: paidDetail),
            JobTimelineStep(title: "Job complete", detail: completeDetail)
        ]
    }

    /// With more than one worker, the line follows the first one.
    private var timelineNote: String? {
        guard isOwner, hiredWorkers.count > 1 else { return nil }
        let firstName = hiredWorkers.first?.workerName?
            .split(separator: " ").first.map(String.init) ?? "the first worker"
        return "Showing \(firstName)'s progress. Each worker's status is on their card below."
    }

    /// "Today, 2:11 PM", "Yesterday, 9:05 AM" or "Mar 28, 2:11 PM".
    private func timelineTime(_ date: Date, midSentence: Bool = false) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        var day: String?
        if calendar.isDateInToday(date) {
            day = "today"
        } else if calendar.isDateInYesterday(date) {
            day = "yesterday"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        }
        if let day = day {
            return (midSentence ? day : day.capitalized) + ", " + time
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private func terminalBanner(_ job: Job) -> some View {
        let info: (icon: String, title: String, message: String) = {
            switch job.status {
            case .cancelled:
                return ("xmark.octagon", "Job cancelled", "This job was cancelled.")
            case .expired:
                return ("calendar.badge.exclamationmark", "Job expired", "No worker was hired before the job's time passed.")
            case .disputed:
                return ("exclamationmark.bubble", "Under review", "A problem was reported on this job. Our team will review it.")
            default:
                return ("exclamationmark.triangle", "Payment problem", "There was a problem with the payment for this job.")
            }
        }()
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(HandzColor.dangerInk)
                .frame(width: 44, height: 44)
                .background(Circle().fill(HandzColor.surface))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(HandzTypography.sectionTitle)
                    .foregroundColor(HandzColor.textPrimary)
                Text(info.message)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(HandzColor.dangerTint)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Next step card

    private func stepCard<Actions: View>(
        icon: String, color: Color, title: String, message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HandzColor.onFill)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(color))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next step")
                        .font(HandzTypography.captionBold)
                        .foregroundColor(HandzColor.textSecondary)
                        .textCase(.uppercase)
                    Text(title)
                        .font(HandzTypography.sectionTitle)
                        .foregroundColor(HandzColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            actions()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.lg, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .transition(.opacity)
    }

    @ViewBuilder
    private func nextStepCard(_ job: Job) -> some View {
        if isOwner {
            if let until = job.replacementUntil, until > Date() {
                stepCard(
                    icon: "arrow.triangle.2.circlepath", color: HandzColor.warning,
                    title: "Finding a replacement",
                    message: "A worker couldn't make it. Your standby workers have been notified, and the first to confirm is hired automatically."
                ) { EmptyView() }
            } else if job.status == .open && job.isUrgent == 1 {
                stepCard(
                    icon: "bolt.fill", color: HandzColor.danger,
                    title: "Finding a new worker",
                    message: "Your job is marked urgent and nearby workers are being notified. You can also hire anyone below."
                ) { EmptyView() }
            } else {
                customerNextStep(job)
            }
        } else if let mine = myAssignment {
            workerNextStep(job, mine)
        } else if let offer = myOffer {
            workerOfferStatus(offer)
        }
    }

    @ViewBuilder
    private func customerNextStep(_ job: Job) -> some View {
        let first = hiredWorkers.first
        switch job.status {
        case .open:
            if job.offerCount > 0 {
                stepCard(
                    icon: "person.2.fill", color: HandzColor.warning,
                    title: job.workersNeeded > 1 ? "Choose your workers" : "Choose your worker",
                    message: "\(job.offerCount) interested. Tap a name below to see their profile and reviews, then hire."
                ) { EmptyView() }
            } else {
                stepCard(
                    icon: "hourglass", color: HandzColor.textSecondary,
                    title: "Waiting for interested workers",
                    message: "We'll notify you as soon as someone is interested."
                ) { EmptyView() }
            }
        case .offerAccepted:
            if let first, first.onTheWayAt != nil {
                stepCard(
                    icon: "car.fill", color: HandzColor.primary,
                    title: "\(first.workerName ?? "Your worker") is on the way",
                    message: "Arriving in about \(first.etaMinutes ?? 0) minutes. They check in when they reach your address."
                ) { EmptyView() }
            } else {
                stepCard(
                    icon: "calendar", color: HandzColor.primary,
                    title: "You're all set",
                    message: "Your worker's pay is held on your card and only charged when the work is done. They'll tap \"On my way\" when they head over."
                ) { EmptyView() }
            }
        case .inProgress:
            stepCard(
                icon: "hammer.fill", color: HandzColor.accent,
                title: "Work in progress",
                message: "When your worker marks the job done, the held amount is charged automatically. If it finishes early, use \"Allow early completion\" below."
            ) { EmptyView() }
        case .awaitingPayment, .paymentOverdue:
            stepCard(
                icon: "creditcard.fill", color: HandzColor.danger,
                title: job.status == .paymentOverdue ? "Payment overdue" : "Work is done, payment due",
                message: "Review the amount and pay to finish up."
            ) {
                NavigationLink {
                    PaymentsView(jobId: job.id, paymentDeadline: job.paymentDeadlineAt, isOwner: true)
                } label: {
                    Text("Review & Pay")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        case .paid:
            stepCard(
                icon: "checkmark.circle.fill", color: HandzColor.primary,
                title: "Confirm the job is complete",
                message: "Payment went through. Confirm everything is finished to close out the job."
            ) {
                Button("Mark Job Complete") {
                    HandzHaptics.press()
                    Task { await viewModel.markJobComplete() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            }
        case .completed:
            stepCard(
                icon: "star.fill", color: HandzColor.warning,
                title: "Job complete",
                message: "Rate your worker to help others hire with confidence."
            ) {
                NavigationLink {
                    ReviewSubmissionView(jobId: job.id)
                } label: {
                    Text("Leave a Review")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func workerNextStep(_ job: Job, _ mine: JobWorker) -> some View {
        if mine.status == .cancelled {
            stepCard(
                icon: "xmark.circle.fill", color: HandzColor.danger,
                title: "This job was cancelled",
                message: mine.cancelledReason ?? "The customer cancelled this job."
            ) { EmptyView() }
        } else if mine.startedAt == nil {
            stepCard(
                icon: mine.onTheWayAt == nil ? "figure.walk" : "car.fill",
                color: HandzColor.accent,
                title: mine.onTheWayAt == nil ? "Head over when it's time" : "You're on the way",
                message: mine.onTheWayAt == nil
                    ? "Tap \"On My Way\" so the customer knows you're coming, then start the job when you arrive."
                    : "Tap Start Job when you arrive at the job site."
            ) {
                workerStartActions(mine)
            }
        } else if let startedAt = mine.startedAt, mine.completedAt == nil {
            stepCard(
                icon: "hammer.fill", color: HandzColor.accent,
                title: "You're working",
                message: "Mark the job complete when you're finished."
            ) {
                CompletionLockContent(
                    countdown: CompletionLockCountdown(startedAt: startedAt, durationHours: job.durationHours),
                    jobWorker: mine,
                    viewModel: viewModel
                )
            }
        } else {
            workerAfterWork(job)
        }
    }

    private func workerStartActions(_ mine: JobWorker) -> some View {
        VStack(spacing: 10) {
            if viewModel.showingLocationWarning {
                locationWarningBanner
                    .handzShake(locationShake)
            }
            if mine.onTheWayAt == nil {
                Button {
                    showingETAOptions = true
                } label: {
                    Label("On My Way", systemImage: "car")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            }
            Button {
                HandzHaptics.press()
                Task { await viewModel.startMyAssignment(mine) }
            } label: {
                Label("Start Job", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: HandzColor.accent))
            .disabled(viewModel.actionInProgress)

            if viewModel.startFailedAttempts >= 3 {
                Button {
                    viewModel.showingStartCodeEntry = true
                } label: {
                    Label("Enter Start Code", systemImage: "key")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if mine.confirmedAt == nil && mine.onTheWayAt == nil {
                Button("I'm Still Coming") {
                    HandzHaptics.tap()
                    Task { await viewModel.confirmAttendance(mine) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            }

            Button("Can't make it?") {
                viewModel.showingWorkerCancelSheet = true
            }
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.danger)
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private func workerAfterWork(_ job: Job) -> some View {
        switch job.status {
        case .awaitingPayment, .paymentOverdue:
            stepCard(
                icon: "clock.fill", color: HandzColor.warning,
                title: "Waiting for payment",
                message: "The customer has been asked to pay. We'll notify you when it goes through."
            ) { EmptyView() }
        case .paid:
            stepCard(
                icon: "checkmark.circle.fill", color: HandzColor.accent,
                title: "Payment received",
                message: "Waiting for the customer to close out the job."
            ) { EmptyView() }
        case .completed:
            stepCard(
                icon: "star.fill", color: HandzColor.warning,
                title: "Job complete",
                message: "Rate the customer and check your job summary below."
            ) {
                NavigationLink {
                    ReviewSubmissionView(jobId: job.id)
                } label: {
                    Text("Leave a Review")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        default:
            stepCard(
                icon: "checkmark.circle.fill", color: HandzColor.accent,
                title: "You've been paid",
                message: "Your pay for this job is on its way to your payout account. Nice work."
            ) { EmptyView() }
        }
    }

    @ViewBuilder
    private func workerOfferStatus(_ offer: Offer) -> some View {
        switch offer.status {
        case .pending:
            stepCard(
                icon: "hourglass", color: HandzColor.warning,
                title: "You're on the applicant list",
                message: "The customer is choosing. We'll notify you if you're selected."
            ) {
                Button("Withdraw Application", role: .destructive) {
                    Task { await viewModel.withdrawOffer(offer) }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            }
        case .rejected:
            stepCard(
                icon: "xmark", color: HandzColor.textSecondary,
                title: "Not selected this time",
                message: "Keep an eye out for new jobs. There's more work coming."
            ) { EmptyView() }
        case .withdrawn:
            stepCard(
                icon: "arrow.uturn.backward", color: HandzColor.textSecondary,
                title: "You withdrew your application",
                message: "You can browse other open jobs."
            ) { EmptyView() }
        case .standby:
            if let until = job?.replacementUntil, until > Date() {
                stepCard(
                    icon: "bolt.fill", color: HandzColor.accent,
                    title: "A spot just opened!",
                    message: "First to confirm gets it. Tap below to take this job."
                ) {
                    Button {
                        HandzHaptics.press()
                        Task { await viewModel.claimSpot(offer) }
                    } label: {
                        Label("Take This Job", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: HandzColor.accent))
                    .disabled(viewModel.actionInProgress)
                }
            } else {
                stepCard(
                    icon: "hourglass", color: HandzColor.warning,
                    title: "You're on standby",
                    message: "This job is filled, but if a spot opens up, you'll get the first chance."
                ) { EmptyView() }
            }
        case .accepted:
            EmptyView()
        }
    }

    private var locationWarningBanner: some View {
        let remaining = max(0, 3 - viewModel.startFailedAttempts)
        return VStack(alignment: .leading, spacing: 6) {
            Label("You're not at the job location", systemImage: "location.slash")
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.dangerInk)
            Text(remaining > 0
                 ? "Move closer and try again. \(remaining) attempt\(remaining == 1 ? "" : "s") left before you can ask the customer for a start code."
                 : "You can now ask the customer for a start code instead.")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                .fill(HandzColor.dangerTint)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - People

    @ViewBuilder
    private func peopleSection(_ job: Job) -> some View {
        if isOwner {
            if !hiredWorkers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle(hiredWorkers.count == 1 ? "Your worker" : "Your workers")
                    ForEach(hiredWorkers) { worker in
                        hiredWorkerCard(worker, job: job)
                    }
                }
            }
        } else if let mine = myAssignment, mine.status != .cancelled {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Your customer")
                personCard(
                    userId: job.customer.id,
                    name: job.customer.name,
                    photoPath: nil,
                    phone: job.customerPhone,
                    status: nil
                ) {
                    EmptyView()
                }
            }
        }
    }

    private func hiredWorkerCard(_ worker: JobWorker, job: Job) -> some View {
        let name = worker.workerName ?? "Worker"
        return personCard(
            userId: worker.workerId,
            name: name,
            photoPath: worker.workerPhotoUrl,
            phone: worker.workerPhone,
            status: workerStatus(worker),
            verified: worker.workerIdentityVerified == true
        ) {
            hiredWorkerActions(worker, name: name, job: job)
        }
    }

    @ViewBuilder
    private func hiredWorkerActions(_ worker: JobWorker, name: String, job: Job) -> some View {
        let canRemove = worker.status == .active && worker.startedAt == nil
        let rebook = canRebook(worker, job: job)
        if canRemove || rebook {
            HStack(spacing: 16) {
                if rebook {
                    NavigationLink {
                        PostJobView(prefill: job, requestedWorkerId: worker.workerId, requestedWorkerName: name)
                    } label: {
                        Label("Hire \(name) again", systemImage: "arrow.clockwise")
                            .font(HandzTypography.callout.weight(.semibold))
                            .foregroundColor(HandzColor.primary)
                            .frame(minHeight: 44)
                    }
                }
                Spacer(minLength: 0)
                if canRemove {
                    Button("Remove") {
                        workerToRemove = worker
                    }
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.danger)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Remove \(name)")
                }
            }
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(HandzColor.border).frame(height: 1)
            }
        }
    }

    private func canRebook(_ worker: JobWorker, job: Job) -> Bool {
        worker.completedAt != nil && (job.status == .paid || job.status == .completed)
    }

    private func personCard<Footer: View>(
        userId: String, name: String, photoPath: String?, phone: String?,
        status: (text: String, kind: HandzChip.Kind)?,
        verified: Bool = false,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                NavigationLink {
                    ProfileView(userId: userId, userName: name)
                } label: {
                    HStack(spacing: 12) {
                        AvatarView(photoPath: photoPath, size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(name)
                                    .font(HandzTypography.headline)
                                    .foregroundColor(HandzColor.textPrimary)
                                if verified {
                                    VerifiedBadge(showsText: false)
                                }
                            }
                            if let status {
                                HandzChip(text: status.text, kind: status.kind)
                            }
                        }
                    }
                }
                .buttonStyle(HandzPressStyle())
                .accessibilityHint("Opens their profile")

                Spacer(minLength: 8)

                // Messaging is the button at the top right of the page.

                if let phone, let url = URL(string: "tel://\(phone)") {
                    Link(destination: url) {
                        circleIcon("phone.fill", fill: HandzColor.accentTint, tint: HandzColor.accentInk)
                    }
                    .accessibilityLabel("Call \(name)")
                }
            }
            footer()
        }
        .cardStyle(padding: 14)
    }

    private func workerStatus(_ worker: JobWorker) -> (text: String, kind: HandzChip.Kind) {
        if worker.status == .completed || worker.completedAt != nil { return ("Finished", .success) }
        if worker.startedAt != nil { return ("Working now", .info) }
        if worker.onTheWayAt != nil { return ("On the way · about \(worker.etaMinutes ?? 0) min", .info) }
        if worker.confirmedAt != nil { return ("Confirmed they're coming", .success) }
        return ("Hired", .neutral)
    }

    // MARK: - Details

    private func details(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("About this job")
            if !job.description.isEmpty {
                Text(job.description)
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            JobLocationMap(
                job: job,
                travelingWorkers: isOwner ? hiredWorkers.filter { $0.liveLocation != nil } : [],
                showsDirectionsButton: myAssignment?.status == .active
            )
            if let address = job.address {
                detailRow("house", address)
            }
            if let instructions = job.arrivalInstructions, !instructions.isEmpty {
                detailRow("key", instructions)
            }
            if let toolsText = ToolsOption.label(job.tools) {
                detailRow("wrench.and.screwdriver", toolsText)
            }
            detailRow("person.2", "\(job.acceptedWorkersCount) of \(job.workersNeeded) workers hired")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func detailRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HandzColor.textSecondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(HandzTypography.callout)
                .foregroundColor(HandzColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Customer: interested workers

    @ViewBuilder
    private func ownerOffersSection(_ job: Job) -> some View {
        if job.status == .open || job.status == .offerAccepted {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Interested workers (\(viewModel.offers.filter { $0.status == .pending }.count))")

                if viewModel.offers.isEmpty {
                    Text("No one yet. We'll let you know when someone's interested.")
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else {
                    ForEach(viewModel.offers) { offer in
                        offerRow(offer, job: job)
                    }
                }

                if job.status == .offerAccepted && job.closedToNewOffers == 0 {
                    Button("Stop accepting new workers") {
                        showingCloseOffersConfirm = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(viewModel.actionInProgress)
                    .confirmationDialog(
                        "Stop accepting new workers?",
                        isPresented: $showingCloseOffersConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Stop accepting workers", role: .destructive) {
                            Task { await viewModel.closeToOffers() }
                        }
                        Button("Keep accepting", role: .cancel) {}
                    } message: {
                        Text(closeOffersMessage(job))
                    }
                }
            }
        }
    }

    private func closeOffersMessage(_ job: Job) -> String {
        let hired = hiredWorkers.count
        let people = hired == 1 ? "1 worker" : "\(hired) workers"
        return "You'll keep the \(people) you hired out of the \(job.workersNeeded) you asked for. No one else can join this job, and this can't be undone."
    }

    private func offerRow(_ offer: Offer, job: Job) -> some View {
        let name = offer.workerName ?? "Worker"
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink {
                    ProfileView(userId: offer.workerId, userName: name)
                } label: {
                    HStack(spacing: 12) {
                        if offer.workerPhotoUrl != nil {
                            AvatarView(photoPath: offer.workerPhotoUrl, size: 44)
                        } else {
                            initialsCircle(name, size: 44)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name)
                                .font(HandzTypography.headline)
                                .foregroundColor(HandzColor.textPrimary)
                            if offer.workerIdentityVerified == true {
                                VerifiedBadge()
                            }
                            Text("See profile and reviews")
                                .font(HandzTypography.caption.weight(.semibold))
                                .foregroundColor(HandzColor.primary)
                        }
                    }
                }
                .buttonStyle(HandzPressStyle())

                Spacer(minLength: 8)
                HandzChip(text: offer.status.displayLabel, kind: offerKind(offer.status))
            }

            if let reliability = offer.workerReliability {
                Label(reliability.shortLabel, systemImage: "checkmark.shield")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.accentInk)
            }

            if let years = offer.workerYearsExperience, years > 0 {
                Label(years == 1 ? "1 year of experience" : "\(years) years of experience", systemImage: "briefcase")
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)
            }

            if let bio = offer.workerBio, !bio.isEmpty {
                Text(bio)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = offer.message, !message.isEmpty {
                Text("“\(message)”")
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
            }

            if offer.status == .pending && job.closedToNewOffers == 0 {
                HStack(spacing: 12) {
                    Button("Decline") {
                        Task { await viewModel.rejectOffer(offer) }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        HandzHaptics.press()
                        offerToHire = offer
                    } label: {
                        Label("Hire", systemImage: "checkmark")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: HandzColor.accent))
                }
                .disabled(viewModel.actionInProgress)
            }
        }
        .cardStyle(padding: 14)
    }

    private func offerKind(_ status: OfferStatus) -> HandzChip.Kind {
        switch status {
        case .pending, .standby: return .info
        case .accepted: return .success
        default: return .neutral
        }
    }

    // MARK: - Worker: apply

    @ViewBuilder
    private func workerApplySection(_ job: Job) -> some View {
        if myOffer == nil && myAssignment == nil && job.status == .open && job.closedToNewOffers == 0 {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Want this job?")
                TextField("Add a note for the customer (optional)", text: $viewModel.offerMessage, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($noteFocused)
                    .padding(.vertical, 14)
                    .handzField(isFocused: noteFocused)
                Button {
                    HandzHaptics.press()
                    noteFocused = false
                    Task { await viewModel.submitOffer(atRate: job.targetRate ?? 0) }
                } label: {
                    Label("I'm Interested", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle(color: HandzColor.accent))
                .disabled(viewModel.actionInProgress)
            }
            .cardStyle()
        }
    }

    // MARK: - Customer: start / completion codes

    @ViewBuilder
    private func generateCodeSection(_ job: Job) -> some View {
        if let waitingWorker = viewModel.workers.first(where: { $0.status == .active && $0.startedAt == nil }) {
            codeCard(
                title: "Start code",
                code: viewModel.generatedStartCode,
                explanation: "Give this code to \(waitingWorker.workerName ?? "your worker") only if the app can't confirm they've arrived.",
                buttonTitle: "Get start code",
                icon: "key"
            ) {
                Task { await viewModel.generateStartCodeForCustomer(waitingWorker) }
            }
        }

        if let workingWorker = viewModel.workers.first(where: { $0.status == .active && $0.startedAt != nil && $0.completedAt == nil }) {
            codeCard(
                title: "Early finish code",
                code: viewModel.generatedCompletionCode,
                explanation: "Give this code to \(workingWorker.workerName ?? "your worker") so they can mark the job complete before the booked time ends.",
                buttonTitle: "Allow early completion",
                icon: "checkmark.seal"
            ) {
                Task { await viewModel.generateCompletionCodeForCustomer(workingWorker) }
            }
        }
    }

    private func codeCard(title: String, code: String?, explanation: String,
                          buttonTitle: String, icon: String,
                          action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)

            if let code {
                Text(spacedCode(code))
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(HandzColor.primaryInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                            .fill(HandzColor.primaryTint)
                    )
                    .textSelection(.enabled)
                    .accessibilityLabel("Code: \(code.map { String($0) }.joined(separator: " "))")
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            Text(explanation)
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)

            if code == nil {
                Button(action: action) {
                    Label(buttonTitle, systemImage: icon)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .animation(HandzMotion.safe(HandzMotion.bouncy), value: code)
    }

    /// "123456" -> "123 456" so it's easy to read out loud
    private func spacedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return String(code.prefix(3)) + " " + String(code.suffix(3))
    }

    // MARK: - More options

    private func moreOptionsSection(_ job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Only people on the job have options here.
            if isOwner || myAssignment != nil {
                sectionTitle("More")
            }
            paymentsLinkSection(job)
            summaryLinkSection(job)
            disputeLinkSection(job)
            if isOwner {
                cancelButton(job)
            }
        }
    }

    private func optionRow(_ icon: String, _ title: String, tint: Color = HandzColor.textPrimary,
                           showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
                .font(HandzTypography.headline)
                .foregroundColor(tint)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 28)
        .cardStyle(padding: 14)
    }

    @ViewBuilder
    private func paymentsLinkSection(_ job: Job) -> some View {
        let relevant: [JobStatus] = [.offerAccepted, .inProgress, .awaitingPayment, .paid, .paymentOverdue, .completed]
        if relevant.contains(job.status) && (isOwner || myAssignment != nil) {
            NavigationLink {
                PaymentsView(jobId: job.id, paymentDeadline: job.paymentDeadlineAt, isOwner: isOwner)
            } label: {
                optionRow("creditcard", "Payment")
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    @ViewBuilder
    private func summaryLinkSection(_ job: Job) -> some View {
        let relevantWorker: JobWorker? = isOwner
            ? viewModel.workers.first(where: { $0.status == .completed })
            : myAssignment

        if job.status == .completed, let worker = relevantWorker {
            NavigationLink {
                JobSummaryView(jobWorkerId: worker.id)
            } label: {
                optionRow("doc.text", "Job summary")
            }
            .buttonStyle(HandzPressStyle())
        }
    }

    @ViewBuilder
    private func disputeLinkSection(_ job: Job) -> some View {
        let eligible: [JobStatus] = [.offerAccepted, .inProgress, .awaitingPayment, .paid, .paymentOverdue, .completed]
        if eligible.contains(job.status) && (isOwner || myAssignment != nil) && !hasOpenReportOfMine {
            SomethingWrongButton(subtitle: somethingWrongSubtitle(job)) {
                viewModel.showingDisputeSheet = true
            }
        }
    }

    @ViewBuilder
    private func cancelButton(_ job: Job) -> some View {
        if job.status == .open {
            Button {
                showingCancelOpenJobConfirm = true
            } label: {
                optionRow("xmark.circle", "Cancel job", tint: HandzColor.danger, showsChevron: false)
            }
            .buttonStyle(HandzPressStyle())
            .disabled(viewModel.actionInProgress)
        } else if [.offerAccepted, .inProgress].contains(job.status) {
            Button {
                viewModel.showingCancelReasonSheet = true
            } label: {
                optionRow("xmark.circle", "Cancel job", tint: HandzColor.danger, showsChevron: false)
            }
            .buttonStyle(HandzPressStyle())
            .disabled(viewModel.actionInProgress)
        }
    }

    // MARK: - Small shared pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(HandzTypography.sectionTitle)
            .foregroundColor(HandzColor.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func circleIcon(_ systemName: String, fill: Color, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 44, height: 44)
            .background(Circle().fill(fill))
    }

    private func initialsCircle(_ name: String, size: CGFloat) -> some View {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        let initials = letters.isEmpty ? "?" : String(letters).uppercased()
        return Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundColor(HandzColor.primaryInk)
            .frame(width: size, height: size)
            .background(Circle().fill(HandzColor.primaryTint))
            .accessibilityHidden(true)
    }

    private func hoursText(_ hours: Double) -> String {
        "\(String(format: "%g", hours)) hour\(hours == 1 ? "" : "s")"
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }

    // MARK: - Sheets

    private func withSheets<V: View>(_ view: V) -> some View {
        view
            .sheet(isPresented: $viewModel.showingCancelReasonSheet) { cancelReasonSheet }
            .sheet(isPresented: $viewModel.showingDisputeSheet) {
                if let job {
                    GetHelpView(viewModel: viewModel, job: job, isOwner: isOwner, hiredWorkers: hiredWorkers)
                }
            }
            .sheet(isPresented: $viewModel.showingStartCodeEntry) { startCodeEntrySheet }
            .sheet(isPresented: $viewModel.showingCompletionCodeEntry) { completionCodeEntrySheet }
            .sheet(isPresented: $viewModel.showingWorkerCancelSheet) { workerCancelSheet }
            .fullScreenCover(item: $photoViewer) { state in
                PhotoViewer(paths: state.paths, startIndex: state.index)
            }
    }

    private func withDialogs<V: View>(_ view: V) -> some View {
        view
            .alert(
                "Hire \(offerToHire?.workerName ?? "this worker")?",
                isPresented: Binding(get: { offerToHire != nil }, set: { if !$0 { offerToHire = nil } }),
                presenting: offerToHire
            ) { offer in
                Button("Hire") {
                    Task { await viewModel.acceptOffer(offer) }
                }
                Button("Not yet", role: .cancel) {}
            } message: { offer in
                Text(hireConfirmationMessage(for: offer))
            }
            .confirmationDialog("Remove this worker?", isPresented: removeDialogBinding, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let worker = workerToRemove {
                        Task { await viewModel.removeWorker(worker) }
                    }
                }
                Button("Keep", role: .cancel) {}
            } message: {
                if let worker = workerToRemove, isLateCancel(for: worker), let rate = job?.targetRate {
                    Text("It's close to the start, so you pay a late-cancellation fee of \(money(rate * 0.25)) (25% of their pay): 20% goes to the worker and 5% to Handz.")
                } else {
                    Text("Their payment hold is released, and you can pick someone else from your applicants.")
                }
            }
            .confirmationDialog("How long until you arrive?", isPresented: $showingETAOptions, titleVisibility: .visible) {
                ForEach([10, 20, 30, 45, 60], id: \.self) { minutes in
                    Button("About \(minutes) minutes") {
                        if let mine = myAssignment {
                            HandzHaptics.tap()
                            Task { await viewModel.markOnTheWay(mine, etaMinutes: minutes) }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Cancel this job?", isPresented: $showingCancelOpenJobConfirm, titleVisibility: .visible) {
                Button("Cancel job", role: .destructive) {
                    Task { await viewModel.cancelJob() }
                }
                Button("Keep job", role: .cancel) {}
            } message: {
                Text("No one is hired yet, so there's no fee. Interested workers will see it's no longer available.")
            }
    }

    private var workerCancelSheet: some View {
        let isLate: Bool = {
            guard let job, job.isFlexibleSchedule == 0 else { return false }
            return job.scheduledAt.timeIntervalSinceNow < 24 * 60 * 60
        }()
        return NavigationStack {
            Form {
                Section {
                    if isLate {
                        Label("This job starts within 24 hours, so cancelling now counts against your reliability score.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(HandzColor.danger)
                    } else {
                        Label("Cancelling more than 24 hours ahead doesn't affect your reliability.",
                              systemImage: "checkmark.circle")
                            .foregroundColor(HandzColor.accent)
                    }
                    Text("We'll immediately offer the job to the customer's standby workers.")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }
                Section("Why can't you make it?") {
                    TextField("Let the customer know", text: $viewModel.workerCancelReason, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Button("Cancel My Spot", role: .destructive) {
                        if let mine = myAssignment {
                            Task { await viewModel.cancelMyAssignment(mine) }
                        }
                    }
                    .disabled(viewModel.workerCancelReason.trimmingCharacters(in: .whitespaces).isEmpty
                              || viewModel.actionInProgress)
                }
            }
            .navigationTitle("Can't Make It")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { viewModel.showingWorkerCancelSheet = false }
                }
            }
        }
        .tint(HandzColor.primary)
    }

    private var startCodeEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Enter the code from the customer") {
                    TextField("6-digit code", text: $viewModel.startCodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                }
                Section {
                    Button("Start Job") {
                        if let mine = myAssignment {
                            HandzHaptics.press()
                            Task { await viewModel.startWithCode(mine) }
                        }
                    }
                    .disabled(viewModel.startCodeInput.isEmpty || viewModel.actionInProgress)
                }
            }
            .navigationTitle("Start Code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") { viewModel.showingStartCodeEntry = false }
                }
            }
        }
        .tint(HandzColor.primary)
    }

    private var completionCodeEntrySheet: some View {
        NavigationStack {
            Form {
                Section("Enter the completion code from the customer") {
                    TextField("6-digit code", text: $viewModel.completionCodeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                }
                Section {
                    Button("Mark Completed") {
                        if let mine = myAssignment {
                            HandzHaptics.press()
                            Task { await viewModel.completeWithCode(mine) }
                        }
                    }
                    .disabled(viewModel.completionCodeInput.isEmpty || viewModel.actionInProgress)
                }
            }
            .navigationTitle("Completion Code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") { viewModel.showingCompletionCodeEntry = false }
                }
            }
        }
        .tint(HandzColor.primary)
    }

    private var cancelReasonSheet: some View {
        NavigationStack {
            Form {
                if lateCancelFeeTotal > 0 {
                    Section {
                        Label("It's close to the start, so you pay a late-cancellation fee of \(money(lateCancelFeeTotal)) (25% of pay): 20% goes to your worker(s) and 5% to Handz. The rest of the hold is released.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(HandzColor.danger)
                    }
                } else {
                    Section {
                        Label("No fee: the payment hold is released in full.", systemImage: "checkmark.circle")
                            .foregroundColor(HandzColor.accent)
                    }
                }
                Section("Why are you cancelling?") {
                    TextField("Reason", text: $viewModel.cancelReason, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button("Confirm Cancellation", role: .destructive) {
                        Task { await viewModel.cancelJobWithReason() }
                    }
                    .disabled(viewModel.cancelReason.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.actionInProgress)
                }
            }
            .navigationTitle("Cancel Job")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") { viewModel.showingCancelReasonSheet = false }
                }
            }
        }
        .tint(HandzColor.primary)
    }
}

// MARK: - Progress line (Hired → On the way → Work started → Work finished → Paid → Complete)
// A vertical line like a delivery tracker: finished steps get a small teal dot
// and a solid line, the current step gets a big ring that gently pulses,
// and steps still to come are grey with a dashed line.

struct JobTimelineStep {
    let title: String
    let detail: String?
}

private struct HandzJobTimeline: View {
    let currentStep: Int
    let steps: [JobTimelineStep]
    let note: String?

    @State private var shownStep: Int = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum StepState {
        case done, current, finished, upcoming
    }

    init(currentStep: Int, steps: [JobTimelineStep], note: String?) {
        self.currentStep = currentStep
        self.steps = steps
        self.note = note
    }

    private var isComplete: Bool { currentStep >= steps.count - 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let note = note {
                Text(note)
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    row(index)
                }
            }
        }
        .onAppear {
            if reduceMotion {
                shownStep = currentStep
            } else {
                withAnimation(HandzMotion.standard.delay(0.15)) { shownStep = currentStep }
            }
        }
        .onChange(of: currentStep) { step in
            withHandzAnimation(HandzMotion.bouncy) { shownStep = step }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Progress")
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if isComplete {
                HandzChip(text: "Complete", icon: "checkmark", kind: .success)
            } else {
                HandzChip(text: "Step \(currentStep + 1) of \(steps.count)", kind: .info)
            }
        }
    }

    // MARK: One step

    private func row(_ index: Int) -> some View {
        let state = stepState(index, at: shownStep)
        let isLast = index == steps.count - 1
        let step = steps[index]

        return HStack(alignment: .top, spacing: 14) {
            dot(state)
                .frame(width: 24, height: 24)
                .animation(stepAnimation(index), value: shownStep)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(titleFont(state))
                    .foregroundColor(titleColor(state))
                if let detail = step.detail {
                    Text(detail)
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : 22)

            Spacer(minLength: 0)
        }
        .background(alignment: .topLeading) {
            if !isLast {
                connector(index)
                    .padding(.top, 12)
                    .padding(.bottom, -12)
                    .frame(width: 24)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(index))
    }

    @ViewBuilder
    private func dot(_ state: StepState) -> some View {
        switch state {
        case .done:
            Circle()
                .fill(HandzColor.primary)
                .frame(width: 12, height: 12)
                .transition(.scale.combined(with: .opacity))
        case .current:
            CurrentStepDot()
                .transition(.scale.combined(with: .opacity))
        case .finished:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(HandzColor.onFill)
                .frame(width: 24, height: 24)
                .background(Circle().fill(HandzColor.accent))
                .transition(.scale.combined(with: .opacity))
        case .upcoming:
            Circle()
                .fill(HandzColor.textFaint.opacity(0.55))
                .frame(width: 10, height: 10)
                .transition(.opacity)
        }
    }

    /// Grey dashes underneath; the teal line draws down over them as steps finish.
    private func connector(_ index: Int) -> some View {
        let filled = index < shownStep
        return ZStack {
            TimelineLine()
                .stroke(HandzColor.textFaint.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
            TimelineLine()
                .trim(from: 0, to: filled ? 1 : 0)
                .stroke(HandzColor.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .animation(stepAnimation(index), value: shownStep)
        }
        .accessibilityHidden(true)
    }

    // MARK: Helpers

    private func stepState(_ index: Int, at step: Int) -> StepState {
        if index < step { return .done }
        if index == step {
            return index == steps.count - 1 ? .finished : .current
        }
        return .upcoming
    }

    /// Each step fills a moment after the one above it.
    private func stepAnimation(_ index: Int) -> Animation? {
        if reduceMotion { return nil }
        return HandzMotion.standard.delay(Double(index) * 0.08)
    }

    private func titleFont(_ state: StepState) -> Font {
        switch state {
        case .current:  return HandzTypography.sectionTitle
        case .upcoming: return HandzTypography.callout
        default:        return HandzTypography.callout.weight(.semibold)
        }
    }

    private func titleColor(_ state: StepState) -> Color {
        state == .upcoming ? HandzColor.textSecondary : HandzColor.textPrimary
    }

    private func accessibilityText(_ index: Int) -> String {
        let prefix: String
        switch stepState(index, at: currentStep) {
        case .done, .finished: prefix = "Done"
        case .current:         prefix = "Now"
        case .upcoming:        prefix = "Coming up"
        }
        let detail = steps[index].detail.map { ". \($0)" } ?? ""
        return "\(prefix): \(steps[index].title)\(detail)"
    }
}

/// White center with a thick teal ring and a soft pulse around it.
private struct CurrentStepDot: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {}

    var body: some View {
        ZStack {
            Circle()
                .fill(HandzColor.primary.opacity(0.25))
                .frame(width: 24, height: 24)
                .scaleEffect(pulse ? 1.6 : 1)
                .opacity(pulse ? 0 : 1)
                .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
            Circle()
                .strokeBorder(HandzColor.primary, lineWidth: 5)
                .background(Circle().fill(HandzColor.surface))
                .frame(width: 22, height: 22)
        }
        .onAppear {
            guard !reduceMotion else { return }
            DispatchQueue.main.async { pulse = true }
        }
    }
}

/// A straight up-and-down line through the middle of its space.
private struct TimelineLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Full-screen photo viewer

private struct PhotoViewerState: Identifiable {
    let id = UUID()
    let paths: [String]
    let index: Int
}

/// Black full-screen view: swipe between photos, pinch or double-tap to zoom, X to close.
private struct PhotoViewer: View {
    let paths: [String]
    @State private var selection: Int
    @State private var isZoomed = false
    @Environment(\.dismiss) private var dismiss

    init(paths: [String], startIndex: Int) {
        self.paths = paths
        _selection = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(paths.indices, id: \.self) { index in
                    ZoomablePhoto(path: paths[index], isZoomed: $isZoomed)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: paths.count > 1 && !isZoomed ? .always : .never))
            .onChange(of: selection) { _ in isZoomed = false }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .accessibilityLabel("Close photo")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .statusBarHidden(true)
    }
}

private struct ZoomablePhoto: View {
    let path: String
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(path: String, isZoomed: Binding<Bool>) {
        self.path = path
        self._isZoomed = isZoomed
    }

    var body: some View {
        AsyncImage(url: PhotoURL.full(from: path)) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            ProgressView().tint(.white)
        }
        .scaleEffect(scale)
        .offset(offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(lastScale * value, 1), 4)
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale <= 1.01 {
                        reset()
                    } else {
                        isZoomed = true
                    }
                }
        )
        // Moving a zoomed photo; turned off when not zoomed so swiping between photos still works
        .simultaneousGesture(panGesture, including: scale > 1 ? .all : .none)
        .onTapGesture(count: 2) {
            withHandzAnimation(HandzMotion.standard) {
                if scale > 1 {
                    reset()
                } else {
                    scale = 2.5
                    lastScale = 2.5
                    isZoomed = true
                }
            }
        }
        .onChange(of: isZoomed) { zoomed in
            if !zoomed && scale > 1 {
                withHandzAnimation(HandzMotion.standard) { reset() }
            }
        }
        .accessibilityLabel("Job photo")
        .accessibilityAddTraits(.isImage)
        .accessibilityHint("Double-tap with two fingers to zoom")
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
        isZoomed = false
    }
}

struct JobDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            JobDetailView(jobId: "preview-id")
                .environmentObject(AuthSession.shared)
        }
    }
}
