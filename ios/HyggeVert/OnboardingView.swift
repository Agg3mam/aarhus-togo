import SwiftUI

/// Spørgeskemaet ved første start: sprog og navn, interesser, budget, alder og rejsefølge.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var store
    @AppStorage(AppLanguage.storageKey) private var lang = AppLanguage.fr.rawValue
    @State private var draft = Profile()
    @State private var step = 0
    @FocusState private var nameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let questions = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if step > 0 { progress.padding(.top, 12) }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: welcome
                    case 1: interests
                    case 2: budget
                    case 3: age
                    default: company
                    }
                }
                .padding(.top, step == 0 ? 40 : 28)
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                  removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background(Palette.night.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.smooth(duration: 0.35), value: step)
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: Trin

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            LeafBadge(size: 64, grow: true)
            Text(L("onb.welcome.title"))
                .font(Typo.display(38, .heavy, relativeTo: .largeTitle))
                .foregroundStyle(.white)
            Text(L("onb.welcome.sub"))
                .font(Typo.body(17))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text(L("settings.language")).font(Typo.body(14, .semibold)).foregroundStyle(Palette.nightHighlight)
                HStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { l in
                        Choice(title: l.name, icon: nil, selected: lang == l.rawValue) { lang = l.rawValue }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L("onb.name")).font(Typo.body(14, .semibold)).foregroundStyle(Palette.nightHighlight)
                TextField("", text: $draft.name, prompt: Text(L("onb.name.placeholder")).foregroundStyle(.white.opacity(0.55)))
                    .font(Typo.body(18, .medium))
                    .foregroundStyle(.white)
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($nameFocused)
                    .onSubmit { next() }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 52)
                    .background(.white.opacity(0.08), in: .capsule)
                    .overlay(Capsule().strokeBorder(nameFocused ? Palette.nightHighlight : .white.opacity(0.15), lineWidth: 1.5))
            }
        }
    }

    private var interests: some View {
        VStack(alignment: .leading, spacing: 22) {
            title(L("onb.interests"), sub: L("onb.interests.sub"))
            FlowLayout(spacing: 10) {
                ForEach(Profile.Interest.allCases) { i in
                    Choice(title: i.title, icon: i.icon, selected: draft.interests.contains(i)) {
                        if draft.interests.contains(i) { draft.interests.remove(i) } else { draft.interests.insert(i) }
                    }
                }
            }
        }
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: 22) {
            title(L("onb.budget"), sub: L("onb.budget.sub"))
            BigValue(text: draft.budgetEuro >= 5000 ? "5 000 € +" : "\(Int(draft.budgetEuro).formatted(.number.locale(Format.locale))) €")
            Slider(value: $draft.budgetEuro, in: 0...5000, step: 50) {
                Text(L("onb.budget"))
            } minimumValueLabel: {
                Text("0 €").font(Typo.body(13)).foregroundStyle(.white.opacity(0.8))
            } maximumValueLabel: {
                Text("5 000 €").font(Typo.body(13)).foregroundStyle(.white.opacity(0.8))
            }
            .tint(Palette.nightHighlight)
        }
    }

    private var age: some View {
        VStack(alignment: .leading, spacing: 22) {
            title(L("onb.age"), sub: nil)
            BigValue(text: L("onb.age.value", Int(draft.age)))
            Slider(value: $draft.age, in: 15...70, step: 1) {
                Text(L("onb.age"))
            } minimumValueLabel: {
                Text("15").font(Typo.body(13)).foregroundStyle(.white.opacity(0.8))
            } maximumValueLabel: {
                Text("70").font(Typo.body(13)).foregroundStyle(.white.opacity(0.8))
            }
            .tint(Palette.nightHighlight)
        }
    }

    private var company: some View {
        VStack(alignment: .leading, spacing: 22) {
            title(L("onb.company"), sub: nil)
            VStack(spacing: 10) {
                ForEach(Profile.Company.allCases) { c in
                    Choice(title: c.title, icon: c.icon, selected: draft.company == c, wide: true) { draft.company = c }
                }
            }
        }
    }

    // MARK: Byggeklodser

    private func title(_ t: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t)
                .font(Typo.display(32, .heavy, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let sub {
                Text(sub).font(Typo.body(16)).foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    /// Fire spørgsmål i rækkefølge, så trinindikatoren viser, hvor langt man er.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(1...questions, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Palette.nightHighlight : .white.opacity(0.15))
                        .frame(height: 5)
                }
            }
            HStack {
                Button { step -= 1 } label: {
                    Label(L("go.back.info"), systemImage: "chevron.left")
                        .font(Typo.body(15, .semibold))
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Palette.nightHighlight)
                Spacer()
                Text(L("onb.step", step, questions)).font(Typo.body(13, .medium)).foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 && step < questions {
                Button(L("onb.skip")) { next() }
                    .font(Typo.body(16, .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(minWidth: 88, minHeight: 52)
            }
            Button {
                next()
            } label: {
                Text(step == questions ? L("onb.done") : L("onb.next"))
                    .font(Typo.body(17, .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(Palette.night)
                    .background(Palette.nightHighlight, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private func next() {
        nameFocused = false
        if step < questions { step += 1 } else { withAnimation(.smooth) { store.save(draft) } }
    }
}

/// Valgknap i spørgeskemaet (mindst 52 pt høj).
private struct Choice: View {
    let title: String
    let icon: String?
    let selected: Bool
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 17, weight: .semibold)) }
                Text(title).font(Typo.body(17, .semibold))
                if wide { Spacer(minLength: 0) }
                if selected && wide { Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)) }
            }
            .padding(.horizontal, 20)
            .frame(minHeight: 52)
            .frame(maxWidth: wide ? .infinity : nil)
            .foregroundStyle(selected ? Palette.night : .white)
            .background(selected ? Palette.nightHighlight : .white.opacity(0.08), in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? .clear : .white.opacity(0.15), lineWidth: 1))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct BigValue: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.display(56, .heavy, relativeTo: .largeTitle))
            .foregroundStyle(Palette.nightHighlight)
            .contentTransition(.numericText())
            .animation(.snappy, value: text)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Lægger valgknapperne i rækker, der brydes efter behov.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal.width ?? .infinity, subviews)
        let h = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        var cur: [Int] = [], w: CGFloat = 0, h: CGFloat = 0
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if !cur.isEmpty && w + spacing + s.width > width {
                rows.append((cur, w, h)); cur = []; w = 0; h = 0
            }
            w += (cur.isEmpty ? 0 : spacing) + s.width
            h = max(h, s.height)
            cur.append(i)
        }
        if !cur.isEmpty { rows.append((cur, w, h)) }
        return rows
    }
}
