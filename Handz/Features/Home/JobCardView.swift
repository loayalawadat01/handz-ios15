import SwiftUI

/// Reusable job card, used on Find Work (workers) and My Jobs (customers).
/// Workers see what they'd earn, distance and a save button.
/// Customers see the job's status and how hiring is going.
struct JobCardView: View {
    let job: Job
    var onToggleSave: (() -> Void)? = nil
    var forWorker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: JobCategoryStyle.icon(for: job.category))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HandzColor.primaryInk)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(HandzColor.primaryTint))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(job.title)
                        .font(HandzTypography.headline)
                        .foregroundColor(HandzColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(JobCategoryStyle.name(for: job.category))
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }

                Spacer(minLength: 8)

                if let onToggleSave = onToggleSave {
                    SaveJobButton(isSaved: job.isSaved, action: onToggleSave)
                }
            }

            chipsRow

            VStack(alignment: .leading, spacing: 6) {
                Label(ScheduleDisplay.text(scheduledAt: job.scheduledAt, isFlexible: job.isFlexibleSchedule != 0),
                      systemImage: "calendar")
                Label(locationText, systemImage: "mappin.and.ellipse")
                Label("\(job.workersNeeded) worker\(job.workersNeeded == 1 ? "" : "s") · \(String(format: "%g", job.durationHours)) hrs",
                      systemImage: "person.2")
            }
            .font(HandzTypography.caption.weight(.semibold))
            .foregroundColor(HandzColor.textSecondary)

            if let rate = job.targetRate {
                payLine(rate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Chips

    private var isUrgent: Bool { job.isUrgent == 1 }
    private var isFlexible: Bool { job.isFlexibleSchedule != 0 }

    @ViewBuilder
    private var chipsRow: some View {
        if forWorker {
            if isUrgent || isFlexible {
                HStack(spacing: 6) {
                    if isUrgent {
                        HandzChip(text: "Urgent", icon: "bolt.fill", kind: .attention)
                    }
                    if isFlexible {
                        HandzChip(text: "Flexible time", kind: .info)
                    }
                }
            }
        } else {
            HStack(spacing: 6) {
                HandzChip(text: job.status.displayLabel, kind: statusKind)
                hiringChip
            }
        }
    }

    private var isWaitingForHires: Bool { job.status == .open && job.acceptedWorkersCount == 0 }
    private var isHiring: Bool { job.status == .open || job.status == .offerAccepted }
    private var isFullyHired: Bool { job.acceptedWorkersCount >= job.workersNeeded }
    private var hiredText: String { "\(job.acceptedWorkersCount) of \(job.workersNeeded) hired" }

    @ViewBuilder
    private var hiringChip: some View {
        if isWaitingForHires {
            if job.offerCount > 0 {
                HandzChip(text: "\(job.offerCount) interested", icon: "person.2", kind: .attention)
            }
        } else if isHiring {
            if isFullyHired {
                HandzChip(text: hiredText, icon: "checkmark", kind: .success)
            } else {
                HandzChip(text: hiredText, kind: .info)
            }
        }
    }

    private var statusKind: HandzChip.Kind {
        switch job.status {
        case .open, .offerAccepted, .inProgress: return .info
        case .awaitingPayment, .paymentOverdue: return .attention
        case .paid, .completed: return .success
        case .cancelled, .expired, .disputed, .paymentFailed: return .danger
        default: return .neutral
        }
    }

    // MARK: - Pay

    @ViewBuilder
    private func payLine(_ rate: Double) -> some View {
        if forWorker {
            HStack {
                Text("You earn \(money(rate * 0.925))")
                    .font(HandzTypography.callout.weight(.bold))
                    .foregroundColor(HandzColor.accentInk)
                Spacer()
                Text("Job pays \(money(rate))")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        } else {
            Text("\(money(rate)) per worker")
                .font(HandzTypography.callout.weight(.semibold))
                .foregroundColor(HandzColor.textPrimary)
        }
    }

    private var locationText: String {
        if let area = job.area, !area.isEmpty {
            return "\(area), \(job.city)"
        }
        return "\(job.city), \(job.state)"
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}

/// Bookmark button that fills in teal when the job is saved.
private struct SaveJobButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HandzHaptics.select()
            action()
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isSaved ? HandzColor.primaryInk : HandzColor.textSecondary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(isSaved ? HandzColor.primaryTint : HandzColor.background))
        }
        .buttonStyle(HandzPressStyle())
        .animation(HandzMotion.safe(HandzMotion.bouncy), value: isSaved)
        .accessibilityLabel(isSaved ? "Remove from saved jobs" : "Save job")
    }
}

/// Icons and readable names for job categories (Apple's icons, no emoji).
enum JobCategoryStyle {
    static func icon(for category: String) -> String {
        let c = category.lowercased()
        if c.contains("clean") { return "sparkles" }
        if c.hasPrefix("car_") || c.contains("tire_") { return "car" }
        if c.contains("bartend") || c.contains("catering") { return "fork.knife" }
        if c.contains("moving") || c.contains("hauling") || c.contains("junk") { return "shippingbox" }
        if c.contains("paint") { return "paintbrush" }
        if c.contains("garden") || c.contains("lawn") || c.contains("yard") || c.contains("landscap") { return "leaf" }
        if c.contains("delivery") || c.contains("courier") || c.contains("driv") { return "car" }
        if c.contains("tech") || c.contains("it_") || c.contains("computer") { return "desktopcomputer" }
        if c.contains("pet") || c.contains("dog") { return "pawprint" }
        if c.contains("electric") { return "bolt" }
        if c.contains("plumb") { return "drop" }
        if c.contains("assembl") || c.contains("carpent") || c.contains("handy") { return "hammer" }
        if c.contains("tutor") || c.contains("teach") || c.contains("instruct") { return "book" }
        return "wrench.and.screwdriver"
    }

    /// "moving_help" -> "Moving help"
    static func name(for category: String) -> String {
        let words = category.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
