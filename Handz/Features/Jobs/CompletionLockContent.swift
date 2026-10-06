import SwiftUI

struct CompletionLockContent: View {
    @StateObject var countdown: CompletionLockCountdown
    let jobWorker: JobWorker
    @ObservedObject var viewModel: JobDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: HandzSpacing.sm) {
            if countdown.isUnlocked {
                Button("Mark Work Completed") {
                    Task { await viewModel.completeMyAssignment(jobWorker) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.actionInProgress)
            } else {
                HStack(spacing: HandzSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(HandzColor.textSecondary)
                    Text("Available in \(countdown.remainingText)")
                        .font(HandzTypography.body)
                        .foregroundColor(HandzColor.textSecondary)
                }
                .padding(HandzSpacing.md)
                .background(HandzColor.surface)
                .cornerRadius(HandzRadius.md)

                Button("Enter Completion Code") {
                    viewModel.showingCompletionCodeEntry = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}
