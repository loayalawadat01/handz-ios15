import SwiftUI

struct JobSummaryView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: JobSummaryViewModel

    init(jobWorkerId: String) {
        _viewModel = StateObject(wrappedValue: JobSummaryViewModel(jobWorkerId: jobWorkerId))
    }

    private var isWorkerViewing: Bool {
        authSession.currentUser?.id == viewModel.summary?.worker.id
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().padding(.top, HandzSpacing.xl)
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(HandzColor.danger).padding()
            } else if let summary = viewModel.summary {
                VStack(alignment: .leading, spacing: HandzSpacing.lg) {
                    header(summary)
                    timingCard(summary)
                    if let payment = summary.payment {
                        paymentCard(payment)
                    }
                }
                .padding(HandzSpacing.lg)
            }
        }
        .navigationTitle("Job Summary")
        .task { await viewModel.load() }
    }

    private func header(_ summary: JobWorkerSummary) -> some View {
        VStack(alignment: .leading, spacing: HandzSpacing.sm) {
            Text(summary.jobTitle)
                .font(HandzTypography.title)
            Text(summary.category.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
            Text(summary.city + (summary.area.map { " · \($0)" } ?? ""))
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
            Text(isWorkerViewing ? "With \(summary.customer.name)" : "With \(summary.worker.name)")
                .font(HandzTypography.body)
        }
    }

    private func timingCard(_ summary: JobWorkerSummary) -> some View {
        VStack(alignment: .leading, spacing: HandzSpacing.sm) {
            Text("Timing").font(HandzTypography.headline)

            row("Scheduled duration", "\(String(format: "%.1f", summary.scheduledDurationHours)) hours")

            if let actual = summary.actualDurationHours {
                row("Actual time worked", "\(String(format: "%.1f", actual)) hours")
            }
            if let started = summary.startedAt {
                row("Started", started.formatted(date: .abbreviated, time: .shortened))
            }
            if let completed = summary.completedAt {
                row("Completed", completed.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func paymentCard(_ payment: Payment) -> some View {
        VStack(alignment: .leading, spacing: HandzSpacing.sm) {
            Text("Payment").font(HandzTypography.headline)

            if isWorkerViewing {
                row("Pay rate", "$\(String(format: "%.2f", payment.workerAmount))")
                row("You received", "$\(String(format: "%.2f", payment.workerKeepsAfterRefunds))", bold: true)
            } else {
                row("Worker rate", "$\(String(format: "%.2f", payment.workerAmount))")
                row("You paid", "$\(String(format: "%.2f", payment.customerPaidAfterRefunds))", bold: true)
            }

            if payment.status == .succeeded {
                NavigationLink {
                    ReceiptView(paymentId: payment.id)
                } label: {
                    Label("View receipt", systemImage: "doc.text")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, HandzSpacing.sm)
            }
        }
        .cardStyle()
    }

    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundColor(HandzColor.textSecondary)
            Spacer()
            Text(value).font(bold ? HandzTypography.headline : HandzTypography.body)
        }
    }
}

struct JobSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            JobSummaryView(jobWorkerId: "preview-id")
                .environmentObject(AuthSession.shared)
        }
    }
}
