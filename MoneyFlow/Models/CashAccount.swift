import Foundation
import SwiftData

@Model
final class CashAccount {
    var id: UUID = UUID()
    var name: String = ""
    var balance: Double = 0
    var icon: String = "banknote"
    var note: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        icon: String = "banknote",
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.icon = icon
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func detachedCopy() -> CashAccount {
        CashAccount(
            id: id,
            name: name,
            balance: balance,
            icon: icon,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
