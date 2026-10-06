//
//  ReceiptView.swift
//  Handz
//
//  The receipt screen. The first time a receipt opens it "prints": the paper
//  slides out of a slot with light ticks you can feel, the checkmark draws
//  itself, the amount counts up, the lines come in one by one and the stamp
//  pops on. Refunds strike out the old total and count down to the new one.
//  After the first time (or with Reduce Motion on) it just shows.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ReceiptView: View {
    let paymentId: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var receipt: Receipt?
    @State private var errorMessage: String?
    @State private var printed = false
    @State private var reveal = ReceiptReveal()
    @State private var actionsShown = false
    @State private var pdfURL: URL?
    @State private var lifted = false
    @State private var exportDocument: ReceiptPDFDocument?
    @State private var exporting = false

    init(paymentId: String) {
        self.paymentId = paymentId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let receipt {
                    printer(receipt)
                    actions(receipt)
                } else if let errorMessage {
                    HandzErrorCard(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    ProgressView()
                        .padding(.top, 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .handzScreenBackground()
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fileExporter(isPresented: $exporting,
                      document: exportDocument,
                      contentType: .pdf,
                      defaultFilename: receipt.map { ReceiptPDF.fileName($0) } ?? "Handz receipt") { _ in }
    }

    // MARK: - The printer slot and the paper coming out of it

    private func printer(_ receipt: Receipt) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(HandzColor.ink)
                .frame(height: 14)
                .overlay(
                    Capsule()
                        .fill(HandzColor.onInk.opacity(0.35))
                        .frame(height: 3)
                        .padding(.horizontal, 40)
                )
                .zIndex(1)
                .accessibilityHidden(true)

            ZStack(alignment: .top) {
                if printed {
                    ReceiptPaper(receipt: receipt, reveal: reveal)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 18)   // room for the paper's shadow inside the slot
                        .transition(.move(edge: .top))
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .clipped()
            .padding(.top, -7)   // the paper starts right under the middle of the slot
        }
        .scaleEffect(lifted ? 1.02 : 1)
        .offset(y: lifted ? -6 : 0)
    }

    // MARK: - Share, save, get help

    private func actions(_ receipt: Receipt) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .simultaneousGesture(TapGesture().onEnded { lift() })
                }
                Button {
                    savePDF()
                } label: {
                    Label("Save PDF", systemImage: "arrow.down.doc")
                }
                .buttonStyle(SecondaryButtonStyle(compact: true))
                .disabled(pdfURL == nil)
            }

            NavigationLink {
                JobDetailView(jobId: receipt.job.id)
            } label: {
                Label("Something wrong? Report a problem", systemImage: "exclamationmark.bubble")
                    .font(HandzTypography.callout.weight(.semibold))
                    .foregroundColor(HandzColor.textSecondary)
                    .frame(minHeight: 44)
            }

            Text("Payment ID \(receipt.id)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(HandzColor.textFaint)
                .textSelection(.enabled)
        }
        .opacity(actionsShown ? 1 : 0)
        .offset(y: actionsShown ? 0 : 12)
    }

    // MARK: - Loading and the printing animation

    @MainActor
    private func load() async {
        guard receipt == nil else { return }
        errorMessage = nil
        do {
            let loaded = try await PaymentsRepository.shared.receipt(paymentId: paymentId)
            receipt = loaded
            pdfURL = ReceiptPDF.make(loaded)
            await play(loaded)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func play(_ receipt: Receipt) async {
        let firstTime = !ReceiptSeenStore.shared.isSeen(receipt.id)
        ReceiptSeenStore.shared.markSeen(receipt.id)

        guard firstTime && !reduceMotion else {
            // Already seen (or Reduce Motion): show it all, with just a soft fade.
            withAnimation(HandzMotion.fade) {
                printed = true
                reveal = .all(receipt)
                actionsShown = true
            }
            return
        }

        // 1. The paper prints out of the slot.
        printerTicks()
        withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.9)) { printed = true }
        await pause(0.55)

        // 2. Checkmark draws, dotted lines draw, the amount counts up.
        withAnimation(.easeOut(duration: 0.5)) {
            reveal.check = true
            reveal.divider = true
        }
        withAnimation(.easeOut(duration: 0.9)) {
            reveal.amount = receipt.wasRefunded ? receipt.total.amount : receipt.final.amount
        }

        // 3. The lines come in one by one.
        for index in 0..<ReceiptPaper.rowCount(receipt) {
            await pause(0.07)
            withAnimation(HandzMotion.standard) { reveal.rows = index + 1 }
        }

        // 4. A refund: strike out the old total, slide in the refund, count down.
        if receipt.wasRefunded {
            await pause(0.35)
            withAnimation(.easeInOut(duration: 0.35)) { reveal.strike = true }
            await pause(0.25)
            withAnimation(HandzMotion.standard) { reveal.refund = true }
            HandzHaptics.tap()
            await pause(0.15)
            withAnimation(.easeOut(duration: 0.8)) { reveal.amount = receipt.final.amount }
            await pause(0.5)
        } else {
            await pause(0.15)
        }

        // 5. The stamp pops on.
        withAnimation(HandzMotion.bouncy) { reveal.stamp = true }
        if receipt.status == .succeeded {
            HandzHaptics.success()
        } else {
            HandzHaptics.tap()
        }

        await pause(0.25)
        withAnimation(HandzMotion.standard) { actionsShown = true }
    }

    /// Light ticks while the paper prints.
    private func printerTicks() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        for index in 0..<7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.09) {
                generator.impactOccurred(intensity: 0.45)
            }
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// The receipt lifts a little as the share sheet opens.
    private func lift() {
        withAnimation(HandzMotion.safe(HandzMotion.bouncy)) { lifted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(HandzMotion.safe(HandzMotion.standard)) { lifted = false }
        }
    }

    private func savePDF() {
        guard let pdfURL, let data = try? Data(contentsOf: pdfURL) else { return }
        exportDocument = ReceiptPDFDocument(data: data)
        exporting = true
    }
}

// MARK: - The receipt in its own sheet (with a Done button)

struct ReceiptSheet: View {
    let paymentId: String
    @Environment(\.dismiss) private var dismiss

    init(paymentId: String) {
        self.paymentId = paymentId
    }

    var body: some View {
        NavigationStack {
            ReceiptView(paymentId: paymentId)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - Which receipts have been shown (so the full animation plays once)

final class ReceiptSeenStore {
    static let shared = ReceiptSeenStore()
    private let key = "handz.seenReceipts"
    private let limit = 300

    private init() {}

    func isSeen(_ paymentId: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: key) ?? []).contains(paymentId)
    }

    func markSeen(_ paymentId: String) {
        var seen = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !seen.contains(paymentId) else { return }
        seen.append(paymentId)
        if seen.count > limit { seen.removeFirst(seen.count - limit) }
        UserDefaults.standard.set(seen, forKey: key)
    }
}

// MARK: - Pop the receipt up on its own right after a job is charged

private struct ReceiptTarget: Identifiable {
    let id: String
}

/// Shows a new receipt (charged in the last 3 days, not seen yet) for this job.
/// Checks when the screen opens and every time `trigger` changes (for example
/// when the job's status changes after the worker finishes).
struct ReceiptAutoPresenter<Trigger: Equatable>: ViewModifier {
    let jobId: String
    let trigger: Trigger
    @State private var target: ReceiptTarget?
    /// Receipts already popped up on this screen, so a failed or swiped-away
    /// one never keeps reopening.
    @State private var presentedIds: Set<String> = []

    func body(content: Content) -> some View {
        content
            .task(id: trigger) { await check() }
            .sheet(item: $target, onDismiss: {
                // If more than one worker was paid, show the next receipt.
                Task { await check() }
            }) { target in
                ReceiptSheet(paymentId: target.id)
            }
    }

    @MainActor
    private func check() async {
        guard target == nil,
              let response = try? await PaymentsRepository.shared.paymentsForJob(jobId: jobId) else { return }
        let cutoff = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        let fresh = response.payments.first { payment in
            payment.status == .succeeded
                && (payment.capturedAt ?? .distantPast) > cutoff
                && !ReceiptSeenStore.shared.isSeen(payment.id)
                && !presentedIds.contains(payment.id)
        }
        guard let fresh else { return }
        // Give any other sheet on the screen (like the finish-code entry) time to close first.
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard target == nil else { return }
        presentedIds.insert(fresh.id)
        target = ReceiptTarget(id: fresh.id)
    }
}

extension View {
    func receiptAutoPresenter<Trigger: Equatable>(jobId: String, trigger: Trigger) -> some View {
        modifier(ReceiptAutoPresenter(jobId: jobId, trigger: trigger))
    }
}
