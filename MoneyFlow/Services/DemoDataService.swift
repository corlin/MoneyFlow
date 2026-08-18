import Foundation
import SwiftData

enum DemoDataService {
    @MainActor
    static func load(into context: ModelContext, replacingExisting: Bool = false) throws {
        if replacingExisting {
            for account in try context.fetch(FetchDescriptor<CashAccount>()) { context.delete(account) }
            for loan in try context.fetch(FetchDescriptor<Loan>()) { context.delete(loan) }
            for card in try context.fetch(FetchDescriptor<CreditCard>()) { context.delete(card) }
        }
        // 1. 资产账户
        let bankAccount = CashAccount(
            name: "招商银行储蓄卡",
            balance: 280000,
            icon: "banknote",
            note: "家庭日常备用金及流动性储备"
        )
        let fundAccount = CashAccount(
            name: "余额宝/货币基金",
            balance: 85000,
            icon: "dollarsign.circle",
            note: "随时可赎回的现金理财"
        )
        context.insert(bankAccount)
        context.insert(fundAccount)

        // 2. 房贷（低于默认利率基准，3.4%）
        let houseLoan = Loan(
            name: "首套房按揭贷款",
            category: .mortgage,
            totalAmount: 1800000,
            remainingPrincipal: 1560000,
            annualRate: 0.034,
            repaymentMethod: .equalPayment,
            totalPeriods: 360,
            paidPeriods: 48,
            monthlyPayment: 7980,
            paymentDayOfMonth: 10,
            startDate: Date().addingMonths(-48),
            endDate: Date().addingMonths(312),
            totalInterestPaid: 285000,
            icon: "house.fill",
            note: "优质公积金+商贷组合"
        )

        // 3. 车贷（5.2%，高于默认利率关注基准）
        let carLoan = Loan(
            name: "新能源车分期",
            category: .carLoan,
            totalAmount: 150000,
            remainingPrincipal: 85000,
            annualRate: 0.052,
            repaymentMethod: .equalPrincipal,
            totalPeriods: 36,
            paidPeriods: 16,
            monthlyPayment: 4530,
            paymentDayOfMonth: 20,
            startDate: Date().addingMonths(-16),
            endDate: Date().addingMonths(20),
            totalInterestPaid: 9200,
            icon: "car.fill",
            note: "3年期车贷"
        )

        context.insert(houseLoan)
        context.insert(carLoan)

        // 4. 信用卡
        let creditCard = CreditCard(
            name: "招商经典白金卡",
            creditLimit: 60000,
            currentBalance: 12800,
            billingDay: 5,
            dueDay: 25,
            icon: "creditcard.fill",
            note: "日常刷卡及商旅消费"
        )
        context.insert(creditCard)

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
