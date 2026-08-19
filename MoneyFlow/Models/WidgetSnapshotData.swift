import Foundation

public struct WidgetUpcomingItem: Codable, Identifiable, Equatable {
    public var id: String
    public var title: String
    public var amount: Double
    public var dueDate: Date
    public var daysRemaining: Int
    public var isLoan: Bool
    public var icon: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        dueDate: Date,
        daysRemaining: Int,
        isLoan: Bool,
        icon: String = "calendar"
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDate = dueDate
        self.daysRemaining = daysRemaining
        self.isLoan = isLoan
        self.icon = icon
    }
}

public struct WidgetSnapshotData: Codable, Equatable {
    public var availableCash: Double
    public var predictedEndingCash: Double
    public var totalMustPayThisMonth: Double
    public var dsrRatio: Double
    public var riskStatusText: String
    public var riskStatusColorHex: String
    public var nearestReminder: WidgetUpcomingItem?
    public var upcomingReminders: [WidgetUpcomingItem]
    public var lastUpdated: Date

    public init(
        availableCash: Double = 0,
        predictedEndingCash: Double = 0,
        totalMustPayThisMonth: Double = 0,
        dsrRatio: Double = 0,
        riskStatusText: String = "资金充裕",
        riskStatusColorHex: String = "#34C759",
        nearestReminder: WidgetUpcomingItem? = nil,
        upcomingReminders: [WidgetUpcomingItem] = [],
        lastUpdated: Date = Date()
    ) {
        self.availableCash = availableCash
        self.predictedEndingCash = predictedEndingCash
        self.totalMustPayThisMonth = totalMustPayThisMonth
        self.dsrRatio = dsrRatio
        self.riskStatusText = riskStatusText
        self.riskStatusColorHex = riskStatusColorHex
        self.nearestReminder = nearestReminder
        self.upcomingReminders = upcomingReminders
        self.lastUpdated = lastUpdated
    }

    public static let placeholder = WidgetSnapshotData(
        availableCash: 68500,
        predictedEndingCash: 52400,
        totalMustPayThisMonth: 8200,
        dsrRatio: 0.28,
        riskStatusText: "资金充裕",
        riskStatusColorHex: "#34C759",
        nearestReminder: WidgetUpcomingItem(
            title: "招商银行房贷",
            amount: 5200,
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            daysRemaining: 3,
            isLoan: true,
            icon: "house.fill"
        ),
        upcomingReminders: [
            WidgetUpcomingItem(title: "招商银行房贷", amount: 5200, dueDate: Date(), daysRemaining: 3, isLoan: true, icon: "house.fill"),
            WidgetUpcomingItem(title: "车贷月供", amount: 1800, dueDate: Date(), daysRemaining: 8, isLoan: true, icon: "car.fill"),
            WidgetUpcomingItem(title: "工行信用卡", amount: 1200, dueDate: Date(), daysRemaining: 15, isLoan: false, icon: "creditcard.fill")
        ],
        lastUpdated: Date()
    )

    public static let appGroupIdentifier = "group.com.moneyflow.app"
    public static let snapshotKey = "moneyflow_widget_snapshot"

    public static func loadFromSharedDefaults() -> WidgetSnapshotData {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshotData.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }

    public func saveToSharedDefaults() {
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? UserDefaults.standard
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.snapshotKey)
        }
    }
}
