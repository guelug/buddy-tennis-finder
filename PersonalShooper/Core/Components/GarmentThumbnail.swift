import SwiftUI

/// Reusable garment thumbnail: shows the whole item (fit, never cropped) on an adaptive tile —
/// transparent-friendly when the garment has a background-removed cutout, white otherwise — so
/// closets, looks and capsules render consistently in both light and dark mode.
struct GarmentThumbnail: View {
    let item: ClothingItem
    var size: CGFloat = 70
    var corner: CGFloat = 10

    var body: some View {
        Group {
            if let image = item.displayImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
                    .frame(width: size, height: size)
                    .background(item.hasCutout ? Color(.systemBackground) : Color.white)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(Image(systemName: item.category.icon).foregroundStyle(.secondary))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}
