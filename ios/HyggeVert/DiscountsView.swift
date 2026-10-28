import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR-kupon med dagens rabat, de tre niveauer og partnerne.
struct DiscountsView: View {
    @Environment(DayModel.self) private var day
    @Environment(AppNavigation.self) private var nav

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("disc.title"))
                        .font(Typo.display(34, .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                    Text(L("disc.subtitle")).font(Typo.body(15)).foregroundStyle(Palette.inkSecondary)
                }
                .padding(.top, 8)

                coupon
                levels
                partners
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Palette.background)
    }

    private var code: String {
        let d = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.omitted))
        return "AARHUSTOGO-\(d)-\(day.level?.percent ?? 0)"
    }

    private var coupon: some View {
        let level = day.level
        let pct = level?.percent ?? 0
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("disc.today")).font(Typo.body(14, .semibold)).foregroundStyle(Palette.nightHighlight)
                    Text(pct > 0 ? "−\(pct) %" : "0 %")
                        .font(Typo.display(48, .heavy, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(pct)))
                    Text(level?.title ?? L("home.level.locked"))
                        .font(Typo.body(15, .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: level?.icon ?? "lock")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Palette.nightHighlight)
            }

            ZStack {
                QRCode(text: code)
                    .frame(width: 180, height: 180)
                    .padding(14)
                    .background(.white, in: .rect(cornerRadius: 20))
                    .blur(radius: pct > 0 ? 0 : 8)
                    .opacity(pct > 0 ? 1 : 0.35)
                if pct == 0 {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                        Text(day.hasTrips ? L("disc.over") : L("disc.locked"))
                            .font(Typo.body(14, .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(pct > 0 ? L("disc.qr.a11y", pct) : L("disc.locked"))

            Text(pct > 0 ? code : L("disc.hint"))
                .font(Typo.body(13, .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            if !day.hasTrips {
                Button(L("home.trips.cta"), systemImage: "map") { nav.tab = .map }
                    .buttonStyle(.pill(.secondary))
            }
        }
        .card(Palette.night, radius: 28)
        .animation(.spring(duration: 0.6, bounce: 0.3), value: pct)
    }

    private var levels: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("disc.levels"))
            Text(L("disc.nocar")).font(Typo.body(14)).foregroundStyle(Palette.inkSecondary)
            VStack(spacing: 10) {
                ForEach([Level.foret, .prairie, .ville]) { l in
                    let current = day.level == l
                    HStack(spacing: 14) {
                        Image(systemName: l.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(current ? .white : Palette.moss)
                            .frame(width: 46, height: 46)
                            .background(current ? Palette.moss : Palette.mossLight, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(l.title).font(Typo.display(17, .bold, relativeTo: .headline)).foregroundStyle(Palette.ink)
                                if current { Tag(text: L("disc.current"), fg: .white, bg: Palette.moss) }
                            }
                            Text(L("disc.rule.\(["foret", "prairie", "ville"][l.rawValue])")).font(Typo.body(14)).foregroundStyle(Palette.inkSecondary)
                        }
                        Spacer()
                        Text("−\(l.percent) %").font(Typo.display(20, .heavy)).foregroundStyle(Palette.moss)
                    }
                    .card()
                    .overlay {
                        if current { RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.moss, lineWidth: 2) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var partners: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("disc.partners"))
            VStack(spacing: 0) {
                ForEach(AppData.shared.partners) { p in
                    Button { nav.show(p.asPlace) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: p.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Palette.ochre)
                                .frame(width: 44, height: 44)
                                .background(Palette.ochre.opacity(0.12), in: .circle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Typo.body(15, .semibold)).foregroundStyle(Palette.ink)
                                Text(p.asPlace.summary).font(Typo.body(13)).foregroundStyle(Palette.inkSecondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "map").foregroundStyle(Palette.moss)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if p.id != AppData.shared.partners.last?.id { Divider().overlay(Palette.hairline).padding(.leading, 74) }
                }
            }
            .padding(.vertical, 6)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            Text(L("disc.partners.note")).font(Typo.body(13)).foregroundStyle(Palette.inkSecondary)
        }
    }
}

struct QRCode: View {
    let text: String
    var body: some View {
        if let img = Self.make(text) {
            Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
        }
    }

    static func make(_ s: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: .init(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
