import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct FreshWidgetEntry: TimelineEntry {
    let date: Date
    let expiringItems: [WidgetProduct]
    let expiredCount: Int
}

struct WidgetProduct: Identifiable {
    let id: UUID
    let name: String
    let categoryIcon: String
    let daysLeft: Int
    let isExpired: Bool
}

// MARK: - Provider

struct FreshWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FreshWidgetEntry {
        FreshWidgetEntry(
            date: Date(),
            expiringItems: [
                WidgetProduct(id: UUID(), name: "Milk", categoryIcon: "🥛", daysLeft: 1, isExpired: false),
                WidgetProduct(id: UUID(), name: "Yogurt", categoryIcon: "🥛", daysLeft: 3, isExpired: false),
                WidgetProduct(id: UUID(), name: "Cheese", categoryIcon: "🥛", daysLeft: -2, isExpired: true)
            ],
            expiredCount: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FreshWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FreshWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh at midnight
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func loadEntry() -> FreshWidgetEntry {
        guard let container = try? ModelContainer(for: Product.self),
              let products = try? ModelContext(container).fetch(FetchDescriptor<Product>()) else {
            return FreshWidgetEntry(date: Date(), expiringItems: [], expiredCount: 0)
        }

        let active = products.filter { !$0.isConsumed }
        let expiredCount = active.filter { $0.expiryStatus == .expired }.count

        let expiring = active
            .filter { $0.expiryStatus != .fresh }
            .sorted { $0.expiryDate < $1.expiryDate }
            .prefix(5)
            .map {
                WidgetProduct(
                    id: $0.id,
                    name: $0.name,
                    categoryIcon: $0.category.icon,
                    daysLeft: $0.daysUntilExpiry,
                    isExpired: $0.expiryStatus == .expired
                )
            }

        return FreshWidgetEntry(date: Date(), expiringItems: Array(expiring), expiredCount: expiredCount)
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: FreshWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("🧊")
                    .font(.caption)
                Text("FreshKeep")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.teal)
            }

            if entry.expiringItems.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Text("✅")
                        .font(.title)
                    Text("All fresh!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Spacer()
                ForEach(entry.expiringItems.prefix(3)) { item in
                    SmallItemRow(item: item)
                }
                if entry.expiringItems.count > 3 {
                    Text("+\(entry.expiringItems.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SmallItemRow: View {
    let item: WidgetProduct

    var body: some View {
        HStack(spacing: 4) {
            Text(item.categoryIcon)
                .font(.caption)
            Text(item.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Text(daysLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(labelColor)
        }
    }

    private var daysLabel: String {
        if item.isExpired { return "Exp!" }
        if item.daysLeft == 0 { return "Today" }
        if item.daysLeft == 1 { return "1d" }
        return "\(item.daysLeft)d"
    }

    private var labelColor: Color {
        if item.isExpired || item.daysLeft == 0 { return .red }
        if item.daysLeft <= 2 { return .orange }
        return .yellow
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: FreshWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text("🧊")
                    Text("FreshKeep")
                        .fontWeight(.bold)
                        .foregroundStyle(.teal)
                }
                Spacer()
                if entry.expiredCount > 0 {
                    Label("\(entry.expiredCount) expired", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.12), in: Capsule())
                }
            }

            if entry.expiringItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("All items are fresh! 🎉")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                Divider()
                ForEach(entry.expiringItems.prefix(4)) { item in
                    MediumItemRow(item: item)
                }
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MediumItemRow: View {
    let item: WidgetProduct

    var body: some View {
        HStack(spacing: 8) {
            Text(item.categoryIcon)
                .font(.body)
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Group {
                if item.isExpired {
                    Text("Expired")
                } else if item.daysLeft == 0 {
                    Text("Today!")
                } else if item.daysLeft == 1 {
                    Text("Tomorrow")
                } else {
                    Text("in \(item.daysLeft) days")
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(item.isExpired || item.daysLeft == 0 ? .red : item.daysLeft <= 2 ? .orange : .yellow)
        }
    }
}

// MARK: - Widget Configuration

struct FreshTrackWidget: Widget {
    let kind: String = "FreshTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FreshWidgetProvider()) { entry in
            FreshWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FreshKeep")
        .description("See products expiring soon.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FreshWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FreshWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        default:            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct FreshWidgetBundle: WidgetBundle {
    var body: some Widget {
        FreshTrackWidget()
    }
}
