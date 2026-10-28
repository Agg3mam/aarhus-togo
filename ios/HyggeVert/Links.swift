import MapKit
import UIKit

/// Links til andre apps. Universelle links (https) åbner appen, hvis den er installeret,
/// og ellers hjemmesiden eller App Store-siden.
enum Links {
    // App Store-id'er slået op i iTunes Search API (country=dk), 2026-10-28.
    static let donkeyStore = URL(string: "https://apps.apple.com/dk/app/id933526449")!
    static let limeStore = URL(string: "https://apps.apple.com/dk/app/id1199780189")!
    static let midttrafikLive = URL(string: "https://apps.apple.com/dk/app/id1290197423")!
    static let rejsebillet = URL(string: "https://apps.apple.com/dk/app/id1664432486")!

    /// Donkey Republic: hubbens eget link fra GBFS-feedet (rental_uris), ellers App Store.
    static func donkey(_ hub: DonkeyHub?) -> URL {
        hub?.deeplink.flatMap(URL.init(string:)) ?? donkeyStore
    }

    static func googleMaps(to c: CLLocationCoordinate2D, mode: Mode) -> URL {
        let travel = switch mode {
        case .walk: "walking"
        case .bike, .donkey, .lime: "bicycling"
        case .car: "driving"
        default: "transit"
        }
        var u = URLComponents(string: "https://www.google.com/maps/dir/")!
        u.queryItems = [
            .init(name: "api", value: "1"),
            .init(name: "destination", value: "\(c.latitude),\(c.longitude)"),
            .init(name: "travelmode", value: travel),
        ]
        return u.url!
    }

    /// Åbner Apple Plans med vejvisning og den rigtige rejseform.
    static func openInPlans(_ place: Place, mode: Mode) {
        let item = MKMapItem(location: CLLocation(latitude: place.lat, longitude: place.lng), address: nil)
        item.name = place.name
        let dir = switch mode {
        case .walk: MKLaunchOptionsDirectionsModeWalking
        case .bike, .donkey, .lime: MKLaunchOptionsDirectionsModeCycling
        case .car: MKLaunchOptionsDirectionsModeDriving
        default: MKLaunchOptionsDirectionsModeTransit
        }
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: dir])
    }

    static func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
