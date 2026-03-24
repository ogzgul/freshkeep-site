import Foundation

struct FoodFactsProduct {
    let name: String
    let brand: String
    let category: ProductCategory
}

// MARK: - Local Turkish DB

private struct LocalProduct: Decodable {
    let barcode: String
    let name: String
    let brand: String
    let category: String
}

private let localTurkishDB: [String: LocalProduct] = {
    guard let url = Bundle.main.url(forResource: "turkish_products", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let products = try? JSONDecoder().decode([LocalProduct].self, from: data) else {
        return [:]
    }
    return Dictionary(uniqueKeysWithValues: products.map { ($0.barcode, $0) })
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

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        return URLSession(configuration: config)
    }()

    func lookup(barcode: String) async -> FoodFactsProduct? {
        // 1. Local Turkish DB first (instant, no network)
        if let local = localTurkishDB[barcode] {
            return FoodFactsProduct(name: local.name, brand: local.brand, category: categoryFromString(local.category))
        }
        // 2. Turkish Open Food Facts
        if let r = await fetch(barcode: barcode, host: "tr.openfoodfacts.org") { return r }
        // 3. World Open Food Facts
        if let r = await fetch(barcode: barcode, host: "world.openfoodfacts.org") { return r }
        // 4. Open Beauty Facts fallback
        if let r = await fetch(barcode: barcode, host: "world.openbeautyfacts.org") { return r }
        return nil
    }

    private func fetch(barcode: String, host: String) async -> FoodFactsProduct? {
        guard let url = URL(string: "https://\(host)/api/v2/product/\(barcode)?fields=product_name,product_name_tr,brands,categories_tags") else { return nil }

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
        return FoodFactsProduct(name: name, brand: brand, category: inferCategory(from: tags))
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
}
