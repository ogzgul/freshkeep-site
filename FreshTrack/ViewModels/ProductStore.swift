import Foundation
import SwiftData
import SwiftUI

@MainActor
final class ProductStore: ObservableObject {

    // MARK: - Stats (computed from current products array passed in)

    func stats(from products: [Product]) -> StoreStats {
        let active = products.filter { !$0.isConsumed }
        let expired = active.filter { $0.expiryStatus == .expired }.count
        let urgent  = active.filter { $0.expiryStatus == .urgent  }.count
        let warning = active.filter { $0.expiryStatus == .warning }.count
        return StoreStats(
            totalActive: active.count,
            expired: expired,
            urgent: urgent,
            warning: warning,
            consumed: products.filter { $0.isConsumed }.count
        )
    }

    // MARK: - Sorting

    func sorted(_ products: [Product], by sort: SortOption, filter: FilterOption) -> [Product] {
        let filtered = applyFilter(products, filter: filter)
        switch sort {
        case .expiryAsc:
            return filtered.sorted { $0.expiryDate < $1.expiryDate }
        case .expiryDesc:
            return filtered.sorted { $0.expiryDate > $1.expiryDate }
        case .nameAsc:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .addedDesc:
            return filtered.sorted { $0.addedDate > $1.addedDate }
        }
    }

    private func applyFilter(_ products: [Product], filter: FilterOption) -> [Product] {
        let active = products.filter { !$0.isConsumed }
        switch filter {
        case .all:      return active
        case .expired:  return active.filter { $0.expiryStatus == .expired }
        case .urgent:   return active.filter { $0.expiryStatus == .urgent || $0.expiryStatus == .warning }
        case .fresh:    return active.filter { $0.expiryStatus == .fresh }
        }
    }

    // MARK: - CRUD helpers (model context passed in)

    func add(_ product: Product, context: ModelContext) {
        context.insert(product)
        NotificationService.shared.scheduleNotifications(for: product)
    }

    func markConsumed(_ product: Product, context: ModelContext) {
        if product.quantity > 1 {
            // Decrease by 1, keep product active
            product.quantity -= 1
        } else {
            // Last one — mark consumed and add to shopping list
            product.isConsumed = true
            NotificationService.shared.cancelNotifications(for: product)
            addToShoppingList(product, context: context)
        }
    }

    func delete(_ product: Product, context: ModelContext) {
        NotificationService.shared.cancelNotifications(for: product)
        context.delete(product)
    }

    func addToShoppingList(_ product: Product, context: ModelContext) {
        // Avoid duplicates — only add if not already in list (not bought yet)
        let name = product.name
        let item = ShoppingItem(name: name, category: product.category)
        context.insert(item)
    }

    /// Called on app launch — auto-adds expired products to shopping list if not already there
    func syncExpiredToShoppingList(products: [Product], shoppingItems: [ShoppingItem], context: ModelContext) {
        let pendingNames = Set(shoppingItems.filter { !$0.isBought }.map { $0.name.lowercased() })
        let expired = products.filter { !$0.isConsumed && $0.expiryStatus == .expired }
        for product in expired where !pendingNames.contains(product.name.lowercased()) {
            context.insert(ShoppingItem(name: product.name, category: product.category))
        }
    }
}

// MARK: - Supporting Types

struct StoreStats {
    let totalActive: Int
    let expired: Int
    let urgent: Int
    let warning: Int
    let consumed: Int

    var alertCount: Int { expired + urgent }
}

enum SortOption: String, CaseIterable {
    case expiryAsc  = "Expiry (Soonest)"
    case expiryDesc = "Expiry (Latest)"
    case nameAsc    = "Name A–Z"
    case addedDesc  = "Recently Added"
}

enum FilterOption: String, CaseIterable {
    case all     = "All"
    case expired = "Expired"
    case urgent  = "Expiring Soon"
    case fresh   = "Fresh"
}
