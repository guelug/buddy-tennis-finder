import SwiftUI
import SwiftData
import UIKit

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var selectedCategory: ClothingCategory?
    @State private var showingAddItem = false
    @State private var searchText = ""

    private var lang: Language {
        appState.preferredLanguage
    }

    var filteredItems: [ClothingItem] {
        var result = items
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        CategoryChip(title: Strings.closetAll(lang), icon: "square.grid.2x2", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: Strings.categoryDisplayName(category, lang),
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .background(Theme.Colors.cardBackground)

                if filteredItems.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "cabinet.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.gray.opacity(0.5))
                        Text(Strings.closetNoItems(lang))
                            .font(.headline)
                        Text(Strings.closetAddItems(lang))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showingAddItem = true
                        } label: {
                            Label(Strings.closetAddArticle(lang), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.groupedBackground)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: Theme.Spacing.sm) {
                            ForEach(filteredItems) { item in
                                ClosetItemCard(item: item, lang: lang)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteItem(item)
                                        } label: {
                                            Label(Strings.closetDelete(lang), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .background(Theme.Colors.groupedBackground)
                }
            }
            .background(Theme.Colors.groupedBackground.ignoresSafeArea())
            .navigationTitle(Strings.closetTitle(lang))
            .searchable(text: $searchText, prompt: Strings.closetSearch(lang))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                ClothingCaptureView()
            }
        }
    }

    private func deleteItem(_ item: ClothingItem) {
        modelContext.delete(item)
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.Colors.primary : Color.gray.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct ClosetItemCard: View {
    let item: ClothingItem
    let lang: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let image = item.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            } else {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: item.category.icon)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(Strings.categoryDisplayName(item.category, lang))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

#Preview {
    ClosetView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
