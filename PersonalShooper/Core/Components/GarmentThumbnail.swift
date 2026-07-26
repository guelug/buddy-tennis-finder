import SwiftUI

/// Reusable garment thumbnail that shows the full transparent garment without a photo backdrop.
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
                    .background(Color.clear)
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
