import CoreLocation
import Foundation

/// Alle lokale JSON-filer i `Data/`. Ingen netværk – kun OSRM-ruter hentes live (med reserve).
final class AppData: Sendable {
    static let shared = AppData()

    let places: [Place]
    let partners: [Partner]
    let stops: [Stop]
    let donkeyHubs: [DonkeyHub]
    let limeZones: [LimeZone]
    let factors: [Mode: Double]

    /// Aarhus H (OSM: railway=station), bruges når placeringen mangler eller er langt fra Aarhus.
    static let aarhusH = CLLocationCoordinate2D(latitude: 56.150001, longitude: 10.203561)

    private init() {
        struct PlacesFile: Decodable { let places: [Place] }
        struct PartnersFile: Decodable { let partners: [Partner] }
        struct StopsFile: Decodable { let stops: [Stop] }
        struct HubsFile: Decodable { let hubs: [DonkeyHub] }
        struct LimeFile: Decodable { let zones: [LimeZone] }
        struct FactorsFile: Decodable {
            struct F: Decodable { let g_per_km: Double }
            let factors: [String: F]
        }

        places = Self.load("places", PlacesFile.self).places
        partners = Self.load("partners", PartnersFile.self).partners
        stops = Self.load("stops", StopsFile.self).stops
        donkeyHubs = Self.load("donkey-hubs", HubsFile.self).hubs
        limeZones = Self.load("lime-zones", LimeFile.self).zones
        var f: [Mode: Double] = [:]
        for (k, v) in Self.load("co2-factors", FactorsFile.self).factors {
            if let m = Mode(rawValue: k) { f[m] = v.g_per_km }
        }
        factors = f
    }

    /// Steder + partnere, som de vises i Explorer og på kortet.
    var allPlaces: [Place] { places + partners.map(\.asPlace) }

    /// Andre steder på præcis samme punkt, fx caféen inde i et museum.
    func colocated(with place: Place) -> [Place] {
        allPlaces.filter { $0.id != place.id && $0.lat == place.lat && $0.lng == place.lng }
    }

    /// Steder til kortet: ét punkt pr. position (det første i listen vinder).
    var mapPlaces: [Place] {
        var seen = Set<String>()
        return allPlaces.filter { seen.insert("\($0.lat),\($0.lng)").inserted }
    }

    func grams(_ mode: Mode, km: Double) -> Double { (factors[mode] ?? 0) * km }

    private static func load<T: Decodable>(_ name: String, _ type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(T.self, from: data)
        else { fatalError("Kunne ikke læse \(name).json") }
        return value
    }
}

// MARK: - Afstand

enum Geo {
    /// Afstand i km i fugleflugt (haversine).
    static func km(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let r = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * r, dLng = (b.longitude - a.longitude) * r
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(a.latitude * r) * cos(b.latitude * r) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * 6371 * asin(min(1, sqrt(h)))
    }

    /// Fugleflugt ganget op til et overslag over vejlængden.
    static func roadKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double { km(a, b) * 1.3 }

    static func nearest<T>(_ items: [T], to p: CLLocationCoordinate2D, at coord: (T) -> CLLocationCoordinate2D) -> (T, Double)? {
        items.map { ($0, km(p, coord($0))) }.min { $0.1 < $1.1 }
    }
}

// MARK: - Rabatniveauer

enum Level: Int, CaseIterable, Identifiable {
    case foret, prairie, ville, none
    var id: Int { rawValue }

    /// ≤ 2 kg = −20 %, ≤ 5 kg = −10 %, ≤ 8 kg = −5 %, ellers ingen.
    /// Niveauet for dagen: det dårligste af CO₂-grænsen og loftet fra de rejseformer, man har brugt.
    static func `for`(grams: Double, modes: [Mode]) -> Level {
        let cap = modes.map(\.levelCap).max { $0.rawValue < $1.rawValue } ?? .foret
        return Level(rawValue: max(Level.for(grams: grams).rawValue, cap.rawValue))!
    }

    static func `for`(grams: Double) -> Level {
        switch grams {
        case ...2000: .foret
        case ...5000: .prairie
        case ...8000: .ville
        default: .none
        }
    }

    var percent: Int { [20, 10, 5, 0][rawValue] }
    var limitKg: Double? { [2, 5, 8, nil][rawValue] }
    var title: String { L("level.\(["foret", "prairie", "ville", "none"][rawValue])") }
    var icon: String { ["tree", "leaf", "building.2", "smoke"][rawValue] }
}

/// Dagens budget i gram.
let dailyBudgetGrams = 8000.0
