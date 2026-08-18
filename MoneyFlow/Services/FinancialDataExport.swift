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
            loans: loans.map { loan in
                .init(
                    name: loan.name,
                    category: loan.category.rawValue,
                    totalAmount: loan.totalAmount,
                    remainingPrincipal: loan.remainingPrincipal,
                    annualRate: loan.annualRate,
                    repaymentMethod: loan.repaymentMethod.rawValue,
                    totalPeriods: loan.totalPeriods,
                    paidPeriods: loan.paidPeriods,
                    monthlyPayment: loan.monthlyPayment,
                    paymentDay: loan.paymentDayOfMonth,
                    adjustmentEvents: loan.adjustmentEvents.map {
                        .init(
                            date: $0.date,
                            periodIndex: $0.periodIndex,
                            type: $0.type.rawValue,
                            newAnnualRate: $0.newAnnualRate,
                            prepaymentAmount: $0.prepaymentAmount,
                            prepaymentEffect: $0.prepaymentEffect.rawValue,
                            note: $0.note
                        )
                    }
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
        let adjustmentEvents: [LoanAdjustmentSnapshot]?
    }

    private struct LoanAdjustmentSnapshot: Codable {
        let date: Date
        let periodIndex: Int
        let type: String
        let newAnnualRate: Double?
        let prepaymentAmount: Double?
        let prepaymentEffect: String?
        let note: String
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
