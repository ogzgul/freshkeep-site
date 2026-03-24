import SwiftUI

struct ProductRowView: View {
    let product: Product
    var onConsume: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void = {}
    var onAddToShoppingList: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            // Category icon
            Text(product.category.icon)
                .font(.title2)
                .frame(width: 36)

            // Name + expiry
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(isExpired ? .white : .primary)

                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.caption)
                        .foregroundStyle(isExpired ? .white.opacity(0.75) : .secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                    Text(product.expiryLabel)
                        .font(.caption)
                }
                .foregroundStyle(isExpired ? .white.opacity(0.9) : statusColor)
            }

            Spacer()

            // Quantity badge
            if product.quantity > 1 {
                Text("×\(product.quantity)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isExpired ? .white.opacity(0.85) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isExpired ? Color.white.opacity(0.2) : Color(.systemGray5),
                                in: Capsule())
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, isExpired ? 8 : 0)
        .background(
            isExpired
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.82))
                : nil
        )
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation { onConsume() }
            } label: {
                Label("Used", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)

            if let addToList = onAddToShoppingList {
                Button {
                    addToList()
                } label: {
                    Label("Shopping List", systemImage: "cart.badge.plus")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation { onDelete() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }

    private var isExpired: Bool { product.expiryStatus == .expired }

    private var statusColor: Color {
        switch product.expiryStatus {
        case .fresh:   return .green
        case .warning: return .yellow
        case .urgent:  return .orange
        case .expired: return .red
        }
    }

    private var statusIcon: String {
        switch product.expiryStatus {
        case .fresh:   return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .urgent:  return "exclamationmark.triangle.fill"
        case .expired: return "xmark.circle.fill"
        }
    }
}
