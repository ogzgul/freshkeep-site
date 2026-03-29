import SwiftUI
import SwiftData
import StoreKit

struct ProductListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.requestReview) private var requestReview
    @Query private var allProducts: [Product]
    @Query private var allShoppingItems: [ShoppingItem]
    @Query(sort: \Cabinet.createdDate) private var allCabinets: [Cabinet]

    @StateObject private var store = ProductStore()

    @State private var showAddProduct = false
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showCabinetManagement = false
    @State private var sortOption: SortOption = .expiryAsc
    @State private var filterOption: FilterOption = .all
    @State private var selectedCabinetID: UUID? = nil
    @State private var searchText = ""
    @State private var showShoppingList = false
    @State private var editingProduct: Product? = nil
    @State private var expiredForAlert: [Product] = []
    @State private var toastMessage: String? = nil

    @AppStorage("consumedCount") private var consumedCount = 0
    @AppStorage("reviewRequested") private var reviewRequested = false
    @AppStorage("notificationHour") private var notificationHour = 9

    private var activeProducts: [Product] { allProducts.filter { !$0.isConsumed } }

    private var cabinetFilteredProducts: [Product] {
        guard let cabID = selectedCabinetID else { return allProducts }
        return allProducts.filter { $0.cabinetID == cabID }
    }

    private var filteredProducts: [Product] {
        let sorted = store.sorted(cabinetFilteredProducts, by: sortOption, filter: filterOption)
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.brand.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var stats: StoreStats { store.stats(from: cabinetFilteredProducts) }

    var body: some View {
        NavigationStack {
            mainList
            .navigationTitle("FreshKeep")
            .searchable(text: $searchText, prompt: "Search products…")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showAddProduct) { AddProductView(prefillCabinetID: selectedCabinetID) }
            .sheet(isPresented: $showStats) { StatsView() }
            .sheet(isPresented: $showShoppingList) { ShoppingListView() }
            .sheet(item: $editingProduct) { EditProductView(product: $0) }
            .sheet(isPresented: $showSettings) { SettingsSheet(notificationHour: $notificationHour) }
            .sheet(isPresented: $showCabinetManagement) { CabinetManagementView() }
            .alert("Expired Products", isPresented: Binding(
                get: { !expiredForAlert.isEmpty },
                set: { if !$0 { expiredForAlert = [] } }
            )) {
                Button("Add to Shopping List") {
                    store.addExpiredToShoppingList(expiredForAlert, context: context)
                    expiredForAlert = []
                }
                Button("Dismiss", role: .cancel) {
                    expiredForAlert = []
                }
            } message: {
                let count = expiredForAlert.count
                let names = expiredForAlert.prefix(3).map { $0.name }.joined(separator: ", ")
                let suffix = count > 3 ? " and \(count - 3) more" : ""
                Text("\(count) product\(count == 1 ? "" : "s") \(count == 1 ? "has" : "have") expired: \(names)\(suffix).\n\nWould you like to add \(count == 1 ? "it" : "them") to your shopping list?")
            }
            .onAppear {
                store.purgeOldConsumed(products: allProducts, context: context)
                let expired = store.expiredProductsNotInList(
                    products: allProducts,
                    shoppingItems: allShoppingItems
                )
                if !expired.isEmpty { expiredForAlert = expired }
            }
            .onChange(of: notificationHour) { _, _ in
                NotificationService.shared.rescheduleAll(products: allProducts, cabinets: allCabinets)
            }
            .onChange(of: allCabinets) { _, newCabinets in
                if let sel = selectedCabinetID,
                   !newCabinets.contains(where: { $0.id == sel }) {
                    selectedCabinetID = nil
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = toastMessage {
                    Text(msg)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.teal.gradient, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(msg)
                }
            }
        }
    }

    // MARK: - Main List

    private var mainList: some View {
        List {
            if stats.alertCount > 0 {
                AlertBannerView(count: stats.alertCount)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if !allCabinets.isEmpty {
                        CabinetChip(
                            icon: "tray.2",
                            name: "All",
                            color: .teal,
                            isSelected: selectedCabinetID == nil
                        ) { selectedCabinetID = nil }

                        ForEach(allCabinets) { cabinet in
                            CabinetChip(
                                icon: cabinet.icon,
                                name: cabinet.name,
                                color: cabinet.color,
                                isSelected: selectedCabinetID == cabinet.id
                            ) { selectedCabinetID = cabinet.id }
                        }
                    }

                    Button {
                        showCabinetManagement = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "refrigerator")
                                .font(.caption.weight(.semibold))
                            if allCabinets.isEmpty {
                                Text("Add Cabinet").font(.subheadline)
                            } else {
                                Text("Manage").font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

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

            if cabinetFilteredProducts.filter({ !$0.isConsumed }).isEmpty {
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
                            cabinet: selectedCabinetID == nil
                                ? allCabinets.first(where: { $0.id == product.cabinetID })
                                : nil,
                            onConsume: {
                                let wasLast = product.quantity == 1
                                store.markConsumed(product, context: context)
                                consumedCount += 1
                                maybeRequestReview()
                                if wasLast { showToast("Added to shopping list") }
                            },
                            onIncrement: { store.incrementQuantity(product) },
                            onDelete: { store.delete(product, context: context) },
                            onEdit: { editingProduct = product },
                            onAddToShoppingList: {
                                let wasLast = product.quantity == 1
                                store.markConsumed(product, context: context)
                                consumedCount += 1
                                maybeRequestReview()
                                if wasLast { showToast("Added to shopping list") }
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: filterOption)
        .animation(.default, value: sortOption)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.4)) { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.3)) { toastMessage = nil }
        }
    }

    // MARK: - Review

    private func maybeRequestReview() {
        guard !reviewRequested, consumedCount >= 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            requestReview()
            reviewRequested = true
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 16) {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar")
                }
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
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
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

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @Binding var notificationHour: Int
    @Environment(\.dismiss) private var dismiss

    private let hours = [6, 7, 8, 9, 10, 11, 12, 18, 20, 21]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reminder Time", selection: $notificationHour) {
                        ForEach(hours, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                } header: {
                    Text("Daily Reminder Time")
                } footer: {
                    Text("You'll be notified at this time 2 days before, 1 day before, and on the expiry day.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func hourLabel(_ hour: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:00 a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return fmt.string(from: date)
    }
}

// MARK: - Subviews

private struct AlertBannerView: View {
    let count: Int
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.white)
            Text(count == 1
                ? String(format: NSLocalizedString("%lld item need attention", comment: ""), count)
                : String(format: NSLocalizedString("%lld items need attention", comment: ""), count)
            )
            .fontWeight(.semibold).foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.top, 4)
    }
}

private struct CabinetChip: View {
    let icon: String
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(
                isSelected ? color.opacity(0.18) : Color(.systemGray5),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .overlay(
                isSelected
                ? Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1)
                : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
