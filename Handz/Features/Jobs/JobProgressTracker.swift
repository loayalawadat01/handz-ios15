import SwiftUI

/// The step tracker at the top of the job page.
/// currentStep: -1 = nothing yet, 0...5 = index into labels.
struct JobProgressTracker: View {
    let currentStep: Int
    private let labels = ["Hired", "On the way", "Working", "Finished", "Paid", "Complete"]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(labels.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? HandzColor.primary : HandzColor.border)
                            .frame(width: 22, height: 22)
                        if index < currentStep || (index == currentStep && index == labels.count - 1) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentStep {
                            Circle().fill(Color.white).frame(width: 8, height: 8)
                        }
                    }
                    Text(labels[index])
                        .font(.system(size: 10, weight: index == currentStep ? .semibold : .regular))
                        .foregroundColor(index <= currentStep ? HandzColor.textPrimary : HandzColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, HandzSpacing.sm)
    }
}
