import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.addedDate, order: .reverse) private var items: [ShoppingItem]
    @Query(sort: \Cabinet.createdDate) private var allCabinets: [Cabinet]

    @State private var newItemName = ""
    @State private var selectedItem: ShoppingItem? = nil
    @State private var showClearConfirm = false

    private var pending: [ShoppingItem] { items.filter { !$0.isBought } }

    var body: some View {
        NavigationStack {
            List {
                // Add new item inline
                Section {
                    HStack {
                        TextField("Add item…", text: $newItemName)
                            .onSubmit { addManualItem() }
                        if !newItemName.isEmpty {
                            Button { addManualItem() } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if pending.isEmpty {
                    ContentUnavailableView(
                        "Shopping list is empty",
                        systemImage: "cart",
                        description: Text("Consumed or expired products appear here automatically.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("To Buy (\(pending.count))") {
                        ForEach(pending) { item in
                            ShoppingRowView(item: item) {
                                selectedItem = item
                            }
                        }
                        .onDelete { deleteItems($0, from: pending) }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !pending.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear Shopping List",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All Items", role: .destructive) {
                    withAnimation { pending.forEach { context.delete($0) } }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(pending.count) items.")
            }
            .sheet(item: $selectedItem) { item in
                AddToFridgeSheet(item: item, cabinets: allCabinets) { expiryDate, cabinetID in
                    addToFridge(item: item, expiryDate: expiryDate, cabinetID: cabinetID)
                }
            }
        }
    }

    // MARK: - Actions

    private func addManualItem() {
        let name = newItemName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let alreadyExists = items.contains {
            !$0.isBought && $0.name.lowercased() == name.lowercased()
        }
        guard !alreadyExists else { newItemName = ""; return }
        context.insert(ShoppingItem(name: name))
        newItemName = ""
    }

    private func deleteItems(_ offsets: IndexSet, from list: [ShoppingItem]) {
        offsets.forEach { context.delete(list[$0]) }
    }

    private func addToFridge(item: ShoppingItem, expiryDate: Date, cabinetID: UUID?) {
        let cabinetName = allCabinets.first(where: { $0.id == cabinetID })?.name
        let product = Product(
            name: item.name,
            brand: item.brand ?? "",
            category: item.category,
            expiryDate: expiryDate,
            barcode: item.barcode,
            notes: item.notes ?? "",
            imageFileName: item.imageFileName,
            cabinetID: cabinetID
        )
        product.ingredients = item.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? item.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        product.allergens = item.allergens?.compactMap { allergen in
            let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        context.insert(product)
        NotificationService.shared.scheduleNotifications(for: product, cabinetName: cabinetName)
        context.delete(item)
        selectedItem = nil
    }
}

// MARK: - Add To Fridge Sheet

private struct AddToFridgeSheet: View {
    let item: ShoppingItem
    let cabinets: [Cabinet]
    let onConfirm: (Date, UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expiryDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var selectedCabinetID: UUID? = nil
    @State private var showExpiryScanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text(item.category.icon).font(.largeTitle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.headline)
                            Text(item.category.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if !cabinets.isEmpty {
                        Picker("Cabinet", selection: $selectedCabinetID) {
                            Text("None").tag(UUID?.none)
                            ForEach(cabinets) { cabinet in
                                Label {
                                    Text(cabinet.name)
                                } icon: {
                                    Image(systemName: cabinet.icon)
                                }
                                .tag(Optional(cabinet.id))
                            }
                        }
                    }
                }

                Section("Expiry Date") {
                    Button {
                        showExpiryScanner = true
                    } label: {
                        Label("Scan Expiry Date", systemImage: "text.viewfinder")
                    }

                    DatePicker("Expires on", selection: $expiryDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.teal)

                    HStack(spacing: 8) {
                        ForEach([3, 7, 14, 30], id: \.self) { days in
                            Button("+\(days)d") {
                                expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .onAppear {
                selectedCabinetID = cabinets.first?.id
            }
            .sheet(isPresented: $showExpiryScanner) {
                ExpiryDateScannerSheet(isPresented: $showExpiryScanner) { date in
                    expiryDate = date
                }
            }
            .navigationTitle("Add to Fridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onConfirm(expiryDate, selectedCabinetID)
                    } label: {
                        Label("Add to Fridge", systemImage: "refrigerator").fontWeight(.semibold)
                    }
                    .tint(.teal)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Row

private struct ShoppingRowView: View {
    let item: ShoppingItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "circle")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
                ProductThumbnailView(fileName: item.imageFileName, fallbackIcon: item.category.icon)
                Text(item.name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: [ShoppingItem.self, Product.self], inMemory: true)
}
