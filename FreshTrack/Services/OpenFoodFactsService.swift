import Foundation

struct FoodFactsProduct {
    let name: String
    let brand: String
    let category: ProductCategory
    let ingredients: String?
    let allergens: [String]?
    let isApproximate: Bool
}

// MARK: - Local Turkish DB

private struct LocalProduct: Decodable {
    let barcode: String?
    let barcodePrefix: String?
    let name: String
    let brand: String
    let category: String
    let ingredients: String?
    let allergens: [String]?
    let approximate: Bool?
}

private struct LearnedBarcodeProduct: Codable {
    let barcode: String
    let name: String
    let brand: String
    let categoryRaw: String
    let ingredients: String?
    let allergens: [String]?
    let updatedAt: Date

    init(
        barcode: String,
        name: String,
        brand: String,
        categoryRaw: String,
        ingredients: String?,
        allergens: [String]?,
        updatedAt: Date = Date()
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.categoryRaw = categoryRaw
        self.ingredients = ingredients
        self.allergens = allergens
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case barcode
        case name
        case brand
        case categoryRaw
        case ingredients
        case allergens
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try container.decode(String.self, forKey: .barcode)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decode(String.self, forKey: .brand)
        categoryRaw = try container.decode(String.self, forKey: .categoryRaw)
        ingredients = try container.decodeIfPresent(String.self, forKey: .ingredients)
        allergens = try container.decodeIfPresent([String].self, forKey: .allergens)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

private struct LocalTurkishIndex {
    let exact: [String: LocalProduct]
    let prefixes: [LocalProduct]
}

private let localTurkishIndex: LocalTurkishIndex = {
    guard let url = Bundle.main.url(forResource: "turkish_products", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let products = try? JSONDecoder().decode([LocalProduct].self, from: data) else {
        return LocalTurkishIndex(exact: [:], prefixes: [])
    }

    let exactProducts: [(String, LocalProduct)] = products.compactMap { product in
        guard let barcode = product.barcode, !barcode.isEmpty else { return nil }
        return (barcode, product)
    }

    let prefixProducts = products
        .filter { ($0.barcodePrefix?.isEmpty == false) }
        .sorted { ($0.barcodePrefix?.count ?? 0) > ($1.barcodePrefix?.count ?? 0) }

    return LocalTurkishIndex(
        exact: Dictionary(uniqueKeysWithValues: exactProducts),
        prefixes: prefixProducts
    )
}()

private func categoryFromString(_ s: String) -> ProductCategory {
    switch s {
    case "dairy":      return .dairy
    case "meat":       return .meat
    case "produce":    return .produce
    case "beverages":  return .beverages
    case "condiments": return .condiments
    case "grains":     return .grains
    case "frozen":     return .frozen
    case "snacks":     return .snacks
    default:           return .other
    }
}

// MARK: - Service

final class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private init() {}

    private let learnedBarcodeKey = "learnedBarcodeProducts"
    private let learnedBarcodeFileName = "learned-barcode-products.json"
    private let maxLearnedBarcodeProducts = 5_000
    private let lookupHosts = [
        "tr.openfoodfacts.org",
        "world.openfoodfacts.org",
        "world.openbeautyfacts.org"
    ]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        return URLSession(configuration: config)
    }()

    func localLookup(barcode: String) -> FoodFactsProduct? {
        let candidates = Self.barcodeCandidates(for: barcode)
        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            if let learned = learnedProduct(for: candidate) {
                return learned
            }
        }

        for candidate in candidates {
            if let local = localTurkishIndex.exact[candidate] {
                return localFoodFactsProduct(from: local)
            }
        }

        for candidate in candidates {
            if let local = localPrefixProduct(for: candidate) {
                return localFoodFactsProduct(from: local)
            }
        }

        return nil
    }

    func lookup(barcode: String) async -> FoodFactsProduct? {
        if let local = localLookup(barcode: barcode) {
            return local
        }

        return await remoteLookup(barcode: barcode)
    }

    func remoteLookup(barcode: String) async -> FoodFactsProduct? {
        let candidates = Self.barcodeCandidates(for: barcode)
        guard !candidates.isEmpty else { return nil }

        for candidate in candidates {
            for host in lookupHosts {
                if let result = await fetch(barcode: candidate, host: host) {
                    cacheRemoteLookup(result, for: candidate)
                    return result
                }
            }
        }

        return nil
    }

    func remember(
        barcode: String,
        name: String,
        brand: String,
        category: ProductCategory,
        ingredients: String?,
        allergens: [String]?
    ) {
        let normalizedBarcode = Self.normalizedBarcode(barcode)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedBarcode.isEmpty, !trimmedName.isEmpty else { return }

        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIngredients = ingredients?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedAllergens = allergens?.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        var learnedProducts = loadLearnedProducts()
        learnedProducts[normalizedBarcode] = LearnedBarcodeProduct(
            barcode: normalizedBarcode,
            name: trimmedName,
            brand: trimmedBrand,
            categoryRaw: category.rawValue,
            ingredients: trimmedIngredients?.isEmpty == false ? trimmedIngredients : nil,
            allergens: sanitizedAllergens?.isEmpty == false ? sanitizedAllergens : nil
        )
        saveLearnedProducts(learnedProducts)
    }

    func cacheRemoteLookup(_ product: FoodFactsProduct, for barcode: String) {
        let normalizedBarcode = Self.normalizedBarcode(barcode)
        guard !normalizedBarcode.isEmpty else { return }

        var learnedProducts = loadLearnedProducts()
        learnedProducts[normalizedBarcode] = LearnedBarcodeProduct(
            barcode: normalizedBarcode,
            name: product.name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: product.brand.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryRaw: product.category.rawValue,
            ingredients: product.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines),
            allergens: product.allergens,
            updatedAt: Date()
        )
        saveLearnedProducts(learnedProducts)
    }

    static func normalizedBarcode(_ barcode: String) -> String {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter { $0.isNumber }
        return digitsOnly.count >= 8 ? digitsOnly : trimmed
    }

    private func fetch(barcode: String, host: String) async -> FoodFactsProduct? {
        guard let url = URL(string: "https://\(host)/api/v2/product/\(barcode)?fields=product_name,product_name_tr,brands,categories_tags,ingredients_text,ingredients_text_tr,allergens_tags") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("FreshKeep iOS/1.1", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else { return nil }

        let name = ((product["product_name_tr"] as? String) ?? (product["product_name"] as? String) ?? "")
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let brand = (product["brands"] as? String ?? "")
            .components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""

        let tags = product["categories_tags"] as? [String] ?? []
        
        let ingredients = (product["ingredients_text_tr"] as? String) ?? (product["ingredients_text"] as? String)
        
        var parsedAllergens: [String]? = nil
        if let allergensTags = product["allergens_tags"] as? [String], !allergensTags.isEmpty {
            parsedAllergens = allergensTags.map { tag in
                let parts = tag.components(separatedBy: ":")
                return parts.count > 1 ? parts[1].capitalized : tag.capitalized
            }
        }
        
        return FoodFactsProduct(
            name: name,
            brand: brand,
            category: inferCategory(from: tags),
            ingredients: ingredients?.trimmingCharacters(in: .whitespacesAndNewlines),
            allergens: parsedAllergens,
            isApproximate: false
        )
    }

    private func inferCategory(from tags: [String]) -> ProductCategory {
        let j = tags.joined(separator: " ").lowercased()
        if contains(j, ["milk","cheese","yogurt","dairy","butter","cream","sut","peynir","tereyag","yogurt"]) { return .dairy }
        if contains(j, ["meat","beef","chicken","pork","fish","seafood","et","tavuk","balik","sucuk","salam"]) { return .meat }
        if contains(j, ["vegetable","fruit","produce","salad","sebze","meyve","domates","salatalik"]) { return .produce }
        if contains(j, ["beverage","drink","juice","water","soda","icecek","meyve-suyu","kola","ayran"]) { return .beverages }
        if contains(j, ["sauce","condiment","ketchup","mustard","dressing","sos","ketcap","mayonez"]) { return .condiments }
        if contains(j, ["bread","grain","cereal","pasta","rice","flour","ekmek","makarna","pirinc","un"]) { return .grains }
        if contains(j, ["frozen","ice","dondurulmus","dondurma"]) { return .frozen }
        if contains(j, ["snack","chip","cookie","cracker","candy","cips","biskuvi","cikolata","gofret"]) { return .snacks }
        return .other
    }

    private func contains(_ string: String, _ keywords: [String]) -> Bool {
        keywords.contains { string.contains($0) }
    }

    private static func barcodeCandidates(for barcode: String) -> [String] {
        let normalized = normalizedBarcode(barcode)
        guard !normalized.isEmpty else { return [] }

        var candidates: [String] = []

        func append(_ value: String) {
            guard !value.isEmpty, !candidates.contains(value) else { return }
            candidates.append(value)
        }

        append(normalized)

        if normalized.count == 12 {
            append("0" + normalized)
        }

        if normalized.count == 13, normalized.hasPrefix("0") {
            append(String(normalized.dropFirst()))
        }

        return candidates
    }

    private func learnedProduct(for barcode: String) -> FoodFactsProduct? {
        let learned = loadLearnedProducts()[barcode]
        guard let learned else { return nil }

        return FoodFactsProduct(
            name: learned.name,
            brand: learned.brand,
            category: ProductCategory(rawValue: learned.categoryRaw) ?? .other,
            ingredients: learned.ingredients,
            allergens: learned.allergens,
            isApproximate: false
        )
    }

    private func loadLearnedProducts() -> [String: LearnedBarcodeProduct] {
        if let fileURL = learnedProductsFileURL(),
           let data = try? Data(contentsOf: fileURL),
           let products = try? JSONDecoder().decode([String: LearnedBarcodeProduct].self, from: data) {
            return trimmedLearnedProducts(products)
        }

        guard let data = UserDefaults.standard.data(forKey: learnedBarcodeKey),
              let products = try? JSONDecoder().decode([String: LearnedBarcodeProduct].self, from: data) else {
            return [:]
        }

        let trimmedProducts = trimmedLearnedProducts(products)
        if learnedProductsFileURL() != nil {
            saveLearnedProducts(trimmedProducts)
            UserDefaults.standard.removeObject(forKey: learnedBarcodeKey)
        }
        return trimmedProducts
    }

    private func saveLearnedProducts(_ products: [String: LearnedBarcodeProduct]) {
        let trimmedProducts = trimmedLearnedProducts(products)
        guard let data = try? JSONEncoder().encode(trimmedProducts) else { return }

        if let fileURL = learnedProductsFileURL() {
            try? data.write(to: fileURL, options: .atomic)
        } else {
            UserDefaults.standard.set(data, forKey: learnedBarcodeKey)
        }
    }

    private func localFoodFactsProduct(from local: LocalProduct) -> FoodFactsProduct {
        FoodFactsProduct(
            name: local.name,
            brand: local.brand,
            category: categoryFromString(local.category),
            ingredients: local.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines),
            allergens: local.allergens?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            isApproximate: local.approximate ?? false
        )
    }

    private func localPrefixProduct(for barcode: String) -> LocalProduct? {
        localTurkishIndex.prefixes.first { local in
            guard let prefix = local.barcodePrefix else { return false }
            return barcode.hasPrefix(prefix)
        }
    }

    private func trimmedLearnedProducts(_ products: [String: LearnedBarcodeProduct]) -> [String: LearnedBarcodeProduct] {
        guard products.count > maxLearnedBarcodeProducts else { return products }

        let recentProducts = products.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(maxLearnedBarcodeProducts)

        return Dictionary(uniqueKeysWithValues: recentProducts.map { ($0.barcode, $0) })
    }

    private func learnedProductsFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let directoryURL = appSupportURL.appendingPathComponent("FreshTrack", isDirectory: true)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        return directoryURL.appendingPathComponent(learnedBarcodeFileName)
    }
}
