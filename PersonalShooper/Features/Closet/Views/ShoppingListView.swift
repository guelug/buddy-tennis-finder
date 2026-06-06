import SwiftUI
import SwiftData

/// The user's shopping list — pieces to buy, typically added from the capsule plan. Check items off
/// as you buy them; purchased items drop to the bottom.
struct ShoppingListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt, order: .reverse) private var items: [ShoppingItem]

    private var isSpanish: Bool { appState.preferredLanguage == .spanish }

    private var pending: [ShoppingItem] { items.filter { !$0.isPurchased } }
    private var purchased: [ShoppingItem] { items.filter(\.isPurchased) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label(isSpanish ? "Lista vacía" : "Empty list", systemImage: "cart")
                    } description: {
                        Text(isSpanish ? "Añade piezas desde tu armario cápsula para no olvidar qué te falta." : "Add pieces from your capsule wardrobe so you don't forget what's missing.")
                    }
                } else {
                    List {
                        if !pending.isEmpty {
                            Section(isSpanish ? "Por comprar" : "To buy") {
                                ForEach(pending) { row($0) }
                            }
                        }
                        if !purchased.isEmpty {
                            Section(isSpanish ? "Comprado" : "Purchased") {
                                ForEach(purchased) { row($0) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isSpanish ? "Lista de compra" : "Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) { clearPurchased() } label: {
                                Label(isSpanish ? "Borrar comprados" : "Clear purchased", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            withAnimation { item.isPurchased.toggle(); try? modelContext.save() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .green : .secondary)
                if let category = item.category {
                    Image(systemName: category.icon).foregroundStyle(Theme.Colors.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    if let color = item.colorHint, !color.isEmpty {
                        Text(color).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                modelContext.delete(item); try? modelContext.save()
            } label: {
                Label(isSpanish ? "Eliminar" : "Delete", systemImage: "trash")
            }
        }
    }

    private func clearPurchased() {
        for item in purchased { modelContext.delete(item) }
        try? modelContext.save()
    }
}
