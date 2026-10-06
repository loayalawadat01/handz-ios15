import SwiftUI

/// A job the worker said "I'm interested" in, while they wait to hear back.
struct MyOfferCardView: View {
    let offer: MyOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(offer.jobTitle)
                    .font(HandzTypography.headline)
                    .foregroundColor(HandzColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                HandzChip(text: offer.status.displayLabel, kind: statusKind)
            }

            HStack {
                Text("\(offer.status == .accepted ? "You earn" : "You'd earn") \(money(offer.amount * 0.925))")
                    .font(HandzTypography.callout.weight(.bold))
                    .foregroundColor(HandzColor.accentInk)
                Spacer()
                Text("Job: \(offer.jobStatus.displayLabel)")
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var statusKind: HandzChip.Kind {
        switch offer.status {
        case .pending, .standby: return .info
        case .accepted: return .success
        default: return .neutral
        }
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }
}
