import CoreLocation
import Foundation
import Observation

/// Svarene fra spørgeskemaet ved første start. Gemmes lokalt og bruges til at tilpasse appen.
struct Profile: Codable, Equatable {
    enum Interest: String, Codable, CaseIterable, Identifiable {
        case cuisine, shopping, musee, nature, activite
        var id: String { rawValue }
        var title: String { L("profile.interest.\(rawValue)") }
        var icon: String {
            switch self {
            case .cuisine: "fork.knife"
            case .shopping: "bag"
            case .musee: "building.columns"
            case .nature: "leaf"
            case .activite: "theatermasks"
            }
        }
    }

    enum Company: String, Codable, CaseIterable, Identifiable {
        case family, friends, familyKids, solo, agency
        var id: String { rawValue }
        var title: String { L("profile.company.\(rawValue)") }
        var icon: String {
            switch self {
            case .family: "person.2"
            case .friends: "person.3"
            case .familyKids: "figure.2.and.child.holdinghands"
            case .solo: "person"
            case .agency: "suitcase"
            }
        }
    }

    var name = ""
    var interests: Set<Interest> = []
    var budgetEuro = 800.0
    var age = 30.0
    var company: Company?

    var displayName: String { name.trimmingCharacters(in: .whitespaces).isEmpty ? "Camille" : name.trimmingCharacters(in: .whitespaces) }

    /// Gåafstand, som appen foreslår til fods (km ad vejen). Kortere for de ældste.
    var walkLimitKm: Double { age >= 65 ? 1.6 : 3.2 }

    // MARK: Anbefalinger

    /// Steder, der passer til shopping (ingen kategori i data dækker det).
    private static let shoppingIDs: Set<String> = ["latinerkvarteret", "salling-rooftop", "street-food", "godsbanen", "aarhus-o"]
    /// Steder, der egner sig til børnefamilier.
    private static let kidIDs: Set<String> = ["tivoli-friheden", "den-gamle-by", "moesgaard", "naturhistorisk", "marselisborg",
                                              "dokk1", "botanisk-have", "aarhus-oje", "steno", "ballehage"]

    func matches(_ i: Interest, _ p: Place) -> Bool {
        switch i {
        case .cuisine: p.category == .restaurant || p.category == .cafe
        case .shopping: Self.shoppingIDs.contains(p.id)
        case .musee: p.category == .musee
        case .nature: p.category == .nature || (p.category == .secret && p.id != "godsbanen")
        case .activite: p.category == .activite || p.category == .excursion
        }
    }

    /// Point for, hvor godt et sted passer til profilen. 0 = ingen særlig grund til at anbefale det.
    func score(_ p: Place) -> Int {
        guard p.category != .partenaire else { return 0 }
        var s = interests.contains { matches($0, p) } ? 3 : 0
        switch company {
        case .familyKids: if Self.kidIDs.contains(p.id) { s += 2 }
        case .family: if p.category == .musee || p.category == .nature { s += 1 }
        case .friends: if p.category == .activite || p.category == .restaurant || p.category == .cafe { s += 1 }
        case .solo: if p.isHiddenGem { s += 1 }
        case .agency: if p.category == .excursion { s += 1 }
        case nil: break
        }
        // Lille budget: natur og parker koster ikke noget. Stort budget: udflugter og økologiske restauranter.
        if budgetEuro < 300, p.category == .nature || p.category == .secret { s += 1 }
        if budgetEuro > 2000, p.category == .excursion || p.organic == true { s += 1 }
        return s
    }
}

@Observable @MainActor
final class ProfileStore {
    private let key = "hyggevert.profile.v1"
    private(set) var profile: Profile?

    init() {
        if let data = UserDefaults.standard.data(forKey: key) {
            profile = try? JSONDecoder().decode(Profile.self, from: data)
        }
    }

    var needsOnboarding: Bool { profile == nil }
    var current: Profile { profile ?? Profile() }

    func save(_ p: Profile) {
        profile = p
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: key) }
    }

    func restart() {
        profile = nil
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// De bedst passende steder, nærmeste først ved lige point.
    func recommendations(from origin: CLLocationCoordinate2D, limit: Int = 8) -> [Place] {
        let p = current
        return AppData.shared.allPlaces
            .map { ($0, p.score($0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : Geo.km(origin, $0.0.coordinate) < Geo.km(origin, $1.0.coordinate) }
            .prefix(limit)
            .map(\.0)
    }
}

