import Foundation
import SwiftData

enum ProductCategory: String, CaseIterable, Codable {
    case dairy       = "Dairy"
    case meat        = "Meat & Seafood"
    case produce     = "Produce"
    case beverages   = "Beverages"
    case condiments  = "Condiments & Sauces"
    case grains      = "Grains & Bread"
    case frozen      = "Frozen"
    case snacks      = "Snacks"
    case other       = "Other"

    var icon: String {
        switch self {
        case .dairy:      return "🥛"
        case .meat:       return "🥩"
        case .produce:    return "🥦"
        case .beverages:  return "🧃"
        case .condiments: return "🫙"
        case .grains:     return "🍞"
        case .frozen:     return "🧊"
        case .snacks:     return "🍿"
        case .other:      return "📦"
        }
    }
}

enum ExpiryStatus {
    case fresh      // > 7 days
    case warning    // 2–7 days
    case urgent     // 0–2 days
    case expired    // past

    var color: String {
        switch self {
        case .fresh:   return "StatusGreen"
        case .warning: return "StatusYellow"
        case .urgent:  return "StatusRed"
        case .expired: return "StatusGray"
        }
    }

    var label: String {
        switch self {
        case .fresh:   return "Fresh"
        case .warning: return "Expiring Soon"
        case .urgent:  return "Expires Today/Tomorrow"
        case .expired: return "Expired"
        }
    }
}

@Model
final class Product {
    var id: UUID
    var name: String
    var brand: String
    var categoryRaw: String
    var expiryDate: Date
    var addedDate: Date
    var barcode: String?
    var isConsumed: Bool
    var consumedDate: Date?
    var quantity: Int
    var unit: String
    var price: Double?
    var notes: String = ""

    init(
        name: String,
        brand: String = "",
        category: ProductCategory = .other,
        expiryDate: Date,
        barcode: String? = nil,
        quantity: Int = 1,
        unit: String = "pcs",
        price: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.categoryRaw = category.rawValue
        self.expiryDate = expiryDate
        self.addedDate = Date()
        self.barcode = barcode
        self.isConsumed = false
        self.consumedDate = nil
        self.quantity = quantity
        self.unit = unit
        self.price = price
        self.notes = notes
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: expiryDate)
        return calendar.dateComponents([.day], from: today, to: expiry).day ?? 0
    }

    var expiryStatus: ExpiryStatus {
        let days = daysUntilExpiry
        if days < 0     { return .expired }
        if days <= 1    { return .urgent }
        if days <= 7    { return .warning }
        return .fresh
    }

    var originalDuration: String {
        let days = Calendar.current.dateComponents([.day], from: addedDate, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "1 day" }
        if days < 30 { return "\(days) days" }
        let months = days / 30
        return "\(months) month\(months > 1 ? "s" : "")"
    }

    var expiryLabel: String {
        let days = daysUntilExpiry
        if days < 0  { return "Expired \(abs(days))d ago" }
        if days == 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }
}
