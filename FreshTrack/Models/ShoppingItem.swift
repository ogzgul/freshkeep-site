import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var addedDate: Date
    var isBought: Bool
    var imageFileName: String?

    init(name: String, category: ProductCategory = .other, imageFileName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.categoryRaw = category.rawValue
        self.addedDate = Date()
        self.isBought = false
        self.imageFileName = imageFileName
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
