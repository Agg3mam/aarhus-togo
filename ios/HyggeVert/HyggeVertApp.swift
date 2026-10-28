import SwiftUI

@main
struct HyggeVertApp: App {
    @State private var day = DayModel()
    @State private var location = LocationProvider()
    @State private var nav = AppNavigation()
    @State private var profile = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(day)
                .environment(location)
                .environment(nav)
                .environment(profile)
                .tint(Palette.moss)
        }
    }
}

/// Fanen, der er valgt, og stedet, kortet skal vise ("Voir sur la carte").
@Observable @MainActor
final class AppNavigation {
    enum TabID: Hashable { case home, map, explore, trip, discounts }
    var tab: TabID = .home
    var focus: Place?

    func show(_ place: Place) {
        focus = place
        tab = .map
    }
}

struct RootView: View {
    @Environment(ProfileStore.self) private var profile

    var body: some View {
        if profile.needsOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            MainTabs()
                .transition(.opacity)
        }
    }
}

struct MainTabs: View {
    @Environment(AppNavigation.self) private var nav
    @Environment(DayModel.self) private var day
    /// Skift af sprog tegner hele appen igen.
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.fr.rawValue

    var body: some View {
        @Bindable var nav = nav
        TabView(selection: $nav.tab) {
            Tab(L("tab.home"), systemImage: "house", value: .home) { HomeView() }
            Tab(L("tab.map"), systemImage: "map", value: .map) { MapScreen() }
            Tab(L("tab.explore"), systemImage: "safari", value: .explore) { ExploreView() }
            Tab(L("tab.trip"), systemImage: "leaf.arrow.triangle.circlepath", value: .trip) { TripCalculatorView() }
            Tab(L("tab.discounts"), systemImage: "ticket", value: .discounts) { DiscountsView() }
        }
        .id(lang)
        .sensoryFeedback(.selection, trigger: nav.tab)
        .overlay(alignment: .top) {
            if let c = day.celebration {
                CelebrationBanner(celebration: c)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: c.id) {
                        try? await Task.sleep(for: .seconds(7))
                        withAnimation(.smooth) { day.celebration = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: day.celebration)
    }
}

/// Banner efter "J'y suis !" / "Ajouter à ma journée".
struct CelebrationBanner: View {
    let celebration: DayModel.Celebration
    @Environment(AppNavigation.self) private var nav

    var body: some View {
        let up = celebration.before == nil || (celebration.before!.rawValue > celebration.after.rawValue)
        Button {
            nav.tab = .discounts
        } label: {
            HStack(spacing: 14) {
                LeafBadge(size: 44, grow: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(up ? L("celebrate.unlocked", celebration.after.title) : L("celebrate.added"))
                        .font(Typo.display(17, .bold, relativeTo: .headline))
                        .foregroundStyle(.white)
                    Text(celebration.after.percent > 0 ? L("celebrate.discount", celebration.after.percent)
                                                         : L("celebrate.nodiscount"))
                        .font(Typo.body(14, .medium))
                        .foregroundStyle(Palette.nightHighlight)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Palette.nightHighlight)
            }
            .padding(14)
            .background(Palette.night, in: .rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .sensoryFeedback(.success, trigger: celebration.id)
        .accessibilityLabel(Text(L("celebrate.a11y", celebration.after.title, celebration.after.percent)))
    }
}

/// Et blad, der vokser frem (bruges i stedet for en Lottie-animation).
struct LeafBadge: View {
    var size: CGFloat = 44
    var grow = false
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Palette.moss)
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(Palette.nightHighlight)
                .rotationEffect(.degrees(shown ? 0 : -50), anchor: .bottomLeading)
                .scaleEffect(shown ? 1 : 0.2, anchor: .bottomLeading)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard grow, !reduceMotion else { shown = true; return }
            withAnimation(.spring(duration: 0.9, bounce: 0.5).delay(0.15)) { shown = true }
        }
        .accessibilityHidden(true)
    }
}
