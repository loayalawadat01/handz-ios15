import Foundation
import CoreLocation

/// While a worker is on the way to a job, sends their position to Handz every
/// so often so the customer can watch them arrive on the map. Keeps going if
/// the worker switches to Maps for directions (the blue location pill shows
/// at the top of the screen). Stops when they start the job, cancel, or the
/// server says sharing has ended.
@MainActor
final class LiveLocationSharer: NSObject, ObservableObject {
    static let shared = LiveLocationSharer()

    /// The assignment being shared, or nil when not sharing.
    @Published private(set) var jobWorkerId: String?

    private let manager = CLLocationManager()
    private var lastSentAt: Date?
    private var isSending = false
    private let minimumInterval: TimeInterval = 15   // at most one update every 15 seconds

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 50                   // meters moved before a new reading
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start(jobWorkerId: String) {
        guard self.jobWorkerId != jobWorkerId else { return }
        self.jobWorkerId = jobWorkerId
        lastSentAt = nil

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Needs "Location updates" under Background Modes (set in Info.plist).
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        jobWorkerId = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func send(_ location: CLLocation) async {
        guard let jobWorkerId, !isSending else { return }
        if let lastSentAt, Date().timeIntervalSince(lastSentAt) < minimumInterval { return }

        isSending = true
        defer { isSending = false }
        do {
            try await JobWorkersRepository.shared.shareLocation(
                id: jobWorkerId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            lastSentAt = Date()
        } catch let APIError.serverError(message) where message.contains("sharing has ended") {
            stop()
        } catch {
            // No signal for a moment: the next reading tries again.
        }
    }
}

extension LiveLocationSharer: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in await self.send(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
