import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var addedDate: Date
    var isBought: Bool

    init(name: String, category: ProductCategory = .other) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.addedDate = Date()
        self.isBought = false
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
