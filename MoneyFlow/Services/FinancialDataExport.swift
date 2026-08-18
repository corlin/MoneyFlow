import Foundation
import CoreTransferable
import UniformTypeIdentifiers

struct FinancialDataExport: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { export in
            export.data
        }
        .suggestedFileName("MoneyFlow-Backup.json")
    }

    static func make(
        accounts: [CashAccount],
        loans: [Loan],
        cards: [CreditCard],
        goals: [FinancialGoal] = []
    ) throws -> FinancialDataExport {
        let snapshot = Snapshot(
            exportedAt: Date(),
            accounts: accounts.map { .init(name: $0.name, balance: $0.balance, icon: $0.icon, note: $0.note) },
            loans: loans.map {
                .init(
                    name: $0.name,
                    category: $0.category.rawValue,
                    totalAmount: $0.totalAmount,
                    remainingPrincipal: $0.remainingPrincipal,
                    annualRate: $0.annualRate,
                    repaymentMethod: $0.repaymentMethod.rawValue,
                    totalPeriods: $0.totalPeriods,
                    paidPeriods: $0.paidPeriods,
                    monthlyPayment: $0.monthlyPayment,
                    paymentDay: $0.paymentDayOfMonth
                )
            },
            cards: cards.map {
                .init(name: $0.name, creditLimit: $0.creditLimit, currentBalance: $0.currentBalance, billingDay: $0.billingDay, dueDay: $0.dueDay)
            },
            goals: goals.map {
                .init(
                    name: $0.name,
                    category: $0.category.rawValue,
                    targetAmount: $0.targetAmount,
                    currentEarmarkedAmount: $0.currentEarmarkedAmount,
                    priority: $0.priority.rawValue,
                    targetDate: $0.targetDate,
                    note: $0.note
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return FinancialDataExport(data: try encoder.encode(snapshot))
    }

    private struct Snapshot: Codable {
        let exportedAt: Date
        let accounts: [Account]
        let loans: [LoanSnapshot]
        let cards: [Card]
        let goals: [GoalSnapshot]
    }

    private struct Account: Codable {
        let name: String
        let balance: Double
        let icon: String
        let note: String
    }

    private struct LoanSnapshot: Codable {
        let name: String
        let category: String
        let totalAmount: Double
        let remainingPrincipal: Double
        let annualRate: Double
        let repaymentMethod: String
        let totalPeriods: Int
        let paidPeriods: Int
        let monthlyPayment: Double
        let paymentDay: Int
    }

    private struct Card: Codable {
        let name: String
        let creditLimit: Double
        let currentBalance: Double
        let billingDay: Int
        let dueDay: Int
    }

    private struct GoalSnapshot: Codable {
        let name: String
        let category: String
        let targetAmount: Double
        let currentEarmarkedAmount: Double
        let priority: String
        let targetDate: Date?
        let note: String
    }
}
