import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    var notificationHour: Int {
        let h = UserDefaults.standard.integer(forKey: "notificationHour")
        return h == 0 ? 9 : h
    }

    private var isTurkish: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return settings.authorizationStatus == .authorized
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        return granted
    }

    func scheduleNotifications(for product: Product, cabinetName: String? = nil) {
        let center = UNUserNotificationCenter.current()
        let idPrefix = product.id.uuidString

        center.removePendingNotificationRequests(withIdentifiers: [
            "\(idPrefix)-2day",
            "\(idPrefix)-1day",
            "\(idPrefix)-0day"
        ])

        let triggers: [(Int, String)] = [
            (2, "\(idPrefix)-2day"),
            (1, "\(idPrefix)-1day"),
            (0, "\(idPrefix)-0day")
        ]

        let tr = isTurkish
        let cabinet = cabinetName.map { " (\($0))" } ?? ""

        for (daysBefore, identifier) in triggers {
            guard let fireDate = notificationDate(for: product.expiryDate, daysBefore: daysBefore) else { continue }
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.threadIdentifier = "freshtrack-expiry"

            switch daysBefore {
            case 2:
                content.title = tr ? "2 gün içinde bitiyor" : "Expiring in 2 days"
                content.body  = tr
                    ? "\(product.name)\(cabinet) \(formatDate(product.expiryDate)) tarihinde bitiyor. Kullanmayı unutma!"
                    : "\(product.name)\(cabinet) expires on \(formatDate(product.expiryDate)). Use it up!"
            case 1:
                content.title = tr ? "Yarın bitiyor!" : "Expiring tomorrow!"
                content.body  = tr
                    ? "\(product.name)\(cabinet) yarın bitiyor. İsraf etme."
                    : "\(product.name)\(cabinet) expires tomorrow. Don't let it go to waste."
            case 0:
                content.title = tr ? "Bugün bitiyor!" : "Expires today!"
                content.body  = tr
                    ? "\(product.name)\(cabinet) bugün bitiyor."
                    : "\(product.name)\(cabinet) expires today."
            default:
                continue
            }

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    func cancelNotifications(for product: Product) {
        let idPrefix = product.id.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(idPrefix)-2day",
            "\(idPrefix)-1day",
            "\(idPrefix)-0day"
        ])
    }

    // iOS limiti: uygulama başına 64 pending notification.
    // Her ürün 3 bildirim → max 21 ürün. En yakın tarihlileri önceliklendir.
    func rescheduleAll(products: [Product], cabinets: [Cabinet] = []) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let active = products
            .filter { !$0.isConsumed && $0.expiryDate > Date() }
            .sorted { $0.expiryDate < $1.expiryDate }
            .prefix(21)
        for product in active {
            let cabinetName = cabinets.first(where: { $0.id == product.cabinetID })?.name
            scheduleNotifications(for: product, cabinetName: cabinetName)
        }
    }

    // MARK: - Helpers

    private func notificationDate(for expiryDate: Date, daysBefore: Int) -> Date? {
        let calendar = Calendar.current
        let expiryDay = calendar.startOfDay(for: expiryDate)
        guard let notifDay = calendar.date(byAdding: .day, value: -daysBefore, to: expiryDay) else { return nil }
        return calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: notifDay)
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        fmt.locale = Locale.current
        return fmt.string(from: date)
    }
}
