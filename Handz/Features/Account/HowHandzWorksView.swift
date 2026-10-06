import SwiftUI

/// Account → How Handz works. A short guide for each side: workers and
/// people hiring. Opens on your own side; you can peek at the other one.
struct HowHandzWorksView: View {
    @EnvironmentObject private var authSession: AuthSession
    @State private var showingWorkerGuide: Bool

    init(startWithWorkerGuide: Bool = false) {
        _showingWorkerGuide = State(initialValue: startWithWorkerGuide)
    }

    private struct Step {
        let icon: String
        let title: String
        let text: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Guide", selection: $showingWorkerGuide) {
                    Text("Hiring").tag(false)
                    Text("Working").tag(true)
                }
                .pickerStyle(.segmented)

                Text(showingWorkerGuide
                     ? "Find work near you, get paid automatically."
                     : "Get trusted help for a few hours, pay only when the work is done.")
                    .font(HandzTypography.body)
                    .foregroundColor(HandzColor.textSecondary)

                ForEach(Array((showingWorkerGuide ? workerSteps : hireSteps).enumerated()), id: \.offset) { index, step in
                    stepCard(number: index + 1, step: step)
                }

                tipsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, HandzSpacing.sm)
            .padding(.bottom, HandzSpacing.lg)
            .animation(HandzMotion.safe(HandzMotion.standard), value: showingWorkerGuide)
        }
        .handzScreenBackground()
        .navigationTitle("How Handz works")
        .onAppear {
            if authSession.currentUser?.role == "worker" { showingWorkerGuide = true }
        }
    }

    // MARK: - Hiring

    private var hireSteps: [Step] {
        [
            Step(icon: "creditcard", title: "Add a card",
                 text: "Account → Payment method. Stripe keeps your card safe; Handz never sees the number."),
            Step(icon: "plus.circle", title: "Post a job",
                 text: "Say what you need, where, when (up to 7 days ahead), how long it takes and what you'll pay each worker. You'll see a typical price for that kind of work."),
            Step(icon: "person.2", title: "Pick who to hire",
                 text: "Workers near you apply at your price. Check their photo, reviews, reliability and the ID verified badge, then tap Hire."),
            Step(icon: "lock.shield", title: "Money is held, not charged",
                 text: "12 hours before the job, the pay is held on your card. If your bank asks you to approve it, you'll get a notification. Tap Confirm payment on the job."),
            Step(icon: "car", title: "Watch them arrive",
                 text: "When your worker taps On My Way, you see them on the map with an arrival time. Message or call them from the job."),
            Step(icon: "number", title: "Codes, if you need them",
                 text: "If their phone can't confirm they've arrived, give them a start code from the job page. If the work finishes early, give them a completion code."),
            Step(icon: "checkmark.circle", title: "Charged when it's done",
                 text: "When the worker finishes, your card is charged the pay plus a 7.5% service fee and card processing. Then leave a review."),
        ]
    }

    // MARK: - Working

    private var workerSteps: [Step] {
        [
            Step(icon: "banknote", title: "Set up payouts",
                 text: "Account → Payouts. Stripe sends your earnings to your bank. You need this before you can apply."),
            Step(icon: "checkmark.seal", title: "Verify your ID",
                 text: "Account → ID verification. A photo of your ID and a selfie. Customers trust workers with the ID verified badge."),
            Step(icon: "dot.radiowaves.left.and.right", title: "Go online",
                 text: "Turn on You're online at the top of Home to get pop-ups for new jobs as they're posted. Go offline any time; every job is still in Find Work."),
            Step(icon: "hand.thumbsup", title: "Apply",
                 text: "Tap I'm Interested on a pop-up or in Find Work. Everyone applies at the customer's price; you keep it minus a 7.5% Handz fee."),
            Step(icon: "bell.badge", title: "Confirm you're coming",
                 text: "When you're hired, we'll ask \u{201C}Still coming?\u{201D} 2 hours before. If you don't confirm by 1 hour before, the job goes to someone else."),
            Step(icon: "car", title: "Tap On My Way",
                 text: "The customer sees you on the map while you drive, even if you switch to Maps for directions."),
            Step(icon: "play.circle", title: "Start at the address",
                 text: "Tap Start Job when you're there. Your phone checks you're at the job. If it can't, ask the customer for a start code."),
            Step(icon: "dollarsign.circle", title: "Finish and get paid",
                 text: "Tap Mark Work Completed after the job's time is up, or earlier with the customer's completion code. Your pay goes to your bank automatically."),
        ]
    }

    // MARK: - Good to know

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Good to know")
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.textPrimary)
            ForEach(showingWorkerGuide ? workerTips : hireTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(HandzColor.primary)
                        .accessibilityHidden(true)
                    Text(tip)
                        .font(HandzTypography.callout)
                        .foregroundColor(HandzColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var hireTips: [String] {
        [
            "Cancelling is free until 2 hours before the start. Later than that, or once the worker is on the way, you pay 25% of their pay: 20% to the worker and 5% to Handz.",
            "Something went wrong? Open the job and tap Get help. The Handz team reviews it and decides on any refund.",
            "Phone numbers are shared only between you and your hired worker, until 24 hours after the job.",
        ]
    }

    private var workerTips: [String] {
        [
            "Cancelling more than 24 hours ahead is free. Closer than that, it counts against your reliability. 3 late cancellations or no-shows in 30 days pause applying for 7 days.",
            "If the customer cancels late, you still get 20% of the pay.",
            "You only see the exact address once you're hired.",
            "A problem on a job? Open it and tap Get help. Don't start work if the payment isn't confirmed yet; the app will tell you.",
        ]
    }

    private func stepCard(number: Int, step: Step) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: step.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(HandzColor.primaryInk)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(HandzColor.primaryTint))
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(HandzColor.onFill)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(HandzColor.primary))
                    .offset(x: 4, y: 4)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                Text(step.text)
                    .font(HandzTypography.callout)
                    .foregroundColor(HandzColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(step.title). \(step.text)")
    }
}
