import Foundation
import SwiftData
import SwiftUI

@Model
final class Cabinet {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var createdDate: Date

    init(name: String, icon: String = "refrigerator", colorHex: String = "34C759") {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdDate = Date()
    }

    var color: Color {
        Color(hex: colorHex) ?? .teal
    }
}

// MARK: - Color Hex helpers

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }

    func toHex() -> String {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
