import SwiftUI

struct ProductRowView: View {
    let product: Product
    var cabinet: Cabinet? = nil
    var onConsume: () -> Void
    var onIncrement: () -> Void
    var onDelete: () -> Void
    var onEdit: () -> Void = {}
    var onAddToShoppingList: (() -> Void)? = nil

    @State private var showNote = false
    @State private var noteRead = false
    @State private var showDeleteConfirm = false
    @State private var showConsumeConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            // Product image or category icon
            ProductThumbnailView(
                fileName: product.imageFileName,
                fallbackIcon: product.category.icon
            )

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

                if let cab = cabinet {
                    HStack(spacing: 3) {
                        Image(systemName: cab.icon)
                            .font(.caption2)
                        Text(cab.name)
                            .font(.caption2)
                    }
                    .foregroundStyle(isExpired ? .white.opacity(0.7) : cab.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        isExpired ? Color.white.opacity(0.15) : cab.color.opacity(0.12),
                        in: Capsule()
                    )
                }

                if let allergenChipText {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(allergenChipText)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(allergenChipForeground)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        allergenChipBackground,
                        in: Capsule()
                    )
                    .accessibilityLabel(Text("Allergen Warning"))
                }

                if !product.notes.isEmpty {
                    Button {
                        showNote = true
                        withAnimation { noteRead = true }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.fill")
                                .font(.caption2)
                                .symbolEffect(.pulse, isActive: !noteRead)
                            Text("Note")
                                .font(.caption2)
                        }
                        .foregroundStyle(noteRead
                            ? (isExpired ? .white.opacity(0.5) : .secondary)
                            : (isExpired ? .white : .orange)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Quantity stepper
            HStack(spacing: 6) {
                Button {
                    if product.quantity == 1 {
                        showConsumeConfirm = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) { onConsume() }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(
                            isExpired ? Color.white.opacity(0.2) : Color(.systemGray5),
                            in: Circle()
                        )
                        .foregroundStyle(isExpired ? .white : .primary)
                }
                .buttonStyle(.plain)

                Text("\(product.quantity)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isExpired ? .white : .primary)
                    .frame(minWidth: 18, alignment: .center)
                    .monospacedDigit()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { onIncrement() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(
                            isExpired ? Color.white.opacity(0.2) : Color(.systemGray5),
                            in: Circle()
                        )
                        .foregroundStyle(isExpired ? .white : .primary)
                }
                .buttonStyle(.plain)
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
            if onAddToShoppingList != nil {
                Button {
                    if product.quantity == 1 {
                        showConsumeConfirm = true
                    } else {
                        onConsume()
                    }
                } label: {
                    Label("Used", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .confirmationDialog(
            "Mark as Used?",
            isPresented: $showConsumeConfirm,
            titleVisibility: .visible
        ) {
            Button("Mark as Used") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onConsume() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(product.name)\" will be removed from your fridge and added to the shopping list.")
        }
        .confirmationDialog(
            "Delete \"\(product.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the product from your fridge.")
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .sheet(isPresented: $showNote) {
            NotePopupView(note: product.notes, productName: product.name)
        }
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

    private var sanitizedAllergens: [String] {
        (product.allergens ?? []).compactMap { allergen in
            let trimmed = allergen.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private var allergenChipText: String? {
        guard let firstAllergen = sanitizedAllergens.first else { return nil }
        let extraCount = sanitizedAllergens.count - 1

        if extraCount > 0 {
            return "\(firstAllergen) +\(extraCount)"
        }

        return firstAllergen
    }

    private var allergenChipForeground: Color {
        isExpired ? .white : .red
    }

    private var allergenChipBackground: Color {
        isExpired ? Color.white.opacity(0.18) : Color.red.opacity(0.10)
    }
}

// MARK: - Note Popup

private struct NotePopupView: View {
    let note: String
    let productName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(productName, systemImage: "note.text")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            Text(note)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(24)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }
}
