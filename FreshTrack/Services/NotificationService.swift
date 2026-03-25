import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    var notificationHour: Int {
        let h = UserDefaults.standard.integer(forKey: "notificationHour")
        return h == 0 ? 9 : h
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

    func scheduleNotifications(for product: Product) {
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

        for (daysBefore, identifier) in triggers {
            guard let fireDate = notificationDate(for: product.expiryDate, daysBefore: daysBefore) else { continue }
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.threadIdentifier = "freshtrack-expiry"

            switch daysBefore {
            case 2:
                content.title = "Expiring in 2 days"
                content.body = "\(product.name) expires on \(formatDate(product.expiryDate)). Use it up!"
            case 1:
                content.title = "Expiring tomorrow!"
                content.body = "\(product.name) expires tomorrow. Don't let it go to waste."
            case 0:
                content.title = "Expires today!"
                content.body = "\(product.name) expires today."
            default:
                continue
            }

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
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

    func rescheduleAll(products: [Product]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for product in products where !product.isConsumed {
            scheduleNotifications(for: product)
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
        return fmt.string(from: date)
    }
}
