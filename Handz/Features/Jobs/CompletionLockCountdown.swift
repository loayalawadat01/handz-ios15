import SwiftUI
import Combine

/// Live countdown until a job_worker's stated duration has elapsed
/// since they started, after which "Mark Work Completed" unlocks.
final class CompletionLockCountdown: ObservableObject {
    @Published var remainingText: String = ""
    @Published var isUnlocked: Bool

    private var timer: AnyCancellable?
    private let unlockDate: Date

    init(startedAt: Date, durationHours: Double) {
        unlockDate = startedAt.addingTimeInterval(durationHours * 3600)
        isUnlocked = Date() >= unlockDate
        if !isUnlocked {
            tick()
            timer = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in self?.tick() }
        }
    }

    private func tick() {
        let remaining = unlockDate.timeIntervalSinceNow
        if remaining <= 0 {
            isUnlocked = true
            timer?.cancel()
            return
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        remainingText = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
