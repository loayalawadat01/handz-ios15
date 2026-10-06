import SwiftUI

/// Wraps the app root, showing the job pop-up whenever DispatchPoller has a new job.
/// "I'm Interested" creates a real offer at the job's fixed pay (same as the button on Job Detail).
/// "Not Now" just closes it (nothing is saved on the server).
struct DispatchPopupContainer<Content: View>: View {
    @ObservedObject private var poller = DispatchPoller.shared
    let content: () -> Content
    /// The pop-up is only as tall as what's in it (measured by the pop-up itself).
    @State private var popupHeight: CGFloat = 480

    var body: some View {
        content()
            .sheet(item: Binding(
                get: { poller.pendingJob },
                set: { if $0 == nil { poller.dismiss() } }
            )) { job in
                JobDispatchPopupView(
                    job: job,
                    onInterested: { await applyInterest(job) },
                    onNotNow: { poller.dismiss() },
                    onDone: { poller.dismiss() },
                    onHeightChange: { height in
                        if abs(height - popupHeight) > 1 { popupHeight = height }
                    }
                )
                .presentationDetents([.height(popupHeight)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
            }
    }

    /// Returns nil when the offer was sent, or a message explaining what went wrong.
    @MainActor
    private func applyInterest(_ job: DispatchJob) async -> String? {
        do {
            _ = try await OffersRepository.shared.submitOffer(
                jobId: job.id, amount: job.targetRate ?? 0, message: nil
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
