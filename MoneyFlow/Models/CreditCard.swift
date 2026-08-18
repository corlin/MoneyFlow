import Foundation
import SwiftData

@Model
final class CreditCard {
    var id: UUID = UUID()
    var name: String = ""
    var creditLimit: Double = 50000        // 信用额度
    var currentBalance: Double = 0         // 当前欠款额
    var billingDay: Int = 5                 // 账单日 (1-28)
    var dueDay: Int = 25                    // 到期还款日 (1-28)
    var icon: String = "creditcard.fill"
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Transient
    var availableCredit: Double {
        max(0, creditLimit - currentBalance)
    }

    @Transient
    var utilizationRate: Double {
        guard creditLimit > 0 else { return 0 }
        return min(1.0, max(0.0, currentBalance / creditLimit))
    }

    init(
        id: UUID = UUID(),
        name: String,
        creditLimit: Double = 50000,
        currentBalance: Double = 0,
        billingDay: Int = 5,
        dueDay: Int = 25,
        icon: String = "creditcard.fill",
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.creditLimit = creditLimit
        self.currentBalance = currentBalance
        self.billingDay = billingDay
        self.dueDay = dueDay
        self.icon = icon
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func detachedCopy() -> CreditCard {
        CreditCard(
            id: id,
            name: name,
            creditLimit: creditLimit,
            currentBalance: currentBalance,
            billingDay: billingDay,
            dueDay: dueDay,
            icon: icon,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
