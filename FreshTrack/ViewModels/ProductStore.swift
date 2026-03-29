import Foundation
import SwiftData
import SwiftUI
import UIKit

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
            product.quantity -= 1
        } else {
            product.isConsumed = true
            product.consumedDate = Date()
            NotificationService.shared.cancelNotifications(for: product)
            let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
            if !existing.contains(where: { !$0.isBought && $0.name.lowercased() == product.name.lowercased() }) {
                context.insert(ShoppingItem(name: product.name, category: product.category, imageFileName: product.imageFileName))
            }
        }
    }

    func incrementQuantity(_ product: Product) {
        product.quantity = min(product.quantity + 1, 99)
    }

    func delete(_ product: Product, context: ModelContext) {
        if !product.isConsumed && product.expiryStatus == .expired {
            let count = UserDefaults.standard.integer(forKey: "archivedWastedCount")
            UserDefaults.standard.set(count + 1, forKey: "archivedWastedCount")
            let price = product.price ?? localAvgCost
            let money = UserDefaults.standard.double(forKey: "archivedWastedMoney")
            UserDefaults.standard.set(money + price, forKey: "archivedWastedMoney")
            if product.price == nil {
                UserDefaults.standard.set(true, forKey: "archivedWastedHasEstimates")
            }
        }
        if let fn = product.imageFileName { ImageStorageService.delete(fileName: fn) }
        NotificationService.shared.cancelNotifications(for: product)
        context.delete(product)
    }

    private var localAvgCost: Double {
        switch Locale.current.language.languageCode?.identifier ?? "en" {
        case "tr": return 50.0
        case "de", "fr": return 3.0
        case "ar": return 15.0
        default: return 4.0
        }
    }

    /// Sadece sepete ekle, miktara dokunma. Swipe aksiyonu için kullanılır.
    func addToShoppingListOnly(_ product: Product, context: ModelContext, allItems: [ShoppingItem]) {
        guard !allItems.contains(where: { !$0.isBought && $0.name.lowercased() == product.name.lowercased() }) else { return }
        context.insert(ShoppingItem(name: product.name, category: product.category, imageFileName: product.imageFileName))
    }

    /// Auto-deletes consumed items older than 30 days
    func purgeOldConsumed(products: [Product], context: ModelContext) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let old = products.filter { $0.isConsumed && ($0.consumedDate ?? $0.addedDate) < cutoff }
        for product in old {
            if let fn = product.imageFileName { ImageStorageService.delete(fileName: fn) }
            context.delete(product)
        }
    }

    /// Returns expired products that are not already in the shopping list
    func expiredProductsNotInList(products: [Product], shoppingItems: [ShoppingItem]) -> [Product] {
        let pendingNames = Set(shoppingItems.filter { !$0.isBought }.map { $0.name.lowercased() })
        let expired = products.filter { !$0.isConsumed && $0.expiryStatus == .expired }
        return expired.filter { !pendingNames.contains($0.name.lowercased()) }
    }

    /// Adds given expired products to the shopping list (called after user confirmation)
    func addExpiredToShoppingList(_ products: [Product], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        for product in products {
            guard !existing.contains(where: { !$0.isBought && $0.name.lowercased() == product.name.lowercased() }) else { continue }
            context.insert(ShoppingItem(name: product.name, category: product.category, imageFileName: product.imageFileName))
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
