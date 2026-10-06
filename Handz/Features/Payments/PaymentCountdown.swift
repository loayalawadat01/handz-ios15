import SwiftUI
import Combine

/// Drives a live mm:ss countdown to a payment deadline, per spec
/// section 20 (15-minute payment window). Updates once per second.
final class PaymentCountdown: ObservableObject {
    @Published var remainingText: String = "--:--"
    @Published var isOverdue: Bool = false

    private var timer: AnyCancellable?
    private let deadline: Date

    init(deadline: Date) {
        self.deadline = deadline
        tick()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            remainingText = "Overdue"
            isOverdue = true
            timer?.cancel()
            return
        }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        remainingText = String(format: "%d:%02d", minutes, seconds)
    }
}
