import CoreLocation
import Observation

/// Brugerens placering. Er den ukendt, afvist eller langt fra Aarhus, bruges Aarhus H,
/// så demoen altid virker (også indendørs og i simulatoren).
@Observable @MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var real: CLLocationCoordinate2D?
    private(set) var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }

    /// Placeringen, appen regner fra.
    var origin: CLLocationCoordinate2D { usesFallback ? AppData.aarhusH : real! }

    /// Sand, når vi regner fra Aarhus H i stedet for den rigtige placering.
    var usesFallback: Bool {
        guard let real else { return true }
        return Geo.km(real, AppData.aarhusH) > 40
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            self.status = s
            if s == .authorizedWhenInUse || s == .authorizedAlways { self.manager.requestLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { @MainActor in self.real = c }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
