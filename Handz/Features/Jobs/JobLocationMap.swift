import SwiftUI
import MapKit

/// The map on a job page.
/// - Before hiring, workers see a shaded circle around the rough area (about 1 km).
/// - The customer and hired workers see the exact spot, with an Open in Maps button.
/// - While a worker is on the way, the customer also sees them moving, with an arrival estimate.
struct JobLocationMap: View {
    let job: Job
    /// Workers on the way whose position the customer can see.
    var travelingWorkers: [JobWorker] = []
    var showsDirectionsButton = false

    @State private var region: MKCoordinateRegion
    @State private var etaMinutes: [String: Int] = [:]

    init(job: Job, travelingWorkers: [JobWorker] = [], showsDirectionsButton: Bool = false) {
        self.job = job
        self.travelingWorkers = travelingWorkers
        self.showsDirectionsButton = showsDirectionsButton
        _region = State(initialValue: Self.region(for: job, workers: travelingWorkers))
    }

    private var isApproximate: Bool { job.locationIsApproximate == true }

    private var jobCoordinate: CLLocationCoordinate2D? {
        guard let lat = job.latitude, let lon = job.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        if let jobCoordinate {
            VStack(alignment: .leading, spacing: 10) {
                Map(coordinateRegion: $region, interactionModes: [.pan, .zoom], annotationItems: pins(jobCoordinate)) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        pinView(pin)
                    }
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: HandzRadius.md, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)

                if isApproximate {
                    Text("Approximate area. You'll see the exact address once you're hired.")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }

                ForEach(travelingWorkers) { worker in
                    if let live = worker.liveLocation {
                        travelLine(worker, live)
                    }
                }

                if showsDirectionsButton && !isApproximate {
                    Button {
                        openInMaps(jobCoordinate)
                    } label: {
                        Label("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .onChange(of: travelingWorkers) { workers in
                withAnimation(HandzMotion.safe(HandzMotion.standard)) {
                    region = Self.region(for: job, workers: workers)
                }
            }
            .task(id: travelingWorkers.compactMap(\.liveLocation)) {
                await updateArrivalEstimates(to: jobCoordinate)
            }
        }
    }

    // MARK: - Pins

    private struct Pin: Identifiable {
        enum Kind { case job, approximateArea, worker(name: String, photo: String?) }
        let id: String
        let coordinate: CLLocationCoordinate2D
        let kind: Kind
    }

    private func pins(_ jobCoordinate: CLLocationCoordinate2D) -> [Pin] {
        var result = [Pin(id: "job", coordinate: jobCoordinate, kind: isApproximate ? .approximateArea : .job)]
        for worker in travelingWorkers {
            if let live = worker.liveLocation {
                result.append(Pin(
                    id: worker.id,
                    coordinate: CLLocationCoordinate2D(latitude: live.latitude, longitude: live.longitude),
                    kind: .worker(name: worker.workerName ?? "Worker", photo: worker.workerPhotoUrl)
                ))
            }
        }
        return result
    }

    @ViewBuilder
    private func pinView(_ pin: Pin) -> some View {
        switch pin.kind {
        case .approximateArea:
            Circle()
                .fill(HandzColor.primary.opacity(0.18))
                .overlay(Circle().stroke(HandzColor.primary.opacity(0.5), lineWidth: 1.5))
                .frame(width: 110, height: 110)
        case .job:
            Image(systemName: "house.circle.fill")
                .font(.system(size: 34))
                .symbolRenderingMode(.palette)
                .foregroundStyle(HandzColor.onFill, HandzColor.primary)
                .shadow(color: HandzColor.shadow.opacity(0.3), radius: 4, y: 2)
        case .worker(_, let photo):
            AvatarView(photoPath: photo, size: 36)
                .overlay(Circle().stroke(HandzColor.onFill, lineWidth: 3))
                .shadow(color: HandzColor.shadow.opacity(0.3), radius: 4, y: 2)
        }
    }

    private func travelLine(_ worker: JobWorker, _ live: LiveLocation) -> some View {
        let name = worker.workerName ?? "Your worker"
        let eta = etaMinutes[worker.id].map { $0 <= 1 ? "about 1 min away" : "about \($0) min away" }
        return HStack(spacing: 8) {
            Image(systemName: "car.fill")
                .foregroundColor(HandzColor.statusInProgress)
                .accessibilityHidden(true)
            Text("\(name) is \(eta ?? "on the way")")
                .font(HandzTypography.callout.weight(.semibold))
                .foregroundColor(HandzColor.textPrimary)
            Spacer(minLength: 4)
            Text(live.updatedAt, style: .relative)
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textFaint)
        }
        .accessibilityElement(children: .combine)
    }

    private var accessibilityText: String {
        if isApproximate { return "Map of the approximate job area in \(job.city)" }
        let moving = travelingWorkers.filter { $0.liveLocation != nil }.count
        return moving > 0 ? "Map of the job location and your worker on the way" : "Map of the job location"
    }

    // MARK: - Helpers

    private static func region(for job: Job, workers: [JobWorker]) -> MKCoordinateRegion {
        let center = CLLocationCoordinate2D(latitude: job.latitude ?? 0, longitude: job.longitude ?? 0)
        let points = [center] + workers.compactMap { w in
            w.liveLocation.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        guard points.count > 1 else {
            let span = job.locationIsApproximate == true ? 0.03 : 0.012
            return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        }
        let lats = points.map(\.latitude)
        let lons = points.map(\.longitude)
        let mid = CLLocationCoordinate2D(latitude: (lats.min()! + lats.max()!) / 2, longitude: (lons.min()! + lons.max()!) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.012, (lats.max()! - lats.min()!) * 1.6),
            longitudeDelta: max(0.012, (lons.max()! - lons.min()!) * 1.6)
        )
        return MKCoordinateRegion(center: mid, span: span)
    }

    /// Driving time from each worker's position to the job, from Apple Maps.
    private func updateArrivalEstimates(to destination: CLLocationCoordinate2D) async {
        for worker in travelingWorkers {
            guard let live = worker.liveLocation else { continue }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: live.latitude, longitude: live.longitude)))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile
            if let eta = try? await MKDirections(request: request).calculateETA() {
                etaMinutes[worker.id] = max(1, Int((eta.expectedTravelTime / 60).rounded()))
            }
        }
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = job.address ?? job.title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
