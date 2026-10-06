import Foundation

/// Polls for a new matching job every few seconds while a worker is
/// logged in and the app is open. In-app only for now -- real push
/// notifications need a paid Apple Developer account (not set up yet).
@MainActor
final class DispatchPoller: ObservableObject {
    static let shared = DispatchPoller()

    @Published var pendingJob: DispatchJob?

    private var timer: Timer?
    private let repository: DispatchRepository

    private init(repository: DispatchRepository = .shared) {
        self.repository = repository
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.poll()
            }
        }
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() async {
        // Don't interrupt if one's already showing, and nothing while offline.
        guard pendingJob == nil else { return }
        guard AuthSession.shared.currentUser?.isAvailable != false else { return }
        guard let job = try? await repository.nextJob() else { return }
        pendingJob = job
    }

    func dismiss() {
        pendingJob = nil
    }
}
