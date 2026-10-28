import MapKit
import SwiftUI

/// Fuldskærmskort over Aarhus med to lag: steder og transport.
struct MapScreen: View {
    @Environment(AppNavigation.self) private var nav
    @Environment(LocationProvider.self) private var location

    @State private var camera: MapCameraPosition = .region(Self.aarhus)
    @State private var showPlaces = true
    @State private var showTransport = true
    @State private var sheet: MapSheet?
    @State private var detent: PresentationDetent = .height(420)
    @State private var route: TripOption?
    @State private var region: MKCoordinateRegion = Self.aarhus

    static let aarhus = MKCoordinateRegion(center: .init(latitude: 56.146, longitude: 10.200),
                                          span: .init(latitudeDelta: 0.07, longitudeDelta: 0.07))

    enum MapSheet: Identifiable, Equatable {
        case place(Place), transport(TransportPoint)
        var id: String {
            switch self {
            case .place(let p): "p" + p.id
            case .transport(let t): t.id
            }
        }
    }

    private let data = AppData.shared

    var body: some View {
        Map(position: $camera) {
            if let route {
                ForEach(route.legs) { leg in
                    MapPolyline(coordinates: leg.path.isEmpty ? [leg.from, leg.to] : leg.path)
                        .stroke(leg.mode.color, style: Self.stroke(for: leg))
                }
            }

            if showTransport && route == nil {
                ForEach(data.limeZones) { z in
                    MapCircle(center: z.coordinate, radius: z.radius_m)
                        .foregroundStyle(Palette.moss.opacity(0.12))
                        .stroke(Palette.moss.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                ForEach(visibleTransport) { point in
                    Annotation(transportName(point), coordinate: transportCoord(point), anchor: .center) {
                        TransportMarker(point: point) { open(.transport(point)) }
                    }
                    .annotationTitles(.hidden)
                }
            }

            if let route {
                Annotation(route.destination.name, coordinate: route.destination.coordinate, anchor: .bottom) {
                    PlaceMarker(place: route.destination, selected: true) {}
                }
                .annotationTitles(.hidden)
                if let start = route.legs.first(where: { $0.mode != .walk })?.from, route.legs.count > 1 {
                    Annotation(route.hub?.name ?? route.zone?.name ?? route.stop?.name ?? "", coordinate: start) {
                        Image(systemName: route.mode.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(route.mode.color, in: .circle)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            } else if showPlaces {
                ForEach(data.mapPlaces) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        PlaceMarker(place: place, selected: sheet == .place(place)) { open(.place(place)) }
                    }
                    .annotationTitles(.hidden)
                }
            }

            Annotation(location.usesFallback ? L("map.you.demo") : L("map.you"), coordinate: location.origin) {
                Circle()
                    .fill(Palette.fjord)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: Palette.fjord.opacity(0.4), radius: 6)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { ctx in region = ctx.region }
        .safeAreaInset(edge: .top) { topBar }
        .sheet(item: $sheet, onDismiss: { route = nil }) { s in
            Group {
                switch s {
                case .place(let p): PlaceSheet(place: p, route: $route, detent: $detent, onDone: { sheet = nil })
                case .transport(let t): TransportSheet(point: t)
                }
            }
            .presentationDetents([.height(250), .height(420), .large], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(420)))
            .presentationBackground(Palette.background)
        }
        .onAppear(perform: consumeFocus)
        .onChange(of: nav.focus) { _, _ in consumeFocus() }
        .onChange(of: route) { _, r in
            guard let r else { return }
            let pts = r.legs.flatMap { $0.path.isEmpty ? [$0.from, $0.to] : $0.path }
            withAnimation(.smooth(duration: 0.8)) { camera = .rect(Self.rect(pts)) }
        }
        .onAppear { location.request() }
    }

    // MARK: Lag-knapper

    private var topBar: some View {
        HStack(spacing: 10) {
            Text(L("map.title"))
                .font(Typo.display(22, .heavy))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassEffect(.regular, in: .capsule)
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    LayerToggle(title: L("map.layer.places"), icon: "mappin.and.ellipse", isOn: $showPlaces)
                    LayerToggle(title: L("map.layer.transport"), icon: "tram", isOn: $showTransport)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: Transportpunkter (stoppesteder og Donkey-hubs vises først tæt på)

    private var visibleTransport: [TransportPoint] {
        let trams = data.stops.filter { $0.type == .tram }.map(TransportPoint.stop)
        guard region.span.latitudeDelta < 0.045 else { return trams }
        let r = region
        func inside(_ c: CLLocationCoordinate2D) -> Bool {
            abs(c.latitude - r.center.latitude) < r.span.latitudeDelta / 2 &&
            abs(c.longitude - r.center.longitude) < r.span.longitudeDelta / 2
        }
        let buses = data.stops.filter { $0.type == .bus && inside($0.coordinate) }.prefix(120).map(TransportPoint.stop)
        let hubs = data.donkeyHubs.filter { inside($0.coordinate) }.prefix(120).map(TransportPoint.donkey)
        let limes = data.limeZones.filter { inside($0.coordinate) }.map(TransportPoint.lime)
        return trams + Array(buses) + Array(hubs) + limes
    }

    private func transportCoord(_ p: TransportPoint) -> CLLocationCoordinate2D {
        switch p {
        case .stop(let s): s.coordinate
        case .donkey(let d): d.coordinate
        case .lime(let l): l.coordinate
        }
    }
    private func transportName(_ p: TransportPoint) -> String {
        switch p {
        case .stop(let s): s.name
        case .donkey(let d): d.name
        case .lime(let l): l.name
        }
    }

    // MARK: Hjælpere

    private func open(_ s: MapSheet) {
        route = nil
        detent = .height(420)
        sheet = s
        if case .place(let p) = s { reveal(p.coordinate) }
    }

    /// Flytter kortet, så stedet ses over bundarket.
    private func reveal(_ c: CLLocationCoordinate2D) {
        let span = min(region.span.latitudeDelta, 0.05)
        withAnimation(.smooth(duration: 0.7)) {
            camera = .region(MKCoordinateRegion(center: .init(latitude: c.latitude - span * 0.25, longitude: c.longitude),
                                                span: .init(latitudeDelta: span, longitudeDelta: span)))
        }
    }

    private func consumeFocus() {
        guard let p = nav.focus else { return }
        nav.focus = nil
        region.span = .init(latitudeDelta: 0.03, longitudeDelta: 0.03)
        open(.place(p))
    }

    static func stroke(for leg: Leg) -> StrokeStyle {
        switch leg.mode {
        case .walk: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 9])
        case _ where leg.mode.isTransit: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [12, 8])
        default: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        }
    }

    /// Kortudsnit, der viser hele ruten og plads til bundarket nederst.
    static func rect(_ pts: [CLLocationCoordinate2D]) -> MKMapRect {
        let r = pts.map { MKMapPoint($0) }.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: .init(width: 1, height: 1))) }
        // Ruten skal ligge i den øverste halvdel; bundarket dækker resten.
        let padX = r.size.width * 0.15 + 300, padTop = r.size.height * 0.12 + 300
        let h = r.size.height + padTop * 2
        return MKMapRect(x: r.origin.x - padX, y: r.origin.y - padTop,
                         width: r.size.width + padX * 2, height: h * 2.1)
    }
}

struct LayerToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOn ? .white : Palette.ink)
                .frame(width: 44, height: 44)
        }
        .glassEffect(isOn ? .regular.tint(Palette.moss).interactive() : .regular.interactive(), in: .circle)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? L("a11y.on") : L("a11y.off"))
    }
}

struct PlaceMarker: View {
    let place: Place
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: place.category.icon)
                    .font(.system(size: selected ? 18 : 14, weight: .bold))
                    .foregroundStyle(place.category.iconColor)
                    .frame(width: selected ? 44 : 34, height: selected ? 44 : 34)
                    .background(place.category.color, in: .circle)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                Triangle()
                    .fill(.white)
                    .frame(width: 10, height: 6)
            }
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.35, bounce: 0.4), value: selected)
        .accessibilityLabel("\(place.name), \(place.category.title)")
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: .init(x: r.minX, y: r.minY))
            p.addLine(to: .init(x: r.maxX, y: r.minY))
            p.addLine(to: .init(x: r.midX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

struct TransportMarker: View {
    let point: TransportPoint
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var icon: some View {
        switch point {
        case .stop(let s) where s.type == .tram:
            Image(systemName: "tram.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.nightHighlight)
                .frame(width: 24, height: 24)
                .background(Palette.night, in: .rect(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white, lineWidth: 1.5))
                .accessibilityLabel(L("transport.tram.a11y", name))
        case .stop:
            Image(systemName: "bus.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Palette.fjord, in: .circle)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityLabel(L("transport.bus.a11y", name))
        case .donkey:
            Image(systemName: "bicycle")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 19, height: 19)
                .background(Palette.moss, in: .rect(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white, lineWidth: 1.5))
                .accessibilityLabel(L("transport.donkey.a11y", name))
        case .lime:
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.moss)
                .frame(width: 19, height: 19)
                .background(.white, in: .circle)
                .overlay(Circle().stroke(Palette.moss, lineWidth: 1.5))
                .accessibilityLabel(L("transport.lime.a11y", name))
        }
    }

    private var name: String {
        switch point {
        case .stop(let s): s.name
        case .donkey(let d): d.name
        case .lime(let l): l.name
        }
    }
}
