import SwiftUI
import SwiftData
import StoreKit

struct ProductListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @Query private var allProducts: [Product]
    @Query private var allShoppingItems: [ShoppingItem]

    @StateObject private var store = ProductStore()

    @State private var showAddProduct = false
    @State private var showStats = false
    @State private var sortOption: SortOption = .expiryAsc
    @State private var filterOption: FilterOption = .all
    @State private var searchText = ""
    @State private var showConsumed = false
    @State private var showShoppingList = false
    @State private var editingProduct: Product? = nil
    @State private var reAddingProduct: Product? = nil

    @AppStorage("consumedCount") private var consumedCount = 0
    @AppStorage("reviewRequested") private var reviewRequested = false

    private var activeProducts: [Product] { allProducts.filter { !$0.isConsumed } }
    private var consumedProducts: [Product] { allProducts.filter { $0.isConsumed } }

    private var filteredProducts: [Product] {
        let sorted = store.sorted(allProducts, by: sortOption, filter: filterOption)
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var stats: StoreStats { store.stats(from: allProducts) }

    var body: some View {
        NavigationStack {
            // Always show list (empty state lives inside list now)
            mainList
            .navigationTitle("FreshKeep")
            .searchable(text: $searchText, prompt: "Search products…")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddProduct) { AddProductView() }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showShoppingList) { ShoppingListView() }
            .sheet(item: $editingProduct) { EditProductView(product: $0) }
            .sheet(item: $reAddingProduct) { product in
                ReAddSheet(product: product) { expiryDate in
                    reAddToFridge(product, expiryDate: expiryDate)
                }
            }
            .onAppear {
                store.syncExpiredToShoppingList(
                    products: allProducts,
                    shoppingItems: allShoppingItems,
                    context: context
                )
            }
        }
    }

    // MARK: - Main List

    private var mainList: some View {
        List {
            // Alert banner
            if stats.alertCount > 0 {
                AlertBannerView(count: stats.alertCount)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FilterOption.allCases, id: \.self) { opt in
                        FilterChip(title: opt.rawValue, isSelected: filterOption == opt) {
                            filterOption = opt
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

            // Active products or empty state
            if activeProducts.isEmpty {
                EmptyStateRow { showAddProduct = true }
                    .listRowBackground(Color.clear)
            } else {
                if filteredProducts.isEmpty {
                    Text("No products match this filter.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredProducts) { product in
                        ProductRowView(
                            product: product,
                            onConsume: {
                                store.markConsumed(product, context: context)
                                consumedCount += 1
                                maybeRequestReview()
                            },
                            onDelete: { store.delete(product, context: context) },
                            onEdit:   { editingProduct = product }
                        )
                    }
                }
            }

            // Used Items — always visible
            Section {
                Button {
                    withAnimation { showConsumed.toggle() }
                } label: {
                    HStack {
                        Image(systemName: showConsumed ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(consumedProducts.isEmpty
                             ? "No used items yet"
                             : (showConsumed ? "Hide Used Items" : "Used Items (\(consumedProducts.count))"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(consumedProducts.isEmpty)

                if showConsumed {
                    ForEach(consumedProducts) { product in
                        UsedItemRow(product: product) {
                            reAddingProduct = product
                        } onRemove: {
                            context.delete(product)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: filterOption)
        .animation(.default, value: sortOption)
    }

    // MARK: - Review

    private func maybeRequestReview() {
        guard !reviewRequested, consumedCount >= 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            requestReview()
            reviewRequested = true
        }
    }

    // MARK: - Re-add to fridge (smart date)

    private func reAddToFridge(_ product: Product, expiryDate: Date) {
        let newProduct = Product(
            name: product.name,
            brand: product.brand,
            category: product.category,
            expiryDate: expiryDate,
            barcode: product.barcode,
            quantity: 1,
            price: product.price
        )
        store.add(newProduct, context: context)
        context.delete(product)
        reAddingProduct = nil
    }

    private func suggestedExpiryDate(for product: Product) -> Date {
        let calendar = Calendar.current
        let originalDays = calendar.dateComponents([.day], from: product.addedDate, to: product.expiryDate).day ?? 7
        return calendar.date(byAdding: .day, value: max(originalDays, 1), to: Date()) ?? Date()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 16) {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar")
                }
                // Cart with badge
                Button { showShoppingList = true } label: {
                    let count = allShoppingItems.filter { !$0.isBought }.count
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "cart")
                            .padding(.top, count > 0 ? 6 : 0)
                            .padding(.trailing, count > 0 ? 6 : 0)
                        if count > 0 {
                            Text("\(min(count, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(.red, in: Capsule())
                        }
                    }
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Sort by") {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Button {
                            sortOption = opt
                        } label: {
                            if sortOption == opt {
                                Label(opt.rawValue, systemImage: "checkmark")
                            } else {
                                Text(opt.rawValue)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddProduct = true } label: {
                Image(systemName: "plus").fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Re-Add Sheet

private struct ReAddSheet: View {
    let product: Product
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expiryDate: Date

    init(product: Product, onConfirm: @escaping (Date) -> Void) {
        self.product = product
        self.onConfirm = onConfirm
        let calendar = Calendar.current
        let originalDays = calendar.dateComponents([.day], from: product.addedDate, to: product.expiryDate).day ?? 7
        let suggested = calendar.date(byAdding: .day, value: max(originalDays, 1), to: Date()) ?? Date()
        _expiryDate = State(initialValue: suggested)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text(product.category.icon)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.headline)
                            if !product.brand.isEmpty {
                                Text(product.brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(product.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Expiry Date") {
                    DatePicker(
                        "Expires on",
                        selection: $expiryDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
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
            .navigationTitle("Add to Fridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onConfirm(expiryDate)
                        dismiss()
                    } label: {
                        Label("Add to Fridge", systemImage: "refrigerator")
                            .fontWeight(.semibold)
                    }
                    .tint(.teal)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Used Item Row

private struct UsedItemRow: View {
    let product: Product
    let onReAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(product.category.icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(product.name)
                    .foregroundStyle(.secondary)
                    .strikethrough()
                    .lineLimit(1)
                Text("Used \(product.originalDuration) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                withAnimation { onReAdd() }
            } label: {
                Label("Re-add", systemImage: "arrow.counterclockwise")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.teal.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Subviews

private struct AlertBannerView: View {
    let count: Int
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
            Text("\(count) item\(count == 1 ? "" : "s") need attention")
                .fontWeight(.semibold).foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.top, 4)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct EmptyStateRow: View {
    var onAdd: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "refrigerator")
                .font(.system(size: 60)).foregroundStyle(.secondary)
            Text("Your fridge is empty")
                .font(.title3).fontWeight(.semibold)
            Text("Add products to start tracking\nexpiry dates and reduce waste.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(action: onAdd) {
                Label("Add First Product", systemImage: "plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(40).frame(maxWidth: .infinity)
    }
}

#Preview {
    ProductListView()
        .modelContainer(for: [Product.self, ShoppingItem.self], inMemory: true)
}
