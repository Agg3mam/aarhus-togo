import SwiftUI

struct ExploreView: View {
    @Environment(AppNavigation.self) private var nav
    @Environment(LocationProvider.self) private var location
    @Environment(ProfileStore.self) private var profile
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all, foryou, nature, musee, restaurant, activite, organic, secret, excursion, partenaire
        var id: String { rawValue }
        var title: String { L("explore.filter.\(rawValue)") }

        func matches(_ p: Place, _ profile: Profile) -> Bool {
            switch self {
            case .all: true
            case .foryou: profile.score(p) > 0
            case .secret: p.isHiddenGem
            case .nature: p.category == .nature
            case .musee: p.category == .musee
            case .excursion: p.category == .excursion
            case .restaurant: p.category == .restaurant || p.category == .cafe
            case .activite: p.category == .activite
            case .organic: p.organic == true
            case .partenaire: p.category == .partenaire
            }
        }
    }

    private var places: [Place] {
        AppData.shared.allPlaces
            .filter { filter.matches($0, profile.current) }
            .sorted { Geo.km(location.origin, $0.coordinate) < Geo.km(location.origin, $1.coordinate) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: .sectionHeaders) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("explore.title"))
                        .font(Typo.display(34, .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                    Text(L("explore.subtitle"))
                        .font(Typo.body(15))
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(.top, 8)

                Section {
                    ForEach(places) { place in
                        PlaceCard(place: place, km: Geo.roadKm(location.origin, place.coordinate)) { nav.show(place) }
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                } header: {
                    filters
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(.smooth(duration: 0.3), value: filter)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.title)
                            .font(Typo.body(14, .semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundStyle(filter == f ? .white : Palette.ink)
                            .background(filter == f ? Palette.moss : Palette.surface, in: .capsule)
                            .overlay(Capsule().strokeBorder(Palette.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == f ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
        .sensoryFeedback(.selection, trigger: filter)
    }
}

struct PlaceCard: View {
    let place: Place
    let km: Double
    let onMap: () -> Void

    /// Secrets locaux får et mørkt kort: det fortæller, at stedet er et lokalt tip.
    private var secret: Bool { place.isHiddenGem }
    private var titleColor: Color { secret ? .white : Palette.ink }
    private var textColor: Color { secret ? .white.opacity(0.85) : Palette.ink }
    private var metaColor: Color { secret ? Palette.nightHighlight : Palette.inkSecondary }

    private var hasPhoto: Bool { Photos.credits[place.id] != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasPhoto {
                PlacePhoto(place: place, height: 150)
            }
            content.padding(18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secret ? Palette.night : Palette.surface)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: place.category.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(secret ? Palette.night : place.category.iconColor)
                    .frame(width: 48, height: 48)
                    .background(secret ? Palette.nightHighlight : place.category.color, in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(Typo.display(18, .bold, relativeTo: .headline))
                        .foregroundStyle(titleColor)
                    Text(L("explore.meta", place.area, Format.km(km)))
                        .font(Typo.body(13, .medium))
                        .foregroundStyle(metaColor)
                    if secret || place.demo == true || place.organic == true {
                        HStack(spacing: 6) {
                            if place.organic == true { OrganicTag(dark: secret) }
                            if secret { Tag(text: L("category.secret"), fg: Palette.night, bg: Palette.nightHighlight, icon: "sparkles") }
                            if place.demo == true { Tag(text: L("common.example"), fg: Palette.ochre, bg: Palette.ochre.opacity(0.12)) }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            Text(place.summary)
                .font(Typo.body(15))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Label(place.greenTransport.shortTitle, systemImage: place.greenTransport.icon)
                    .font(Typo.body(13, .semibold))
                    .foregroundStyle(metaColor)
                Spacer()
                Button(L("explore.onmap"), systemImage: "map", action: onMap)
                    .font(Typo.body(14, .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .foregroundStyle(secret ? Palette.night : Palette.moss)
                    .background(secret ? Palette.nightHighlight : Palette.mossLight, in: .capsule)
                    .buttonStyle(.plain)
            }
            if hasPhoto { PhotoCreditLink(place: place, dark: secret) }
        }
    }
}
