import CoreLocation
import SwiftUI

// MARK: - Rejseformer

enum Mode: String, Codable, CaseIterable, Identifiable {
    case walk, bike, donkey, lime, tram, bus, train, car
    var id: String { rawValue }

    var title: String { L("mode.\(rawValue)") }
    /// Kort navn til små felter ("Donkey", "Bus" …).
    var shortTitle: String { L("mode.short.\(rawValue)") }
    /// "à pied", "à vélo", "en bus" … til opsummeringer.
    var phrase: String { L("mode.phrase.\(rawValue)") }

    var icon: String {
        switch self {
        case .walk: "figure.walk"
        case .bike, .donkey: "bicycle"
        case .lime: "bolt.circle"
        case .tram: "tram"
        case .bus: "bus"
        case .train: "train.side.front.car"
        case .car: "car"
        }
    }

    /// Gennemsnitsfart i km/t, brugt til tidsoverslag.
    var speedKmh: Double {
        switch self {
        case .walk: 4.8
        case .bike, .donkey: 15
        case .lime: 18
        case .tram: 22
        case .bus: 20
        case .train: 65
        case .car: 32
        }
    }

    var color: Color {
        switch self {
        case .walk: Palette.fjord
        case .bike, .donkey, .lime: Palette.moss
        case .tram, .bus, .train: Palette.night
        case .car: Palette.car
        }
    }

    var isBike: Bool { self == .bike || self == .donkey || self == .lime }

    /// Det bedste rabatniveau, man kan nå på en dag med denne rejseform:
    /// gang og cykel −20 %, Lime og offentlig transport −10 %, bil ingen rabat.
    var levelCap: Level {
        switch self {
        case .walk, .bike, .donkey: .foret
        case .lime, .tram, .bus, .train: .prairie
        case .car: .none
        }
    }
    var isTransit: Bool { self == .tram || self == .bus || self == .train }

    /// Rejseformer, man kan vælge i beregneren (Donkey er en cykel, så den står for sig selv).
    static let calculator: [Mode] = [.walk, .bike, .donkey, .lime, .tram, .bus, .train, .car]
}

// MARK: - Steder

enum Category: String, Codable, CaseIterable, Identifiable {
    case nature, musee, secret, partenaire, excursion, restaurant, cafe, activite
    var id: String { rawValue }
    var title: String { L("category.\(rawValue)") }

    var icon: String {
        switch self {
        case .nature: "leaf"
        case .musee: "building.columns"
        case .secret: "sparkles"
        case .partenaire: "storefront"
        case .excursion: "map"
        case .restaurant: "fork.knife"
        case .cafe: "cup.and.saucer"
        case .activite: "theatermasks"
        }
    }
    var color: Color {
        switch self {
        case .nature: Palette.moss
        case .musee: Palette.fjord
        case .secret: Palette.night
        case .partenaire: Palette.ochre
        case .excursion: Palette.inkSecondary
        case .restaurant, .cafe: Palette.plum
        case .activite: Palette.teal
        }
    }
    var iconColor: Color { self == .secret ? Palette.nightHighlight : .white }
}

struct Place: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: Category
    let description_fr: String
    let lat: Double
    let lng: Double
    let area: String
    let greenTransport: Mode
    let isHiddenGem: Bool
    var demo: Bool? = nil
    /// Har Det Økologiske Spisemærke (ifølge VisitAarhus' liste).
    var organic: Bool? = nil

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    var description_da: String? = nil
    /// Beskrivelsen på appens sprog (fransk, hvis der ikke er en dansk).
    var summary: String { AppLanguage.current == .da ? (description_da ?? description_fr) : description_fr }
}

struct Partner: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: String
    let offer_fr: String
    var offer_da: String? = nil
    let lat: Double
    let lng: Double
    let demo: Bool

    var icon: String {
        switch kind {
        case "cafe": "cup.and.saucer"
        case "bike": "bicycle"
        case "hotel": "bed.double"
        case "shop": "basket"
        default: "fork.knife"
        }
    }

    /// Partneren som sted på kortet og i Explorer.
    var asPlace: Place {
        Place(id: id, name: name, category: .partenaire, description_fr: offer_fr, lat: lat, lng: lng,
              area: L("common.example"), greenTransport: .walk, isHiddenGem: false, demo: true, description_da: offer_da)
    }
}

// MARK: - Transport

struct Stop: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case bus, tram }
    let id: String
    let name: String
    let type: Kind
    let lat: Double
    let lng: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

struct DonkeyHub: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let deeplink: String?
    let demo: Bool
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

struct LimeZone: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
    let radius_m: Double
    let demo: Bool
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
}

/// Noget, man kan trykke på i kortets transportlag.
enum TransportPoint: Identifiable, Hashable {
    case stop(Stop), donkey(DonkeyHub), lime(LimeZone)
    var id: String {
        switch self {
        case .stop(let s): "s" + s.id
        case .donkey(let d): "d" + d.id
        case .lime(let l): "l" + l.id
        }
    }
}

// MARK: - Dagens ture

struct Trip: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var title: String
    var mode: Mode
    var km: Double
    var grams: Double
}

// MARK: - Sprog

/// Slår en tekst op i `fr.lproj/Localizable.strings` (én fil pr. sprog).
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = AppLanguage.current.bundle.localizedString(forKey: key, value: nil, table: nil)
    return args.isEmpty ? format : String(format: format, locale: AppLanguage.current.locale, arguments: args)
}

/// Appens sprog. Vælges i appen (spørgeskemaet og menuen ••• på forsiden), uafhængigt af telefonens sprog.
enum AppLanguage: String, CaseIterable, Identifiable {
    case fr, da
    var id: String { rawValue }
    static let storageKey = "hyggevert.lang"

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .fr
    }

    /// Navnet på sproget, skrevet på sproget selv.
    var name: String { self == .fr ? "Français" : "Dansk" }
    var locale: Locale { Locale(identifier: self == .fr ? "fr_FR" : "da_DK") }
    var bundle: Bundle {
        Bundle.main.path(forResource: rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

enum Format {
    static var locale: Locale { AppLanguage.current.locale }

    static func km(_ km: Double) -> String {
        km < 1 ? "\(Int((km * 1000 / 10).rounded()) * 10) m"
               : km.formatted(.number.precision(.fractionLength(km < 10 ? 1 : 0)).locale(locale)) + " km"
    }
    static func co2(_ grams: Double) -> String {
        grams < 1000 ? "\(Int(grams.rounded())) g"
                     : (grams / 1000).formatted(.number.precision(.fractionLength(1)).locale(locale)) + " kg"
    }
    static func minutes(_ min: Double) -> String {
        let m = max(1, Int(min.rounded()))
        return m < 60 ? "\(m) min" : "\(m / 60) h \(String(format: "%02d", m % 60))"
    }
}

extension String {
    /// "mercredi 28 octobre" → "Mercredi 28 octobre" (kun første bogstav stort, som på fransk og dansk).
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
