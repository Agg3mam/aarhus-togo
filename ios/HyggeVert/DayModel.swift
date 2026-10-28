import Foundation
import Observation

/// Dagens ture, gemt lokalt (UserDefaults). Ture fra tidligere dage tælles ikke med.
@Observable @MainActor
final class DayModel {
    private(set) var trips: [Trip] = []
    /// Bruges til at fejre et nyt rabatniveau efter "J'y suis !".
    var celebration: Celebration?

    struct Celebration: Identifiable, Equatable {
        let id = UUID()
        let trip: Trip
        let before: Level?
        let after: Level
    }

    private let key = "hyggevert.trips.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = saved.filter { Calendar.current.isDateInToday($0.date) }
        }
    }

    var totalGrams: Double { trips.reduce(0) { $0 + $1.grams } }
    /// Rabatten låses op med dagens første tur.
    var hasTrips: Bool { !trips.isEmpty }
    var level: Level? { hasTrips ? Level.for(grams: totalGrams, modes: trips.map(\.mode)) : nil }

    /// Rejseformen, der holder rabatten nede i dag (fx bussen), hvis det ikke er CO₂-grænsen.
    var cappingMode: Mode? {
        guard let level, Level.for(grams: totalGrams).rawValue < level.rawValue else { return nil }
        return trips.map(\.mode).first { $0.levelCap == level }
    }

    /// Niveauet, man ender på, hvis man lægger en tur oveni.
    func level(adding grams: Double, mode: Mode) -> Level {
        Level.for(grams: totalGrams + grams, modes: trips.map(\.mode) + [mode])
    }

    /// CO₂ sparet i forhold til at have taget bilen på alle turene.
    var savedGrams: Double {
        trips.reduce(0) { $0 + AppData.shared.grams(.car, km: $1.km) - $1.grams }
    }

    @discardableResult
    func add(_ trip: Trip) -> Celebration {
        let before = level
        trips.insert(trip, at: 0)
        save()
        let c = Celebration(trip: trip, before: before, after: level ?? .none)
        celebration = c
        return c
    }

    func remove(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        save()
    }

    func reset() {
        trips = []
        save()
    }

    /// En eksempeldag til præsentationen: tog fra lufthavnsbussen og en tur med letbanen.
    func loadExampleDay() {
        let cal = Calendar.current
        func at(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now }
        let d = AppData.shared
        trips = [
            Trip(date: at(11, 40), title: L("example.trip2"), mode: .tram, km: 4.2, grams: d.grams(.tram, km: 4.2)),
            Trip(date: at(9, 15), title: L("example.trip1"), mode: .bus, km: 44, grams: d.grams(.bus, km: 44)),
        ]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(trips) { UserDefaults.standard.set(data, forKey: key) }
    }
}
