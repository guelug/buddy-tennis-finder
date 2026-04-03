import SwiftUI
import SwiftData
import UIKit

struct ClosetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @State private var selectedCategory: ClothingCategory?
    @State private var showingAddItem = false
    @State private var searchText = ""

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
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        CategoryChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }

                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.displayName,
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
                        Text("No Items")
                            .font(.headline)
                        Text("Add clothing items to your closet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            showingAddItem = true
                        } label: {
                            Label("Add Item", systemImage: "plus")
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
                                ClosetItemCard(item: item)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteItem(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
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
            .navigationTitle("My Closet")
            .searchable(text: $searchText, prompt: "Search closet")
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
                AddClothingItemView()
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

            Text(item.category.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: .black.opacity(0.05), radius: 2)
    }
}

struct AddClothingItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedCategory: ClothingCategory = .tops
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var photoPickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var colorTags: [String] = []
    @State private var newColorTag = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        photoPickerSource = .camera
                        showPhotoPicker = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }

                    Button {
                        photoPickerSource = .photoLibrary
                        showPhotoPicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                }

                Section("Details") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ClothingCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section("Color Tags") {
                    FlowLayout(spacing: 4) {
                        ForEach(colorTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.primary.opacity(0.1))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    colorTags.removeAll { $0 == tag }
                                }
                        }
                    }

                    HStack {
                        TextField("Add color", text: $newColorTag)
                        Button("Add") {
                            if !newColorTag.isEmpty {
                                colorTags.append(newColorTag)
                                newColorTag = ""
                            }
                        }
                        .disabled(newColorTag.isEmpty)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: photoPickerSource) { image in
                    selectedImage = image
                }
            }
        }
    }

    private func saveItem() {
        let item = ClothingItem(
            name: name,
            category: selectedCategory,
            image: selectedImage,
            colorTags: colorTags
        )
        modelContext.insert(item)
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage?) -> Void

        init(onImageSelected: @escaping (UIImage?) -> Void) {
            self.onImageSelected = onImageSelected
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            onImageSelected(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    ClosetView()
        .modelContainer(for: ClothingItem.self, inMemory: true)
}
