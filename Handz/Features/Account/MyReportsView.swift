import SwiftUI

struct MyReportsView: View {
    @State private var reports: [Dispute] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundColor(HandzColor.danger)
            } else if reports.isEmpty {
                Text("You haven't reported any problems.")
                    .foregroundColor(HandzColor.textSecondary)
            } else {
                ForEach(reports) { report in
                    NavigationLink {
                        JobDetailView(jobId: report.jobId)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(report.issueLabel).font(HandzTypography.headline)
                                Spacer()
                                Text(report.status.displayLabel)
                                    .font(HandzTypography.captionBold)
                                    .foregroundColor(HandzColor.warning)
                            }
                            Text(report.jobTitle ?? "Job")
                                .font(HandzTypography.body)
                                .foregroundColor(HandzColor.textSecondary)
                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(HandzTypography.caption)
                                .foregroundColor(HandzColor.textSecondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("My Reports")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            reports = try await DisputesRepository.shared.myDisputes()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
