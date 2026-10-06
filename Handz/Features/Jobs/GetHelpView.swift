import SwiftUI

struct GetHelpView: View {
    @ObservedObject var viewModel: JobDetailViewModel
    let job: Job
    let isOwner: Bool
    let hiredWorkers: [JobWorker]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssue: HelpIssue?
    @State private var details = ""
    @State private var againstWorkerId: String?
    @FocusState private var detailsFocused: Bool

    private var issues: [HelpIssue] { isOwner ? HelpIssue.forCustomer : HelpIssue.forWorker }

    private var alreadyPaid: Bool { job.status == .paid || job.status == .completed }

    private var canSubmit: Bool {
        guard let issue = selectedIssue, !viewModel.actionInProgress else { return false }
        if issue.id == "other" {
            return details.trimmingCharacters(in: .whitespaces).count >= 10
        }
        return true
    }

    var body: some View {
        HandzNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    emergencyBanner
                    issuePicker

                    if let issue = selectedIssue {
                        followUp(for: issue)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, HandzSpacing.sm)
                .padding(.bottom, HandzSpacing.lg)
                .animation(HandzMotion.safe(HandzMotion.standard), value: selectedIssue)
            }
            .handzScrollDismissesKeyboard()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitBar
            }
            .handzScreenBackground()
            .navigationTitle("Something's wrong")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.errorMessage = nil
                againstWorkerId = hiredWorkers.first?.workerId
            }
        }
        .tint(HandzColor.primary)
    }

    // MARK: - 911 banner

    private var emergencyBanner: some View {
        Label("If anyone is in danger, call 911 first.", systemImage: "phone.fill")
            .font(HandzTypography.callout.weight(.semibold))
            .foregroundColor(HandzColor.dangerInk)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.dangerTint)
            )
    }

    // MARK: - What went wrong?

    private var issuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What went wrong?")
                .font(HandzTypography.sectionTitle)
                .foregroundColor(HandzColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(issues) { issue in
                issueRow(issue)
            }
        }
    }

    private func issueRow(_ issue: HelpIssue) -> some View {
        let isSelected = selectedIssue == issue
        return Button {
            HandzHaptics.select()
            withHandzAnimation(HandzMotion.quick) { selectedIssue = issue }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: issue.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? HandzColor.onFill : HandzColor.primaryInk)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isSelected ? HandzColor.primary : HandzColor.primaryTint))
                    .accessibilityHidden(true)
                Text(issue.label)
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

    // MARK: - After choosing an issue

    private func followUp(for issue: HelpIssue) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if isOwner && hiredWorkers.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which worker is this about?")
                        .font(HandzTypography.captionBold)
                        .foregroundColor(HandzColor.textPrimary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(hiredWorkers) { worker in
                                HandzSelectChip(worker.workerName ?? "Worker",
                                                isSelected: againstWorkerId == worker.workerId) {
                                    againstWorkerId = worker.workerId
                                }
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.forward.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HandzColor.primaryInk)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("What happens next")
                        .font(HandzTypography.captionBold)
                        .foregroundColor(HandzColor.primaryInk)
                    Text(alreadyPaid && issue.id != "worker_no_show"
                         ? "This job is already paid, so it won't be paused. Your report is saved and our team will review it."
                         : issue.whatHappensNext)
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.primaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous)
                    .fill(HandzColor.primaryTint)
            )

            HandzFormField(issue.id == "other" ? "Describe the problem" : "Details (optional)",
                           hint: issue.id == "other" ? "At least 10 characters" : nil) {
                HandzGrowingTextField("What happened?", text: $details, lines: 3...6)
                    .focused($detailsFocused)
                    .padding(.vertical, 14)
                    .handzField(isFocused: detailsFocused)
            }
        }
    }

    // MARK: - Submit (stays at the bottom)

    private var submitBar: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(HandzTypography.caption.weight(.semibold))
                    .foregroundColor(HandzColor.dangerInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                submit()
            } label: {
                if viewModel.actionInProgress {
                    HStack(spacing: 8) {
                        ProgressView().tint(HandzColor.onFill)
                        Text("Sending…")
                    }
                } else {
                    Text(selectedIssue == nil ? "Choose what went wrong" : "Send report")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSubmit)
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

    private func submit() {
        guard let issue = selectedIssue, canSubmit else { return }
        detailsFocused = false
        HandzHaptics.press()
        Task {
            let ok = await viewModel.raiseIssue(
                type: issue.id,
                details: details.trimmingCharacters(in: .whitespaces),
                againstUserId: isOwner ? againstWorkerId : nil
            )
            await MainActor.run {
                if ok {
                    HandzHaptics.success()
                    dismiss()
                } else {
                    HandzHaptics.error()
                }
            }
        }
    }
}
