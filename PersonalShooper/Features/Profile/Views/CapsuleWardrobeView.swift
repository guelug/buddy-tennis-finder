import SwiftUI
import SwiftData

/// "Capsule wardrobe" — crosses the user's palette, silhouette and current closet to show the
/// timeless essentials, each in an on-palette color with a fit note, split into pieces still missing
/// versus slots they already have covered.
struct CapsuleWardrobeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var closetItems: [ClothingItem]
    @Query private var shoppingItems: [ShoppingItem]
    @State private var showingList = false

    private var lang: Language { appState.preferredLanguage }
    private var isSpanish: Bool { lang == .spanish }

    private var ownedCategoryCounts: [ClothingCategory: Int] {
        Dictionary(grouping: closetItems, by: \.category).mapValues(\.count)
    }

    private var pieces: [CapsuleWardrobeService.CapsulePiece] {
        CapsuleWardrobeService.generate(
            gender: appState.currentUser?.personalStylingProfile.genderIdentity,
            palette: appState.currentUser?.personalPalette,
            bodyShape: appState.currentUser?.personalStylingProfile.bodyShape,
            ownedCategoryCounts: ownedCategoryCounts,
            language: lang
        )
    }

    private var missing: [CapsuleWardrobeService.CapsulePiece] { pieces.filter { !$0.alreadyInCloset } }
    private var covered: [CapsuleWardrobeService.CapsulePiece] { pieces.filter(\.alreadyInCloset) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header

                if !missing.isEmpty {
                    section(
                        title: isSpanish ? "Prioriza estas piezas" : "Prioritize these pieces",
                        subtitle: isSpanish ? "Huecos en tu cápsula" : "Gaps in your capsule",
                        pieces: missing,
                        highlight: true
                    )
                }

                if !covered.isEmpty {
                    section(
                        title: isSpanish ? "Ya tienes la base" : "You've got the base",
                        subtitle: isSpanish ? "Slots cubiertos en tu armario" : "Slots covered in your closet",
                        pieces: covered,
                        highlight: false
                    )
                }
            }
            .padding()
        }
        .background(Theme.Colors.groupedBackground.ignoresSafeArea())
        .navigationTitle(isSpanish ? "Armario cápsula" : "Capsule Wardrobe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingList = true } label: {
                    Image(systemName: "cart")
                }
            }
        }
        .sheet(isPresented: $showingList) {
            ShoppingListView()
        }
    }

    private func isOnList(_ piece: CapsuleWardrobeService.CapsulePiece) -> Bool {
        shoppingItems.contains { $0.title == piece.title && !$0.isPurchased }
    }

    private func addToList(_ piece: CapsuleWardrobeService.CapsulePiece) {
        guard !isOnList(piece) else { return }
        let item = ShoppingItem(
            title: piece.title,
            categoryRaw: piece.category.rawValue,
            colorHint: piece.color?.name,
            reason: piece.reason
        )
        modelContext.insert(item)
        try? modelContext.save()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isSpanish ? "Tu cápsula esencial" : "Your essential capsule")
                .font(.largeTitle.weight(.bold))
            Text(isSpanish
                 ? "Las piezas clave en tu paleta y tu silueta para vestir bien con menos."
                 : "The key pieces in your palette and silhouette to dress well with less.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(title: String, subtitle: String, pieces: [CapsuleWardrobeService.CapsulePiece], highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            ForEach(pieces) { piece in
                pieceRow(piece, highlight: highlight)
            }
        }
    }

    private func pieceRow(_ piece: CapsuleWardrobeService.CapsulePiece, highlight: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill((piece.color?.color ?? Color(.systemGray4)))
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.black.opacity(0.08)))
                Image(systemName: piece.category.icon)
                    .font(.caption)
                    .foregroundStyle(iconTint(for: piece.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(piece.title)
                        .font(.subheadline.weight(.semibold))
                    if piece.alreadyInCloset {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                Text(piece.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if highlight {
                    Button {
                        withAnimation { addToList(piece) }
                    } label: {
                        Label(
                            isOnList(piece) ? (isSpanish ? "En la lista" : "On the list") : (isSpanish ? "Añadir a la lista" : "Add to list"),
                            systemImage: isOnList(piece) ? "checkmark.circle.fill" : "cart.badge.plus"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOnList(piece) ? .green : Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isOnList(piece))
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .strokeBorder(highlight ? Theme.Colors.primary.opacity(0.35) : .clear, lineWidth: 1)
        )
    }

    /// Black icon on light swatches, white on dark ones, so the category glyph stays legible.
    private func iconTint(for color: CodableColor?) -> Color {
        guard let color else { return .white.opacity(0.95) }
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.6 ? .black.opacity(0.6) : .white.opacity(0.95)
    }
}
