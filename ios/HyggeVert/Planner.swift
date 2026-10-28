import CoreLocation
import Foundation

/// Ét ben af en rejse (gå, cykle, bus …).
struct Leg: Identifiable, Hashable {
    let id = UUID()
    let mode: Mode
    let from: CLLocationCoordinate2D
    let to: CLLocationCoordinate2D
    var km: Double
    var minutes: Double
    let title: String
    /// Ruten på kortet. Tom, indtil OSRM har svaret (eller en lige linje som reserve).
    var path: [CLLocationCoordinate2D] = []
    /// Sand, når ruten er et overslag (lige linje), fx for bus/letbane.
    var indicative = false

    // Ruten tæller med, så kortet tegnes om, når OSRM har svaret.
    static func == (a: Leg, b: Leg) -> Bool { a.id == b.id && a.path.count == b.path.count && a.km == b.km }
    func hash(into h: inout Hasher) { h.combine(id) }
}

/// Et grønt rejseforslag til et sted.
struct TripOption: Identifiable, Hashable {
    let id = UUID()
    let mode: Mode
    var legs: [Leg]
    let destination: Place
    var hub: DonkeyHub? = nil
    var zone: LimeZone? = nil
    var stop: Stop? = nil
    /// Ekstra minutter (ventetid på bus/letbane, hente cykel …).
    var overheadMinutes: Double = 0

    var minutes: Double { legs.reduce(overheadMinutes) { $0 + $1.minutes } }
    /// Kilometer med selve transportmidlet (gang tæller 0 g).
    var mainKm: Double { legs.filter { $0.mode != .walk }.reduce(0) { $0 + $1.km } + (mode == .walk ? totalKm : 0) }
    var totalKm: Double { legs.reduce(0) { $0 + $1.km } }
    var grams: Double { mode == .walk ? 0 : AppData.shared.grams(mode, km: legs.filter { $0.mode == mode }.reduce(0) { $0 + $1.km }) }
    var isComparisonOnly: Bool { mode == .car }

    static func == (a: TripOption, b: TripOption) -> Bool { a.id == b.id && a.legs == b.legs }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum Planner {
    /// 2–4 grønne forslag sorteret efter laveste CO₂ (så tid), og bilen til sidst.
    static func options(from origin: CLLocationCoordinate2D, to place: Place, walkLimitKm: Double = 3.2) -> [TripOption] {
        let data = AppData.shared
        let dest = place.coordinate
        let crow = Geo.km(origin, dest)
        let road = crow * 1.3
        var green: [TripOption] = []

        func leg(_ m: Mode, _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ title: String, indicative: Bool = false) -> Leg {
            let km = Geo.roadKm(a, b)
            return Leg(mode: m, from: a, to: b, km: km, minutes: km / m.speedKmh * 60, title: title, indicative: indicative)
        }

        // À pied
        if road <= walkLimitKm {
            green.append(TripOption(mode: .walk, legs: [leg(.walk, origin, dest, L("leg.walk.to", place.name))], destination: place))
        }

        // Donkey Republic: gå til nærmeste zone, cykle derfra
        if crow <= 12, let (hub, d) = Geo.nearest(data.donkeyHubs, to: origin, at: \.coordinate), d <= 1.5 {
            var o = TripOption(mode: .donkey, legs: [
                leg(.walk, origin, hub.coordinate, L("leg.walk.donkey", hub.name)),
                leg(.donkey, hub.coordinate, dest, L("leg.ride.to", place.name)),
            ], destination: place, hub: hub)
            o.overheadMinutes = 2
            green.append(o)
        }

        // Lime (eksempelzoner)
        if crow <= 12, let (zone, d) = Geo.nearest(data.limeZones, to: origin, at: \.coordinate), d <= 1.5 {
            var o = TripOption(mode: .lime, legs: [
                leg(.walk, origin, zone.coordinate, L("leg.walk.lime", zone.name)),
                leg(.lime, zone.coordinate, dest, L("leg.ride.to", place.name)),
            ], destination: place, zone: zone)
            o.overheadMinutes = 2
            green.append(o)
        }

        // Bus / letbane / tog
        if crow > 1.2 {
            if let o = transit(from: origin, to: place, leg: leg) { green.append(o) }
        }

        green.sort { ($0.grams, $0.minutes) < ($1.grams, $1.minutes) }
        green = Array(green.prefix(4))

        // Bil: kun til sammenligning
        var car = TripOption(mode: .car, legs: [leg(.car, origin, dest, L("leg.car"))], destination: place)
        if crow > 15 { car.legs[0].minutes = car.legs[0].km / 70 * 60 }
        car.overheadMinutes = 5
        return green + [car]
    }

    private static func transit(from origin: CLLocationCoordinate2D, to place: Place,
                                leg: (Mode, CLLocationCoordinate2D, CLLocationCoordinate2D, String, Bool) -> Leg) -> TripOption? {
        let data = AppData.shared
        let dest = place.coordinate
        let far = Geo.km(origin, dest) > 15

        // Udflugt med tog: gå til Aarhus H og tag toget.
        if far && place.greenTransport == .train {
            let station = Stop(id: "aarhus-h", name: "Aarhus H", type: .bus, lat: AppData.aarhusH.latitude, lng: AppData.aarhusH.longitude)
            var o = TripOption(mode: .train, legs: [
                leg(.walk, origin, station.coordinate, L("leg.walk.station"), false),
                leg(.train, station.coordinate, dest, L("leg.train", place.area), true),
            ], destination: place, stop: station)
            o.overheadMinutes = 10
            return o
        }

        let trams = data.stops.filter { $0.type == .tram }
        let nearTram = Geo.nearest(trams, to: origin, at: \.coordinate)
        let destTram = Geo.nearest(trams, to: dest, at: \.coordinate)
        // Letbane, når der er et letbanestop tæt på begge ender (eller stedet anbefaler letbanen).
        let useTram = (nearTram?.1 ?? 9) <= 0.9 && ((destTram?.1 ?? 9) <= 1.0 || place.greenTransport == .tram)
        let mode: Mode = useTram ? .tram : .bus
        let pool = useTram ? trams : data.stops
        guard let (start, walkKm) = Geo.nearest(pool, to: origin, at: \.coordinate), walkKm <= 1.5 else { return nil }

        var legs = [leg(.walk, origin, start.coordinate, L("leg.walk.stop", start.name), false)]
        if let (end, endKm) = Geo.nearest(pool, to: dest, at: \.coordinate), endKm <= 1.2, end.id != start.id {
            legs.append(leg(mode, start.coordinate, end.coordinate, L("leg.transit", mode.title, end.name), true))
            legs.append(leg(.walk, end.coordinate, dest, L("leg.walk.to", place.name), false))
        } else {
            legs.append(leg(mode, start.coordinate, dest, L("leg.transit.direct", mode.title, place.area), true))
        }
        var o = TripOption(mode: mode, legs: legs, destination: place, stop: start)
        o.overheadMinutes = 6
        return o
    }
}

// MARK: - Ruter fra OSRM

enum Router {
    /// Henter rigtige gå- og cykelruter fra den offentlige OSRM-tjeneste (routing.openstreetmap.de).
    /// Svarer den ikke inden for 8 sekunder, tegnes en lige linje, så demoen altid virker.
    static func route(_ option: TripOption) async -> TripOption {
        var o = option
        await withTaskGroup(of: (Int, Leg).self) { group in
            for (i, l) in option.legs.enumerated() {
                group.addTask { (i, await route(l)) }
            }
            for await (i, l) in group { o.legs[i] = l }
        }
        return o
    }

    private static func route(_ leg: Leg) async -> Leg {
        var l = leg
        let profile: String? = switch leg.mode {
        case .walk: "routed-foot"
        case .bike, .donkey, .lime: "routed-bike"
        default: nil
        }
        guard let profile, !leg.indicative else {
            l.path = [leg.from, leg.to]
            return l
        }
        let coords = "\(leg.from.longitude),\(leg.from.latitude);\(leg.to.longitude),\(leg.to.latitude)"
        guard let url = URL(string: "https://routing.openstreetmap.de/\(profile)/route/v1/driving/\(coords)?overview=full&geometries=geojson") else { return l }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("HyggeVert-school-prototype/1.0", forHTTPHeaderField: "User-Agent")

        struct Response: Decodable {
            struct Route: Decodable {
                struct Geometry: Decodable { let coordinates: [[Double]] }
                let distance: Double
                let duration: Double
                let geometry: Geometry
            }
            let routes: [Route]
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let r = try JSONDecoder().decode(Response.self, from: data).routes.first else { throw URLError(.badServerResponse) }
            l.path = r.geometry.coordinates.map { .init(latitude: $0[1], longitude: $0[0]) }
            l.km = r.distance / 1000
            // OSRM-cykeltider er optimistiske; vi bruger vores egen fart til elcykler og bycykler.
            l.minutes = leg.mode == .walk ? r.duration / 60 : l.km / leg.mode.speedKmh * 60
        } catch {
            l.path = [leg.from, leg.to]
            l.indicative = true
        }
        return l
    }
}
