import SwiftUI

/// CO₂-beregner: vælg rejseform og distance, se udledningen mod bilen og rabatniveauet bagefter.
struct TripCalculatorView: View {
    @Environment(DayModel.self) private var day
    @State private var mode: Mode = .bike
    @State private var km = 5.0
    @State private var added = 0

    private var grams: Double { AppData.shared.grams(mode, km: km) }
    private var carGrams: Double { AppData.shared.grams(.car, km: km) }
    private var after: Level { day.level(adding: grams, mode: mode) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("trip.title"))
                        .font(Typo.display(34, .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                    Text(L("trip.subtitle")).font(Typo.body(15)).foregroundStyle(Palette.inkSecondary)
                }
                .padding(.top, 8)

                modePicker
                distanceCard
                resultCard

                Button {
                    day.add(Trip(title: L("trip.free", Format.km(km)), mode: mode, km: km, grams: grams))
                    added += 1
                } label: {
                    Label(L("trip.add"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.pill)
                .sensoryFeedback(.success, trigger: added)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
    }

    private var modePicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(Mode.calculator) { m in
                Button {
                    withAnimation(.snappy) { mode = m }
                } label: {
                    VStack(spacing: 6) {
                        if m.isBike && mode == m {
                            LeafBadge(size: 36, grow: true).id(m)
                        } else {
                            Image(systemName: m.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 36, height: 36)
                        }
                        Text(m.shortTitle)
                            .font(Typo.body(13, .semibold, relativeTo: .caption))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 76)
                    .foregroundStyle(mode == m ? (m == .car ? .white : .white) : (m == .car ? Palette.car : Palette.ink))
                    .background(mode == m ? (m == .car ? Palette.car : Palette.moss) : Palette.surface, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var distanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("trip.distance")).font(Typo.body(15, .semibold)).foregroundStyle(Palette.inkSecondary)
                Spacer()
                Text(Format.km(km))
                    .font(Typo.display(24, .heavy))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: km))
            }
            Slider(value: $km, in: 0.5...60, step: 0.5) {
                Text(L("trip.distance"))
            } minimumValueLabel: {
                Text("0,5").font(Typo.body(12)).foregroundStyle(Palette.inkSecondary)
            } maximumValueLabel: {
                Text("60").font(Typo.body(12)).foregroundStyle(Palette.inkSecondary)
            }
            .tint(Palette.moss)
            HStack(spacing: 8) {
                ForEach([2.0, 5, 10, 25, 44], id: \.self) { v in
                    Button(Format.km(v)) { withAnimation(.snappy) { km = v } }
                        .font(Typo.body(13, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(km == v ? .white : Palette.ink)
                        .background(km == v ? Palette.fjord : Palette.background, in: .capsule)
                        .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.co2(grams))
                    .font(Typo.display(40, .heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: grams))
                Text(L("trip.co2")).font(Typo.body(14, .medium)).foregroundStyle(.white.opacity(0.85))
            }
            Bar(label: mode.title, grams: grams, max: carGrams, color: mode == .car ? Color(hex: 0xF0A07F) : Palette.nightHighlight)
            if mode != .car {
                Bar(label: Mode.car.title, grams: carGrams, max: carGrams, color: Color(hex: 0xF0A07F))
                Text(L("trip.saved", Format.co2(carGrams - grams), Int(((carGrams - grams) / carGrams * 100).rounded())))
                    .font(Typo.body(15, .semibold))
                    .foregroundStyle(Palette.nightHighlight)
            }
            Divider().overlay(.white.opacity(0.15))
            HStack(spacing: 12) {
                Image(systemName: after.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.night)
                    .frame(width: 44, height: 44)
                    .background(Palette.nightHighlight, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("trip.after")).font(Typo.body(13)).foregroundStyle(.white.opacity(0.85))
                    Text(after.percent > 0 ? "\(after.title), −\(after.percent) %" : after.title)
                        .font(Typo.display(18, .bold, relativeTo: .headline))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(L("trip.day.total", Format.co2(day.totalGrams + grams)))
                    .font(Typo.body(13, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.trailing)
            }
        }
        .card(Palette.night, radius: 28)
        .animation(.smooth, value: grams)
    }
}

struct Bar: View {
    let label: String
    let grams: Double
    let max: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(Typo.body(13, .semibold)).foregroundStyle(.white)
                Spacer()
                Text(Format.co2(grams)).font(Typo.body(13, .semibold)).foregroundStyle(.white)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(color).frame(width: Swift.max(8, g.size.width * (max > 0 ? grams / max : 0)))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
    }
}
