import SwiftUI
import StoreKit

struct EditProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let product: Product

    @State private var name: String
    @State private var brand: String
    @State private var category: ProductCategory
    @State private var expiryDate: Date
    @State private var quantity: Int
    @State private var priceText: String

    init(product: Product) {
        self.product = product
        _name       = State(initialValue: product.name)
        _brand      = State(initialValue: product.brand)
        _category   = State(initialValue: product.category)
        _expiryDate = State(initialValue: product.expiryDate)
        _quantity   = State(initialValue: product.quantity)
        _priceText  = State(initialValue: product.price.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    Picker("Category", selection: $category) {
                        ForEach(ProductCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: "").tag(cat)
                        }
                    }
                }

                Section("Expiry Date") {
                    DatePicker(
                        "Expires on",
                        selection: $expiryDate,
                        in: Calendar.current.date(byAdding: .day, value: -365, to: Date())!...,
                        displayedComponents: .date
                    )
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

                Section("Price (optional)") {
                    HStack {
                        Text(currencySymbol).foregroundStyle(.secondary)
                        TextField("0.00", text: $priceText).keyboardType(.decimalPad)
                    }
                }

                Section("Quantity") {
                    Stepper("Qty: \(quantity)", value: $quantity, in: 1...99)
                }
            }
            .navigationTitle("Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var currencySymbol: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "tr": return "₺"
        case "de", "fr": return "€"
        case "ar": return "﷼"
        default: return "$"
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        product.name       = trimmed
        product.brand      = brand.trimmingCharacters(in: .whitespaces)
        product.category   = category
        product.expiryDate = expiryDate
        product.quantity   = quantity
        product.price      = Double(priceText.replacingOccurrences(of: ",", with: "."))

        // Reschedule notifications with updated date
        NotificationService.shared.cancelNotifications(for: product)
        NotificationService.shared.scheduleNotifications(for: product)

        dismiss()
    }
}
