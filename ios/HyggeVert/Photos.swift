import SwiftUI
import UIKit

/// Frit licenserede fotos fra Wikimedia Commons (hentet med scripts/fetch-photos.mjs).
struct PhotoCredit: Decodable {
    let file: String
    let author: String
    let license: String
    let url: String
}

enum Photos {
    static let credits: [String: PhotoCredit] = {
        guard let url = Bundle.main.url(forResource: "photo-credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: PhotoCredit].self, from: data)) ?? [:]
    }()

    @MainActor private static var cache: [String: UIImage] = [:]

    @MainActor static func image(for id: String) -> UIImage? {
        guard credits[id] != nil else { return nil }
        if let img = cache[id] { return img }
        let img = UIImage(named: "\(id).jpg")
        cache[id] = img
        return img
    }
}

/// Stedets foto, eller kategoriens farve og ikon, hvis der ikke findes et frit foto.
struct PlacePhoto: View {
    let place: Place
    var height: CGFloat = 160

    var body: some View {
        Group {
            if let img = Photos.image(for: place.id) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    place.category.color
                    Image(systemName: place.category.icon)
                        .font(.system(size: height * 0.3, weight: .light))
                        .foregroundStyle(place.category.iconColor.opacity(0.85))
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// "Photo : Jon Wickmann, CC BY 3.0" – fører til fotoets side på Wikimedia Commons (krav i licensen).
struct PhotoCreditLink: View {
    let place: Place
    var dark = false

    var body: some View {
        if let c = Photos.credits[place.id], let url = URL(string: c.url) {
            Link(destination: url) {
                Text(c.author.isEmpty ? L("photo.credit.noauthor", c.license) : L("photo.credit", c.author, c.license))
                    .font(Typo.body(12, .medium, relativeTo: .caption))
                    .foregroundStyle(dark ? .white.opacity(0.8) : Palette.inkSecondary)
                    .underline()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .accessibilityHint(L("photo.credit.hint"))
        }
    }
}
