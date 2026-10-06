import SwiftUI

struct EarningsView: View {
    @State private var summary: EarningsSummary?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let summary {
                    hero(summary)

                    HandzTileRow {
                        tile("Last 30 days", money(summary.last30Days), icon: "calendar")
                    } right: {
                        tile("All time", money(summary.allTime), icon: "chart.line.uptrend.xyaxis")
                    }
                    HandzTileRow {
                        tile("Coming to you", money(summary.pending), icon: "clock")
                    } right: {
                        tile("Paid jobs", "\(summary.paidJobs)", icon: "checkmark.circle")
                    }

                    Label("Coming to you is pay for jobs you're booked on or still finishing. It's held on the customer's card and sent to you when the job is done.",
                          systemImage: "info.circle")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)

                    NavigationLink {
                        PaymentHistoryView()
                    } label: {
                        Label("Payments and receipts", systemImage: "doc.text")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if let errorMessage {
                    HandzErrorCard(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    HandzLoadingList(count: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
        }
        .handzScreenBackground()
        .navigationTitle("Earnings")
        .task { await load() }
        .handzRefreshable { await load() }
    }

    private func hero(_ summary: EarningsSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HandzEyebrow("Last 7 days")
            HandzAmountText(summary.last7Days, color: HandzColor.accentInk)
            Text("After the 7.5% Handz fee")
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, HandzSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func tile(_ label: String, _ value: String, icon: String) -> some View {
        HandzTile(icon: icon, title: value, subtitle: label)
    }

    private func money(_ amount: Double) -> String {
        amount.formatted(.currency(code: "USD"))
    }

    private func load() async {
        do {
            let loaded = try await PaymentsRepository.shared.earnings()
            withHandzAnimation {
                summary = loaded
                errorMessage = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
