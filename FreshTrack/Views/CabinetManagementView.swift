import SwiftUI
import SwiftData
import UIKit

// MARK: - CabinetManagementView

struct CabinetManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Cabinet.createdDate) private var cabinets: [Cabinet]
    @Query private var allProducts: [Product]

    @State private var showAddCabinet = false
    @State private var editingCabinet: Cabinet?
    @State private var deletingCabinet: DeleteCandidate?

    var body: some View {
        NavigationStack {
            List {
                if cabinets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No cabinets yet")
                            .font(.headline)
                        Text("Add cabinets to organize products\nby location (e.g. Home, Summer House).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(cabinets) { cabinet in
                        CabinetRow(cabinet: cabinet, productCount: productCount(for: cabinet))
                            .contentShape(Rectangle())
                            .onTapGesture { editingCabinet = cabinet }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deletingCabinet = DeleteCandidate(
                                        id: cabinet.id,
                                        name: cabinet.name,
                                        productCount: productCount(for: cabinet)
                                    )
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Cabinets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddCabinet = true } label: {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddCabinet) {
                CabinetFormView(cabinet: nil)
            }
            .sheet(item: $editingCabinet) { cab in
                CabinetFormView(cabinet: cab)
            }
            .confirmationDialog(
                Text("Delete Cabinet?"),
                isPresented: Binding(
                    get: { deletingCabinet != nil },
                    set: { if !$0 { deletingCabinet = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Cabinet & Products", role: .destructive) {
                    if let candidate = deletingCabinet { deleteCabinet(id: candidate.id) }
                }
                Button("Cancel", role: .cancel) { deletingCabinet = nil }
            } message: {
                if let candidate = deletingCabinet {
                    if candidate.productCount > 0 {
                        Text("\"\(candidate.name)\" and \(candidate.productCount) products will be permanently deleted.")
                    } else {
                        Text("\"\(candidate.name)\" will be permanently deleted.")
                    }
                }
            }
        }
    }

    private func productCount(for cabinet: Cabinet) -> Int {
        allProducts.filter { $0.cabinetID == cabinet.id }.count
    }

    private func deleteCabinet(id cabinetID: UUID) {
        let products = allProducts.filter { $0.cabinetID == cabinetID }
        let cabinet = cabinets.first { $0.id == cabinetID }

        if editingCabinet?.id == cabinetID {
            editingCabinet = nil
        }
        deletingCabinet = nil

        for product in products {
            NotificationService.shared.cancelNotifications(for: product)
            if let fn = product.imageFileName { ImageStorageService.delete(fileName: fn) }
            context.delete(product)
        }
        if let cabinet {
            context.delete(cabinet)
        }
        try? context.save()
    }
}

private struct DeleteCandidate: Identifiable {
    let id: UUID
    let name: String
    let productCount: Int
}

// MARK: - CabinetRow

private struct CabinetRow: View {
    let cabinet: Cabinet
    let productCount: Int
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cabinet.color.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: cabinet.icon)
                    .font(.title3)
                    .foregroundStyle(cabinet.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(cabinet.name).font(.body)
                Text("\(productCount) products")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CabinetFormView

struct CabinetFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let cabinet: Cabinet?

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

    init(cabinet: Cabinet?) {
        self.cabinet = cabinet
        _name          = State(initialValue: cabinet?.name ?? "")
        _selectedIcon  = State(initialValue: cabinet?.icon ?? "refrigerator")
        _selectedColor = State(initialValue: cabinet?.colorHex ?? "34C759")
    }

    private let icons = [
        "refrigerator", "house", "building.2", "archivebox",
        "fork.knife", "cart", "basket", "tray.full",
        "tent", "car.fill", "briefcase.fill", "star.fill"
    ]

    private let presetColors: [(hex: String, name: String)] = [
        ("34C759", "Green"),
        ("007AFF", "Blue"),
        ("FF9500", "Orange"),
        ("FF3B30", "Red"),
        ("AF52DE", "Purple"),
        ("5AC8FA", "Teal"),
        ("FF2D55", "Pink"),
        ("A2845E", "Brown")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Home, Summer House", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedIcon == icon
                                              ? (Color(hex: selectedColor) ?? .teal).opacity(0.2)
                                              : Color(.systemGray5))
                                        .frame(height: 44)
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedIcon == icon
                                                         ? (Color(hex: selectedColor) ?? .teal)
                                                         : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(presetColors, id: \.hex) { preset in
                            Button {
                                selectedColor = preset.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.hex) ?? .teal)
                                        .frame(width: 34, height: 34)
                                    if selectedColor == preset.hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Preview
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill((Color(hex: selectedColor) ?? .teal).opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .font(.title3)
                                .foregroundStyle(Color(hex: selectedColor) ?? .teal)
                        }
                        Text(name.isEmpty ? "Cabinet Name" : name)
                            .foregroundStyle(name.isEmpty ? .tertiary : .primary)
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle(cabinet == nil ? "New Cabinet" : "Edit Cabinet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(cabinet == nil ? "Add" : "Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = cabinet {
            existing.name     = trimmed
            existing.icon     = selectedIcon
            existing.colorHex = selectedColor
        } else {
            context.insert(Cabinet(name: trimmed, icon: selectedIcon, colorHex: selectedColor))
        }
        dismiss()
    }
}

#Preview {
    CabinetManagementView()
        .modelContainer(for: Cabinet.self, inMemory: true)
}
