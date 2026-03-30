import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var id: UUID
    var name: String
    var brand: String?
    var categoryRaw: String
    var barcode: String?
    var notes: String?
    var ingredients: String?
    var allergens: [String]?
    var addedDate: Date
    var isBought: Bool
    var imageFileName: String?

    init(
        name: String,
        brand: String? = nil,
        category: ProductCategory = .other,
        barcode: String? = nil,
        notes: String? = nil,
        ingredients: String? = nil,
        allergens: [String]? = nil,
        imageFileName: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.categoryRaw = category.rawValue
        self.barcode = barcode
        self.notes = notes
        self.ingredients = ingredients
        self.allergens = allergens
        self.addedDate = Date()
        self.isBought = false
        self.imageFileName = imageFileName
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    convenience init(product: Product) {
        self.init(
            name: product.name,
            brand: product.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : product.brand,
            category: product.category,
            barcode: product.barcode,
            notes: product.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : product.notes,
            ingredients: product.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? product.ingredients : nil,
            allergens: product.allergens,
            imageFileName: product.imageFileName
        )
    }

    func absorbMetadata(from product: Product) {
        category = product.category

        let trimmedBrand = product.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBrand.isEmpty {
            brand = trimmedBrand
        }

        let trimmedBarcode = product.barcode?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedBarcode, !trimmedBarcode.isEmpty {
            barcode = trimmedBarcode
        }

        let trimmedNotes = product.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            notes = trimmedNotes
        }

        let trimmedIngredients = product.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedIngredients, !trimmedIngredients.isEmpty {
            ingredients = trimmedIngredients
        }

        let sanitizedAllergens = (product.allergens ?? []).compactMap { allergen -> String? in
            let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if !sanitizedAllergens.isEmpty {
            allergens = sanitizedAllergens
        }

        if let imageFileName = product.imageFileName, !imageFileName.isEmpty {
            self.imageFileName = imageFileName
        }
    }
}
