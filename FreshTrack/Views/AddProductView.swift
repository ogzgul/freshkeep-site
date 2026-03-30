import SwiftUI
import SwiftData
import UIKit

struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Cabinet.createdDate) private var allCabinets: [Cabinet]

    var prefillBarcode: String? = nil
    var prefillName: String? = nil
    var prefillBrand: String? = nil
    var prefillCategory: ProductCategory? = nil
    var prefillCabinetID: UUID? = nil

    @StateObject private var store = ProductStore()

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var category: ProductCategory = .other
    @State private var expiryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var quantity: Int = 1
    @State private var barcode: String? = nil
    @State private var priceText: String = ""
    @State private var notes: String = ""
    @State private var hasCustomDate = false
    @State private var selectedCabinetID: UUID? = nil

    @State private var showScanner = false
    @State private var showExpiryScanner = false
    @State private var isLookingUp = false
    @State private var lookupError: String? = nil
    @State private var lookupInfo: String? = nil
    @State private var productImage: UIImage? = nil
    @State private var scannedIngredients: String? = nil
    @State private var scannedAllergens: [String] = []
    @State private var lastLookupWasApproximate = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    ProductImagePickerView(image: $productImage)

                    HStack {
                        TextField("Product name", text: $name)
                        if isLookingUp {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                    TextField("Brand (optional)", text: $brand)
                    Picker("Category", selection: $category) {
                        ForEach(ProductCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: "").tag(cat)
                        }
                    }
                    if !allCabinets.isEmpty {
                        Picker("Cabinet", selection: $selectedCabinetID) {
                            Text("None").tag(UUID?.none)
                            ForEach(allCabinets) { cabinet in
                                Label {
                                    Text(cabinet.name)
                                } icon: {
                                    Image(systemName: cabinet.icon)
                                }
                                .tag(Optional(cabinet.id))
                            }
                        }
                    }
                    if let bc = barcode {
                        HStack {
                            Image(systemName: "barcode").foregroundStyle(.secondary)
                            Text(bc).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear") { barcode = nil }.foregroundStyle(.red).font(.caption)
                        }
                    } else {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                    }
                    
                    if !scannedAllergens.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("Allergen Warning")
                                    .font(.subheadline).bold().foregroundStyle(.red)
                            }
                            Text(scannedAllergens.joined(separator: ", "))
                                .font(.subheadline).bold().foregroundStyle(.red)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    if let ing = scannedIngredients, !ing.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ingredients")
                                .font(.subheadline).bold()
                            Text(ing)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if let err = lookupError {
                        Text(err).font(.caption).foregroundStyle(.orange)
                    }

                    if let info = lookupInfo {
                        Text(info).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Expiry Date") {
                    DatePicker(
                        "Expires on",
                        selection: $expiryDate,
                        in: Calendar.current.date(byAdding: .day, value: -365, to: Date())!...,
                        displayedComponents: .date
                    )
                    .onChange(of: expiryDate) { _, _ in hasCustomDate = true }

                    HStack(spacing: 8) {
                        ForEach([3, 7, 14, 30], id: \.self) { days in
                            Button("+\(days)d") {
                                expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
                                hasCustomDate = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }

                    Button {
                        showExpiryScanner = true
                    } label: {
                        Label("Scan Expiry Date", systemImage: "text.viewfinder")
                    }

                    if !hasCustomDate {
                        Text("Suggested based on category")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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

                Section("Notes (optional)") {
                    TextField("Storage location, usage tips…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                    let normalizedCode = OpenFoodFactsService.normalizedBarcode(code)
                    barcode = normalizedCode
                    Task { await lookupBarcode(normalizedCode) }
                }
            }
            .sheet(isPresented: $showExpiryScanner) {
                ExpiryDateScannerSheet(isPresented: $showExpiryScanner) { date in
                    expiryDate = date
                    hasCustomDate = true
                }
            }
            .onChange(of: category) { _, newCategory in
                guard !hasCustomDate else { return }
                expiryDate = defaultExpiry(for: newCategory)
            }
            .onAppear {
                if let pName = prefillName     { name     = pName }
                if let pBrand = prefillBrand   { brand    = pBrand }
                if let pCat = prefillCategory  { category = pCat }
                if let pBC = prefillBarcode    { barcode  = OpenFoodFactsService.normalizedBarcode(pBC) }
                if let pCabID = prefillCabinetID {
                    selectedCabinetID = pCabID
                } else {
                    selectedCabinetID = allCabinets.first?.id
                }
                expiryDate = defaultExpiry(for: category)
            }
        }
    }

    // MARK: - Default expiry by category

    private func defaultExpiry(for category: ProductCategory) -> Date {
        let days: Int
        switch category {
        case .dairy:      days = 7
        case .meat:       days = 3
        case .produce:    days = 5
        case .beverages:  days = 30
        case .condiments: days = 180
        case .grains:     days = 180
        case .frozen:     days = 90
        case .snacks:     days = 30
        case .other:      days = 7
        }
        return Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
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

        var imageFileName: String? = nil
        if let img = productImage {
            let fn = ImageStorageService.newFileName()
            ImageStorageService.save(img, fileName: fn)
            imageFileName = fn
        }

        let product = Product(
            name: trimmed,
            brand: brand.trimmingCharacters(in: .whitespaces),
            category: category,
            expiryDate: expiryDate,
            barcode: barcode,
            quantity: quantity,
            price: parsedPrice,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            imageFileName: imageFileName,
            cabinetID: selectedCabinetID,
            ingredients: scannedIngredients,
            allergens: scannedAllergens.isEmpty ? nil : scannedAllergens
        )

        if let barcode {
            OpenFoodFactsService.shared.remember(
                barcode: barcode,
                name: trimmed,
                brand: brand,
                category: category,
                ingredients: scannedIngredients,
                allergens: scannedAllergens
            )
        }

        let cabinetName = allCabinets.first(where: { $0.id == selectedCabinetID })?.name
        store.add(product, context: context, cabinetName: cabinetName)
        dismiss()
    }

    private func lookupBarcode(_ code: String) async {
        await MainActor.run {
            isLookingUp = true
            lookupError = nil
            lookupInfo = nil
            scannedIngredients = nil
            scannedAllergens = []
            lastLookupWasApproximate = false
        }

        if let localResult = OpenFoodFactsService.shared.localLookup(barcode: code) {
            await MainActor.run {
                applyLookupResult(localResult, overwriteText: false)
                lastLookupWasApproximate = localResult.isApproximate

                if localResult.isApproximate {
                    lookupInfo = NSLocalizedString("Approximate match found, searching for details.", comment: "")
                } else if localResult.ingredients == nil && (localResult.allergens?.isEmpty != false) {
                    lookupInfo = NSLocalizedString("Product found, fetching ingredient details.", comment: "")
                }
            }

            let shouldEnrich = localResult.isApproximate
                || localResult.ingredients == nil
                || (localResult.allergens?.isEmpty ?? true)

            if shouldEnrich {
                if let remoteResult = await OpenFoodFactsService.shared.remoteLookup(barcode: code) {
                    await MainActor.run {
                        guard barcode == code else { return }
                        applyLookupResult(remoteResult, overwriteText: lastLookupWasApproximate)
                        lastLookupWasApproximate = false

                        if remoteResult.ingredients != nil || (remoteResult.allergens?.isEmpty == false) {
                            lookupInfo = NSLocalizedString("Ingredient details updated.", comment: "")
                        } else {
                            lookupInfo = nil
                        }
                    }
                } else {
                    await MainActor.run {
                        guard barcode == code else { return }
                        if localResult.isApproximate {
                            lookupInfo = NSLocalizedString("Approximate match found, please verify the product name.", comment: "")
                        } else {
                            lookupInfo = nil
                        }
                    }
                }
            }
        } else if let remoteResult = await OpenFoodFactsService.shared.remoteLookup(barcode: code) {
            await MainActor.run {
                guard barcode == code else { return }
                applyLookupResult(remoteResult, overwriteText: false)
            }
        } else {
            await MainActor.run {
                lookupError = NSLocalizedString("Product not found — enter details manually.", comment: "")
            }
        }

        await MainActor.run {
            isLookingUp = false
        }
    }

    private func applyLookupResult(_ result: FoodFactsProduct, overwriteText: Bool) {
        if overwriteText || name.isEmpty {
            name = result.name
        }

        if overwriteText || brand.isEmpty {
            brand = result.brand
        }

        category = result.category

        if let ingredients = result.ingredients, !ingredients.isEmpty {
            scannedIngredients = ingredients
        }

        if let allergens = result.allergens, !allergens.isEmpty {
            scannedAllergens = allergens
        }
    }
}

#Preview {
    AddProductView()
        .modelContainer(for: Product.self, inMemory: true)
}
