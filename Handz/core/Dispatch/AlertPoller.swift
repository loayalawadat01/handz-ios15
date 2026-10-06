import Foundation

/// Checks for urgent notifications every 10 seconds while logged in and
/// the app is open, and holds the one that should pop up next.
@MainActor
final class AlertPoller: ObservableObject {
    static let shared = AlertPoller()

    @Published var pendingAlert: AppNotification?

    private var timer: Timer?

    private init() {}

    func start() {
        stop()
        let newTimer = Timer(timeInterval: 10, repeats: true) { _ in
            Task { @MainActor in
                await AlertPoller.shared.poll()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pendingAlert = nil
    }

    func poll() async {
        // One pop-up at a time; a job offer pop-up takes priority.
        guard pendingAlert == nil, DispatchPoller.shared.pendingJob == nil else { return }
        if let alert = try? await NotificationsRepository.shared.nextPopup() {
            pendingAlert = alert
        }
    }

    func dismiss() {
        pendingAlert = nil
    }
}
