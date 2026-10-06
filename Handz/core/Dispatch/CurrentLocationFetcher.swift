import Foundation
import CoreLocation

/// One-time current location fetch for the geofenced "Start Job" check
/// (spec item 10). Not continuous tracking -- just a single snapshot
/// when the worker taps Start.
final class CurrentLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func fetchOnce() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let status = manager.authorizationStatus
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
