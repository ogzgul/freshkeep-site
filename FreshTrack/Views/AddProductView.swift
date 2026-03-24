import SwiftUI
import SwiftData

struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var prefillBarcode: String? = nil
    var prefillName: String? = nil
    var prefillBrand: String? = nil
    var prefillCategory: ProductCategory? = nil

    @StateObject private var store = ProductStore()

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var category: ProductCategory = .other
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var quantity: Int = 1
    @State private var barcode: String? = nil
    @State private var priceText: String = ""

    @State private var showScanner = false
    @State private var isLookingUp = false
    @State private var lookupError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Product info
                Section("Product") {
                    HStack {
                        TextField("Product name", text: $name)
                        if isLookingUp {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }

                    TextField("Brand (optional)", text: $brand)

                    Picker("Category", selection: $category) {
                        ForEach(ProductCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: "")
                                .tag(cat)
                        }
                    }
                }

                // Expiry
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

                // Price
                Section("Price (optional)") {
                    HStack {
                        Text(currencySymbol)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                }

                // Quantity
                Section("Quantity") {
                    Stepper("Qty: \(quantity)", value: $quantity, in: 1...99)
                }

                // Barcode
                Section("Barcode") {
                    if let bc = barcode {
                        HStack {
                            Image(systemName: "barcode")
                                .foregroundStyle(.secondary)
                            Text(bc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") { barcode = nil }
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    } else {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                    }

                    if let err = lookupError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet(isPresented: $showScanner) { code in
                    barcode = code
                    Task { await lookupBarcode(code) }
                }
            }
            .onAppear {
                if let pName = prefillName    { name     = pName }
                if let pBrand = prefillBrand  { brand    = pBrand }
                if let pCat   = prefillCategory { category = pCat }
                if let pBC    = prefillBarcode  { barcode  = pBC }
            }
        }
    }

    // MARK: - Helpers

    private var currencySymbol: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "tr": return "₺"
        case "de", "fr": return "€"
        case "ar": return "﷼"
        default:   return "$"
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let parsedPrice = Double(priceText.replacingOccurrences(of: ",", with: "."))

        let product = Product(
            name: trimmed,
            brand: brand.trimmingCharacters(in: .whitespaces),
            category: category,
            expiryDate: expiryDate,
            barcode: barcode,
            quantity: quantity,
            price: parsedPrice
        )
        store.add(product, context: context)
        dismiss()
    }

    private func lookupBarcode(_ code: String) async {
        isLookingUp = true
        lookupError = nil

        if let result = await OpenFoodFactsService.shared.lookup(barcode: code) {
            await MainActor.run {
                if name.isEmpty { name = result.name }
                if brand.isEmpty { brand = result.brand }
                category = result.category
            }
        } else {
            await MainActor.run {
                lookupError = "Product not found — enter details manually."
            }
        }

        isLookingUp = false
    }
}

#Preview {
    AddProductView()
        .modelContainer(for: Product.self, inMemory: true)
}
