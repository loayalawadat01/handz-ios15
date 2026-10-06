import Foundation
import MapKit

/// One suggested address/place from Apple's MapKit search-completer.
struct AddressSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
}

/// A resolved address with real coordinates, ready to save.
struct ResolvedAddress {
    let fullText: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
}

/// Wraps MKLocalSearchCompleter (live-as-you-type suggestions) and
/// MKLocalSearch (resolving a picked suggestion into real coordinates).
/// Free, built into iOS, no API key -- per spec section 6/45's "avoid
/// unnecessary third-party dependencies."
@MainActor
final class AddressSearchService: NSObject, ObservableObject {
    @Published var suggestions: [AddressSuggestion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func search(_ query: String) {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }

    /// Resolves a picked suggestion into real coordinates. The displayed
    /// text always comes directly from what the person tapped (set in
    /// AddressAutocompleteField), never reconstructed here -- this only
    /// supplies city/state/coordinates behind the scenes.
    func resolve(_ suggestion: AddressSuggestion) async -> ResolvedAddress? {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let placemark = item.placemark
            return ResolvedAddress(
                fullText: suggestion.title,
                city: placemark.locality ?? "",
                state: placemark.administrativeArea ?? "",
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude
            )
        } catch {
            return nil
        }
    }
}

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map {
            AddressSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
        }
        Task { @MainActor in
            self.suggestions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently ignore -- worst case, no suggestions show and the
        // person can still type a plain address manually.
    }
}
