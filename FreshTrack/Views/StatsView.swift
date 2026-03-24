import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allProducts: [Product]
    @Environment(\.dismiss) private var dismiss

    private var consumed: [Product] { allProducts.filter { $0.isConsumed } }
    private var expired: [Product] { allProducts.filter { !$0.isConsumed && $0.expiryStatus == .expired } }
    private var active: [Product] { allProducts.filter { !$0.isConsumed } }

    private var currencySymbol: String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "tr": return "₺"
        case "de", "fr": return "€"
        case "ar": return "﷼"
        default:   return "$"
        }
    }

    private var avgItemCost: Double {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        switch lang {
        case "tr": return 50.0   // ~50₺ ortalama ürün
        case "de", "fr": return 3.0
        case "ar": return 15.0
        default:   return 4.0
        }
    }

    private var moneySaved: Double {
        let withPrice = consumed.compactMap { $0.price }
        if withPrice.isEmpty { return Double(consumed.count) * avgItemCost }
        return withPrice.reduce(0, +)
    }

    private var moneyWasted: Double {
        let withPrice = expired.compactMap { $0.price }
        if withPrice.isEmpty { return Double(expired.count) * avgItemCost }
        return withPrice.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary cards
                Section {
                    HStack(spacing: 16) {
                        StatCard(
                            value: "\(active.count)",
                            label: "Active",
                            color: .blue,
                            icon: "refrigerator"
                        )
                        StatCard(
                            value: "\(consumed.count)",
                            label: "Used",
                            color: .green,
                            icon: "checkmark.circle"
                        )
                        StatCard(
                            value: "\(expired.count)",
                            label: "Expired",
                            color: .gray,
                            icon: "xmark.circle"
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                // Money impact
                Section("Savings Tracker") {
                    HStack {
                        Label("Estimated saved", systemImage: "dollarsign.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Text("\(currencySymbol)\(formatMoney(moneySaved))")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Label("Estimated wasted", systemImage: "trash.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(currencySymbol)\(formatMoney(moneyWasted))")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    Text("Based on ~\(currencySymbol)\(Int(avgItemCost)) average item cost")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Category breakdown
                Section("By Category") {
                    ForEach(categoryBreakdown, id: \.category) { item in
                        HStack {
                            Text(item.category.icon)
                            Text(item.category.rawValue)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                    }
                }

                // Expiry breakdown
                Section("Expiry Status") {
                    StatusRow(label: "Expired",       count: expired.count, color: .gray)
                    StatusRow(label: "Today/Tomorrow", count: active.filter { $0.expiryStatus == .urgent  }.count, color: .orange)
                    StatusRow(label: "Within 7 days", count: active.filter { $0.expiryStatus == .warning }.count, color: .yellow)
                    StatusRow(label: "Fresh (>7d)",   count: active.filter { $0.expiryStatus == .fresh   }.count, color: .green)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatMoney(_ value: Double) -> String {
        value >= 10 ? String(Int(value)) : String(format: "%.2f", value)
    }

    private var categoryBreakdown: [(category: ProductCategory, count: Int)] {
        var counts: [ProductCategory: Int] = [:]
        for p in active { counts[p.category, default: 0] += 1 }
        return counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatusRow: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text("\(count)")
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Product.self, inMemory: true)
}
