import SwiftUI

struct HomeView: View {
    @Environment(DayModel.self) private var day
    @Environment(AppNavigation.self) private var nav
    @Environment(ProfileStore.self) private var profile
    @Environment(LocationProvider.self) private var location
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.fr.rawValue
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ringCard
                forYouSection
                tripsSection
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Format.locale)).capitalizedFirst)
                    .font(Typo.body(14, .medium))
                    .foregroundStyle(Palette.inkSecondary)
                Text(L("home.hello", profile.current.displayName))
                    .font(Typo.display(34, .heavy, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            Menu {
                Picker(selection: $lang) {
                    ForEach(AppLanguage.allCases) { Text($0.name).tag($0.rawValue) }
                } label: {
                    Label(L("settings.language"), systemImage: "globe")
                }
                .pickerStyle(.menu)
                Button(L("home.menu.profile"), systemImage: "person.crop.circle.badge.questionmark") {
                    withAnimation(.smooth) { profile.restart() }
                }
                Divider()
                Button(L("home.menu.example"), systemImage: "calendar.badge.plus") {
                    withAnimation(.smooth) { day.loadExampleDay() }
                }
                Button(L("home.menu.reset"), systemImage: "arrow.counterclockwise", role: .destructive) {
                    confirmReset = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(L("home.menu"))
            .confirmationDialog(L("home.reset.title"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L("home.menu.reset"), role: .destructive) { withAnimation(.smooth) { day.reset() } }
            }
        }
        .padding(.top, 8)
    }

    /// Ringen er selve rabatsystemet: sporet er delt i de tre niveauer (Forêt, Prairie, Ville).
    private var ringCard: some View {
        Button { nav.tab = .discounts } label: {
            HStack(alignment: .center, spacing: 18) {
                ZoneRing(grams: day.totalGrams, locked: !day.hasTrips)
                    .frame(width: 144, height: 144)
                VStack(alignment: .leading, spacing: 6) {
                    if let level = day.level {
                        Label(level.title, systemImage: level.icon)
                            .font(Typo.body(14, .semibold))
                            .foregroundStyle(Palette.nightHighlight)
                        Text(level.percent > 0 ? "−\(level.percent) %" : "0 %")
                            .font(Typo.display(38, .heavy, relativeTo: .largeTitle))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(value: Double(level.percent)))
                        Text(nextStep(for: level))
                            .font(Typo.body(14))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label(L("home.level.locked"), systemImage: "lock")
                            .font(Typo.body(14, .semibold))
                            .foregroundStyle(Palette.nightHighlight)
                        Text("−20 %")
                            .font(Typo.display(38, .heavy, relativeTo: .largeTitle))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(L("home.level.locked.sub"))
                            .font(Typo.body(14))
                            .foregroundStyle(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if day.savedGrams > 0 {
                        Tag(text: L("home.saved", Format.co2(day.savedGrams)), fg: Palette.night, bg: Palette.nightHighlight, icon: "arrow.down")
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .card(Palette.night, radius: 28)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("home.ring.hint"))
    }

    /// "Encore 1,3 kg avant le Niveau Prairie" – hvor langt der er til næste grænse.
    private func nextStep(for level: Level) -> String {
        if let m = day.cappingMode {
            return level == .none ? L("home.capped.car", m.phrase) : L("home.capped", m.phrase, level.title)
        }
        let left = (level.limitKg ?? 0) * 1000 - day.totalGrams
        switch level {
        case .foret: return L("home.next", Format.co2(left), Level.prairie.title)
        case .prairie: return L("home.next", Format.co2(left), Level.ville.title)
        case .ville: return L("home.next.end", Format.co2(left))
        case .none: return L("home.next.over", Format.co2(day.totalGrams - dailyBudgetGrams))
        }
    }

    /// Steder valgt ud fra svarene i spørgeskemaet.
    @ViewBuilder private var forYouSection: some View {
        let places = profile.recommendations(from: location.origin)
        if !places.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionTitle(text: L("home.foryou"))
                    Text(L("home.foryou.sub")).font(Typo.body(14)).foregroundStyle(Palette.inkSecondary)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(places) { p in
                            Button { nav.show(p) } label: { ForYouCard(place: p) }
                                .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .padding(.horizontal, -16)
            }
        }
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("home.trips"))
            if day.trips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("home.trips.empty"))
                        .font(Typo.body(15))
                        .foregroundStyle(Palette.inkSecondary)
                    Button(L("home.trips.cta"), systemImage: "map") { nav.tab = .map }
                        .buttonStyle(.pill(.secondary))
                }
                .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(day.trips) { trip in
                        TripRow(trip: trip)
                        if trip.id != day.trips.last?.id { Divider().overlay(Palette.hairline).padding(.leading, 60) }
                    }
                }
                .padding(.vertical, 6)
                .background(Palette.surface, in: .rect(cornerRadius: 20))
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("home.tips"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Tip.all) { tip in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: tip.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Palette.fjord)
                            .frame(width: 44, height: 44)
                            .background(Palette.fjordLight, in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L("tip.\(tip.id).title")).font(Typo.display(16, .bold, relativeTo: .headline)).foregroundStyle(Palette.ink)
                            Text(L("tip.\(tip.id).body")).font(Typo.body(14)).foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 14)
                    .accessibilityElement(children: .combine)
                    if tip.id != Tip.all.last?.id { Divider().overlay(Palette.hairline).padding(.leading, 58) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
        }
    }
}

struct Tip: Identifiable {
    let id: String
    let icon: String
    static let all = [
        Tip(id: "water", icon: "drop"),
        Tip(id: "pant", icon: "arrow.3.trianglepath"),
        Tip(id: "bike", icon: "bicycle"),
        Tip(id: "organic", icon: "checkmark.seal"),
    ]
}

struct TripRow: View {
    let trip: Trip
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: trip.mode.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(trip.mode == .car ? Palette.car : Palette.moss)
                .frame(width: 44, height: 44)
                .background(trip.mode == .car ? Palette.car.opacity(0.1) : Palette.mossLight, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.title).font(Typo.body(15, .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                Text(L("trip.row", trip.mode.phrase, Format.km(trip.km), trip.date.formatted(.dateTime.hour().minute().locale(Format.locale))))
                    .font(Typo.body(13)).foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 8)
            Text(Format.co2(trip.grams))
                .font(Typo.body(15, .bold))
                .foregroundStyle(trip.grams == 0 ? Palette.moss : Palette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// Ring med dagens CO₂ mod budgettet på 8 kg. Sporet er delt i de tre rabatzoner
/// (Forêt ≤ 2 kg, Prairie ≤ 5 kg, Ville ≤ 8 kg), så man kan se, hvor tæt man er på næste grænse.
struct ZoneRing: View {
    let grams: Double
    var locked = false
    @State private var shown = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let budget = dailyBudgetGrams
    private let line: CGFloat = 12
    private let gap = 0.012
    /// Zonernes grænser som brøkdel af budgettet.
    /// Zonerne blegner fra Forêt mod Ville: jo grønnere, jo større rabat.
    private let zones: [(from: Double, to: Double, opacity: Double)] = [
        (0, 2.0 / 8, 0.5),
        (2.0 / 8, 5.0 / 8, 0.28),
        (5.0 / 8, 1, 0.14),
    ]

    private var fraction: Double { min(1, grams / budget) }
    private var progressColor: Color {
        switch grams {
        case ...8000: Palette.nightHighlight
        default: Color(hex: 0xF0A07F)
        }
    }

    var body: some View {
        GeometryReader { g in
            let size = min(g.size.width, g.size.height)
            let r = size / 2 - line / 2
            ZStack {
                ForEach(zones.indices, id: \.self) { i in
                    let z = zones[i]
                    Circle()
                        .trim(from: z.from + gap / 2, to: z.to - gap / 2)
                        .stroke(Palette.nightHighlight.opacity(z.opacity), style: StrokeStyle(lineWidth: line, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
                Circle()
                    .trim(from: 0, to: shown)
                    .stroke(progressColor, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // Grænserne 2 og 5 kg, inde i ringen.
                ForEach([2.0, 5.0], id: \.self) { kg in
                    let a = Angle.degrees(kg / 8 * 360 - 90)
                    Text("\(Int(kg))")
                        .font(Typo.body(11, .semibold, relativeTo: .caption2))
                        .foregroundStyle(.white.opacity(0.75))
                        .position(x: size / 2 + cos(a.radians) * (r - 20), y: size / 2 + sin(a.radians) * (r - 20))
                }
                VStack(spacing: 2) {
                    Text(Format.co2(grams))
                        .font(Typo.display(24, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: grams))
                    Text(L("home.ring.of", Format.co2(budget)))
                        .font(Typo.body(12, .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { animate(to: fraction, duration: 1.2) }
        .onChange(of: fraction) { _, f in animate(to: f, duration: 0.9) }
        .accessibilityElement()
        .accessibilityLabel(L("home.ring.a11y", Format.co2(grams), Format.co2(budget)))
    }

    private func animate(to f: Double, duration: Double) {
        let target = max(0.001, f)
        if reduceMotion { shown = target; return }
        withAnimation(.spring(duration: duration, bounce: 0.2)) { shown = target }
    }
}

/// Lille kort i "Pour toi"-rækken.
struct ForYouCard: View {
    let place: Place
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlacePhoto(place: place, height: 104)
            VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(Typo.display(16, .bold, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Text(place.category.title).font(Typo.body(13, .medium)).foregroundStyle(Palette.inkSecondary)
                if place.organic == true { Image(systemName: "checkmark.seal").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.moss) }
            }
            }
            .padding(12)
        }
        .frame(width: 176, alignment: .leading)
        .background(Palette.surface)
        .clipShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
