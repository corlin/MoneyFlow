import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized: Bool = false

    private init() {
        Task {
            await checkAuthorization()
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            return granted
        } catch {
            self.isAuthorized = false
            return false
        }
    }

    /// 调度全量未结清贷款与信用卡的本地还款提醒
    func scheduleAllReminders(
        loans: [Loan],
        creditCards: [CreditCard],
        isEnabled: Bool,
        daysBefore: Int = 3
    ) {
        guard isEnabled else {
            cancelAllReminders()
            return
        }

        cancelAllReminders()

        let calendar = Calendar.current
        let today = Date()
        let reminders = RiskAnalyzer.getUpcomingReminders(loans: loans, creditCards: creditCards, daysAhead: 30)

        for item in reminders {
            let idString = item.sourceID?.uuidString ?? UUID().uuidString

            // 1. 提前预警 (例如提前 daysBefore 天 09:30)
            if let advanceDate = calendar.date(byAdding: .day, value: -daysBefore, to: item.dueDate), advanceDate > today {
                scheduleSingleNotification(
                    identifier: "mf_payment_adv_\(idString)",
                    title: "🔔 还款预警提醒",
                    body: "您的「\(item.title)」将于 \(daysBefore) 天后（\(item.dueDate.monthDayString)）扣款 \(item.amount.formattedCurrencyCompact)，请留意账户可用余额。",
                    targetDate: advanceDate,
                    hour: 9,
                    minute: 30
                )
            }

            // 2. 当日关键提醒 (还款日当天 09:00)
            if item.dueDate >= calendar.startOfDay(for: today) {
                scheduleSingleNotification(
                    identifier: "mf_payment_due_\(idString)",
                    title: "⏰ 今日还款提醒",
                    body: "今天是「\(item.title)」还款日，待还金额 \(item.amount.formattedCurrencyCompact)，请确认还款扣款顺利。",
                    targetDate: item.dueDate,
                    hour: 9,
                    minute: 0
                )
            }
        }
    }

    /// 当用户在 App 内完成本期还款时，实时核销该笔账目的未触发通知
    func cancelReminder(for sourceId: UUID) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "mf_payment_adv_\(sourceId.uuidString)",
            "mf_payment_due_\(sourceId.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let mfIds = requests.filter { $0.identifier.hasPrefix("mf_payment_") }.map(\.identifier)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: mfIds)
        }
    }

    private func scheduleSingleNotification(
        identifier: String,
        title: String,
        body: String,
        targetDate: Date,
        hour: Int,
        minute: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
