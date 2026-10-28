import MapKit
import SwiftUI

/// Bundarket for et sted: info → "Y aller" → grønne forslag → rute og "J'y suis !".
struct PlaceSheet: View {
    let place: Place
    @Binding var route: TripOption?
    @Binding var detent: PresentationDetent
    let onDone: () -> Void

    @Environment(LocationProvider.self) private var location
    @Environment(DayModel.self) private var day
    @Environment(ProfileStore.self) private var profile

    enum Step: Equatable { case info, locating, options, chosen }
    @State private var step: Step = .info
    @State private var options: [TripOption] = []
    @State private var chosen: TripOption?
    @State private var loadingRoute = false
    @State private var askMaps = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case .info: info
                case .locating: locating
                case .options: optionsList
                case .chosen: chosenView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 24)
            .animation(.smooth(duration: 0.35), value: step)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(L("go.maps.title"), isPresented: $askMaps, titleVisibility: .visible) {
            let mode = chosen?.mode ?? place.greenTransport
            Button("Google Maps") { Links.open(Links.googleMaps(to: place.coordinate, mode: mode)) }
            Button(L("go.maps.plans")) { Links.openInPlans(place, mode: mode) }
        }
    }

    // MARK: 1. Info

    private var info: some View {
        VStack(alignment: .leading, spacing: 14) {
            if Photos.credits[place.id] != nil {
                VStack(alignment: .leading, spacing: 6) {
                    PlacePhoto(place: place, height: 180)
                        .clipShape(.rect(cornerRadius: 20))
                    PhotoCreditLink(place: place)
                }
            }
            HStack(spacing: 6) {
                Tag(text: place.category.title, fg: .white, bg: place.category.color, icon: place.category.icon)
                if place.isHiddenGem && place.category != .secret {
                    Tag(text: L("category.secret"), fg: Palette.nightHighlight, bg: Palette.night, icon: "sparkles")
                }
                if place.organic == true { OrganicTag() }
                if place.demo == true { Tag(text: L("common.example"), fg: Palette.ochre, bg: Palette.ochre.opacity(0.12)) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(Typo.display(26, .heavy, relativeTo: .title))
                    .foregroundStyle(Palette.ink)
                Text(place.area).font(Typo.body(14, .medium)).foregroundStyle(Palette.inkSecondary)
            }
            Text(place.summary)
                .font(Typo.body(16))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            let here = AppData.shared.colocated(with: place)
            if !here.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("go.alsohere")).font(Typo.body(13, .semibold)).foregroundStyle(Palette.inkSecondary)
                    ForEach(here) { p in
                        HStack(spacing: 10) {
                            Image(systemName: p.category.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(p.category.color, in: .rect(cornerRadius: 9))
                            Text(p.name).font(Typo.body(15, .semibold)).foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                            if p.organic == true { OrganicTag() }
                        }
                    }
                }
                .padding(14)
                .background(Palette.surface, in: .rect(cornerRadius: 14))
            }

            let km = Geo.roadKm(location.origin, place.coordinate)
            let mode = place.greenTransport
            HStack(spacing: 10) {
                Stat(icon: "location", value: Format.km(km), label: location.usesFallback ? L("go.from.demo") : L("go.from.you"))
                Stat(icon: mode.icon, value: mode.shortTitle, label: L("go.suggested"))
                Stat(icon: "leaf", value: Format.co2(AppData.shared.grams(mode, km: km)), label: L("go.co2"))
            }

            Button {
                Task { await startGo() }
            } label: {
                Label(L("go.cta"), systemImage: "arrow.triangle.turn.up.right.diamond")
            }
            .buttonStyle(.pill)
            .sensoryFeedback(.impact(weight: .medium), trigger: step)

            Button(L("go.maps"), systemImage: "map") { askMaps = true }
                .buttonStyle(.pill(.quiet))
        }
    }

    private var locating: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(Palette.moss)
            Text(L("go.locating")).font(Typo.body(15, .medium)).foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    /// Spørg om placering (højst et par sekunder), og regn så forslagene ud.
    private func startGo() async {
        step = .locating
        detent = .height(420)
        location.request()
        for _ in 0..<40 where location.status == .notDetermined { try? await Task.sleep(for: .milliseconds(250)) }
        for _ in 0..<8 where location.real == nil && (location.status == .authorizedWhenInUse || location.status == .authorizedAlways) {
            try? await Task.sleep(for: .milliseconds(250))
        }
        options = Planner.options(from: location.origin, to: place, walkLimitKm: profile.current.walkLimitKm)
        step = .options
        detent = .large
    }

    // MARK: 2. Forslag

    private var optionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            backButton(L("go.back.info")) { step = .info; detent = .height(420) }
            Text(L("go.options.title", place.name))
                .font(Typo.display(24, .heavy, relativeTo: .title2))
                .foregroundStyle(Palette.ink)
            Label(location.usesFallback ? L("go.origin.demo") : L("go.origin.you"),
                  systemImage: location.usesFallback ? "mappin.circle" : "location.fill")
                .font(Typo.body(14, .medium))
                .foregroundStyle(Palette.inkSecondary)

            ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                OptionCard(option: o, best: i == 0 && !o.isComparisonOnly, levelAfter: day.level(adding: o.grams, mode: o.mode)) {
                    choose(o)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func choose(_ o: TripOption) {
        chosen = o
        step = .chosen
        detent = .height(420)
        loadingRoute = true
        route = o
        Task {
            let routed = await Router.route(o)
            guard chosen?.id == o.id else { return }
            chosen = routed
            route = routed
            loadingRoute = false
        }
    }

    // MARK: 3. Valgt rute

    @ViewBuilder private var chosenView: some View {
        if let o = chosen {
            VStack(alignment: .leading, spacing: 14) {
                backButton(L("go.back.options")) { step = .options; route = nil; detent = .large }

                HStack(spacing: 14) {
                    if o.mode.isBike { LeafBadge(size: 52, grow: true) }
                    else {
                        Image(systemName: o.mode.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(o.mode.color, in: .circle)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.mode.title).font(Typo.display(22, .heavy, relativeTo: .title2)).foregroundStyle(Palette.ink)
                        HStack(spacing: 14) {
                            Label(Format.minutes(o.minutes), systemImage: "clock")
                            Label(Format.co2(o.grams), systemImage: "leaf")
                            if loadingRoute { ProgressView().controlSize(.mini) }
                        }
                        .font(Typo.body(15, .semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .contentTransition(.numericText())
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(o.legs) { leg in LegRow(leg: leg, last: leg.id == o.legs.last?.id) }
                }
                .card()

                note(for: o)

                appButtons(for: o)

                Button {
                    finish(o)
                } label: {
                    Label(L("go.arrived"), systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.pill(.dark))
            }
        }
    }

    @ViewBuilder private func note(for o: TripOption) -> some View {
        let text: String? = switch o.mode {
        case .donkey: L("go.note.donkey")
        case .lime: L("go.note.lime")
        case .tram, .bus, .train: L("go.note.ticket")
        default: nil
        }
        if let text {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle").foregroundStyle(Palette.fjord)
                Text(text).font(Typo.body(14)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            }
            .card(Palette.fjordLight, radius: 18)
        }
        if o.legs.contains(where: { $0.indicative && !$0.mode.isTransit }) {
            Text(L("go.note.offline")).font(Typo.body(13)).foregroundStyle(Palette.inkSecondary)
        }
    }

    @ViewBuilder private func appButtons(for o: TripOption) -> some View {
        switch o.mode {
        case .donkey:
            Button(L("go.open.donkey"), systemImage: "bicycle") { Links.open(Links.donkey(o.hub)) }
                .buttonStyle(.pill(.secondary))
        case .lime:
            Button(L("go.open.lime"), systemImage: "bolt") { Links.open(Links.limeStore) }
                .buttonStyle(.pill(.secondary))
        case .tram, .bus, .train:
            Button(L("go.transit.route"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                Links.open(Links.googleMaps(to: place.coordinate, mode: .bus))
            }
            .buttonStyle(.pill(.secondary))
            HStack(spacing: 10) {
                Button(L("go.open.midttrafik")) { Links.open(Links.midttrafikLive) }
                    .buttonStyle(.pill(.quiet))
                Button(L("go.open.ticket")) { Links.open(Links.rejsebillet) }
                    .buttonStyle(.pill(.quiet))
            }
        default:
            EmptyView()
        }
        Button(L("go.maps"), systemImage: "map") { askMaps = true }
            .buttonStyle(.pill(.quiet))
    }

    private func finish(_ o: TripOption) {
        let km = o.mode == .walk ? o.totalKm : o.legs.filter { $0.mode != .walk }.reduce(0) { $0 + $1.km }
        day.add(Trip(title: L("trip.to", place.name), mode: o.mode, km: km, grams: o.grams))
        route = nil
        onDone()
    }

    private func backButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.smooth) { action() } }) {
            Label(title, systemImage: "chevron.left")
                .font(Typo.body(15, .semibold))
                .frame(minHeight: 44)
        }
        .foregroundStyle(Palette.moss)
    }
}

// MARK: - Byggeklodser

struct Stat: View {
    let icon: String
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.moss)
            Text(value).font(Typo.body(15, .bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(Typo.body(12)).foregroundStyle(Palette.inkSecondary).lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct OptionCard: View {
    let option: TripOption
    let best: Bool
    let levelAfter: Level
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: option.mode.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(option.isComparisonOnly ? Palette.car : .white)
                        .frame(width: 46, height: 46)
                        .background(option.isComparisonOnly ? Palette.car.opacity(0.1) : option.mode.color, in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(option.mode.title).font(Typo.display(18, .bold, relativeTo: .headline)).foregroundStyle(Palette.ink)
                            if best { Tag(text: L("go.best"), fg: .white, bg: Palette.moss) }
                            if option.zone?.demo == true { Tag(text: L("common.example"), fg: Palette.ochre, bg: Palette.ochre.opacity(0.12)) }
                        }
                        Text(summary).font(Typo.body(13)).foregroundStyle(Palette.inkSecondary).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if !option.isComparisonOnly { Image(systemName: "chevron.right").foregroundStyle(Palette.inkSecondary) }
                }
                HStack(spacing: 8) {
                    Tag(text: Format.minutes(option.minutes), fg: Palette.ink, bg: Palette.background, icon: "clock")
                    Tag(text: Format.co2(option.grams), fg: option.isComparisonOnly ? Palette.car : Palette.moss,
                        bg: option.isComparisonOnly ? Palette.car.opacity(0.1) : Palette.mossLight, icon: "leaf")
                    Spacer(minLength: 0)
                    if option.isComparisonOnly {
                        Text(L("go.compare")).font(Typo.body(12, .semibold)).foregroundStyle(Palette.car)
                    } else {
                        Text(levelAfter.percent > 0 ? "\(levelAfter.title) −\(levelAfter.percent) %" : levelAfter.title)
                            .font(Typo.body(12, .semibold))
                            .foregroundStyle(Palette.fjord)
                    }
                }
            }
            .card()
            .overlay {
                if best { RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.moss, lineWidth: 2) }
            }
            .opacity(option.isComparisonOnly ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .disabled(option.isComparisonOnly)
        .accessibilityHint(option.isComparisonOnly ? L("go.compare") : L("go.choose.hint"))
    }

    private var summary: String {
        option.legs.map { "\(Format.minutes($0.minutes)) \($0.mode.phrase)" }
            .joined(separator: " + ")
    }
}

struct LegRow: View {
    let leg: Leg
    let last: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: leg.mode.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(leg.mode.color, in: .circle)
                if !last {
                    Rectangle().fill(leg.mode.color.opacity(0.35)).frame(width: 3).frame(minHeight: 22)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(leg.title).font(Typo.body(15, .semibold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("leg.meta", Format.minutes(leg.minutes), Format.km(leg.km)))
                    .font(Typo.body(13)).foregroundStyle(Palette.inkSecondary)
                if leg.indicative && leg.mode.isTransit {
                    Text(L("leg.indicative")).font(Typo.body(12, .medium)).foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(.bottom, last ? 0 : 10)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Transportpunkt

struct TransportSheet: View {
    let point: TransportPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch point {
            case .stop(let s):
                header(icon: s.type == .tram ? "tram.fill" : "bus.fill", color: s.type == .tram ? Palette.night : Palette.fjord,
                       kind: s.type == .tram ? L("transport.tram") : L("transport.bus"), name: s.name,
                       tag: L("transport.source.osm"))
                Text(L("go.note.ticket")).font(Typo.body(15)).foregroundStyle(Palette.ink)
                Button(L("go.transit.route"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    Links.open(Links.googleMaps(to: s.coordinate, mode: .walk))
                }
                .buttonStyle(.pill(.secondary))
                HStack(spacing: 10) {
                    Button(L("go.open.midttrafik")) { Links.open(Links.midttrafikLive) }.buttonStyle(.pill(.quiet))
                    Button(L("go.open.ticket")) { Links.open(Links.rejsebillet) }.buttonStyle(.pill(.quiet))
                }
            case .donkey(let h):
                header(icon: "bicycle", color: Palette.moss, kind: L("transport.donkey"), name: h.name,
                       tag: h.demo ? L("common.example") : L("transport.source.gbfs"))
                Text(L("transport.donkey.body")).font(Typo.body(15)).foregroundStyle(Palette.ink)
                Button(L("go.open.donkey"), systemImage: "bicycle") { Links.open(Links.donkey(h)) }
                    .buttonStyle(.pill)
            case .lime(let z):
                header(icon: "bolt.fill", color: Palette.moss, kind: L("transport.lime"), name: z.name, tag: L("common.example"))
                Text(L("transport.lime.body")).font(Typo.body(15)).foregroundStyle(Palette.ink)
                Button(L("go.open.lime"), systemImage: "bolt") { Links.open(Links.limeStore) }
                    .buttonStyle(.pill)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private func header(icon: String, color: Color, kind: String, name: String, tag: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(color, in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(kind).font(Typo.body(13, .semibold)).foregroundStyle(Palette.inkSecondary)
                Text(name).font(Typo.display(22, .heavy, relativeTo: .title2)).foregroundStyle(Palette.ink)
                Tag(text: tag, fg: tag == L("common.example") ? Palette.ochre : Palette.fjord,
                    bg: tag == L("common.example") ? Palette.ochre.opacity(0.12) : Palette.fjordLight)
            }
        }
    }
}
