import Foundation
import SwiftData

enum DemoPersona: String, CaseIterable, Identifiable {
    case debtRelief = "debtRelief"           // 画像 1：负债加速突围型
    case multiGoalGrowth = "multiGoalGrowth" // 画像 2：多目标置业积累型

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debtRelief: return "画像 1：负债突围与安全筑底 (高 DSR / 雪崩省息)"
        case .multiGoalGrowth: return "画像 2：多目标稳健积累 (充裕结余 / 动态灌溉)"
        }
    }

    var shortTitle: String {
        switch self {
        case .debtRelief: return "负债突围画像"
        case .multiGoalGrowth: return "多目标积累画像"
        }
    }

    var subtitle: String {
        switch self {
        case .debtRelief: return "房贷 + 7.2% 高息消费贷，流动性承压，DSR 达 63%，急需雪崩法脱困与建立应急金"
        case .multiGoalGrowth: return "低息公积金贷，月结余 ¥1.6万，3 大梯队目标（应急金/车/首付）自适应灌溉"
        }
    }
}

enum DemoDataService {

    @MainActor
    static func load(into context: ModelContext, replacingExisting: Bool = false, persona: DemoPersona = .debtRelief) throws {
        if replacingExisting {
            for account in try context.fetch(FetchDescriptor<CashAccount>()) { context.delete(account) }
            for loan in try context.fetch(FetchDescriptor<Loan>()) { context.delete(loan) }
            for card in try context.fetch(FetchDescriptor<CreditCard>()) { context.delete(card) }
            for goal in try context.fetch(FetchDescriptor<FinancialGoal>()) { context.delete(goal) }
            for event in try context.fetch(FetchDescriptor<LoanAdjustmentEvent>()) { context.delete(event) }
        }

        // 获取或初始化 UserSettings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let existingSettings = try context.fetch(settingsDescriptor).first
        let settings = existingSettings ?? UserSettings()
        if existingSettings == nil {
            context.insert(settings)
        }

        switch persona {
        case .debtRelief:
            loadDebtReliefPersona(into: context, settings: settings)
        case .multiGoalGrowth:
            loadMultiGoalGrowthPersona(into: context, settings: settings)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func loadDebtReliefPersona(into context: ModelContext, settings: UserSettings) {
        // 设置参数
        settings.monthlyEstimatedIncome = 18000
        settings.monthlyLivingExpense = 5000
        settings.rateThreshold = 0.05
        settings.emergencyFundMonthsTarget = 3

        // 资产
        let bankAccount = CashAccount(
            name: "工商银行工资卡",
            balance: 18000,
            icon: "banknote",
            note: "主要流动资金"
        )
        let wechatAccount = CashAccount(
            name: "微信零钱",
            balance: 3500,
            icon: "dollarsign.circle",
            note: "日常小额零花"
        )
        context.insert(bankAccount)
        context.insert(wechatAccount)

        // 负债 1: 商业房贷 (初始 4.30%，历经调息与还本)
        let houseLoan = Loan(
            name: "住宅商业按揭",
            category: .mortgage,
            totalAmount: 1200000,
            remainingPrincipal: 980000,
            annualRate: 0.0430,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 36,
            monthlyPayment: 6740,
            paymentDayOfMonth: 10,
            startDate: Date().addingMonths(-36),
            endDate: Date().addingMonths(204),
            totalInterestPaid: 132000,
            icon: "house.fill",
            note: "首套房按揭贷款，历经两次调息与一次提前还本"
        )
        context.insert(houseLoan)

        // 房贷变更事件 1：2024年元旦 LPR 重定价由 4.30% 降至 3.85%
        let event1 = LoanAdjustmentEvent(
            date: Date().addingMonths(-24),
            periodIndex: 12,
            type: .rateAdjustment,
            newAnnualRate: 0.0385,
            note: "2024年1月1日 LPR 年度重定价",
            loan: houseLoan
        )
        // 房贷变更事件 2：2024年10月 提前还贷 5 万元
        let event2 = LoanAdjustmentEvent(
            date: Date().addingMonths(-14),
            periodIndex: 22,
            type: .prepayment,
            prepaymentAmount: 50000,
            prepaymentEffect: .reducePayment,
            note: "年终奖金提前偿还本金，减轻月供压力",
            loan: houseLoan
        )
        houseLoan.adjustmentEvents.append(event1)
        houseLoan.adjustmentEvents.append(event2)
        context.insert(event1)
        context.insert(event2)

        // 负债 2: 装修消费贷 (7.2% 高息贷款)
        let renovationLoan = Loan(
            name: "房屋装修消费贷",
            category: .consumerLoan,
            totalAmount: 150000,
            remainingPrincipal: 110000,
            annualRate: 0.072,
            repaymentMethod: .equalPayment,
            totalPeriods: 36,
            paidPeriods: 10,
            monthlyPayment: 4645,
            paymentDayOfMonth: 15,
            startDate: Date().addingMonths(-10),
            endDate: Date().addingMonths(26),
            totalInterestPaid: 8900,
            icon: "hammer.fill",
            note: "年化 7.2% 高息消费贷款，建议优先雪崩加速结清"
        )
        context.insert(renovationLoan)

        // 信用卡
        let creditCard = CreditCard(
            name: "招行白金信用卡",
            creditLimit: 40000,
            currentBalance: 8200,
            billingDay: 5,
            dueDay: 25,
            icon: "creditcard.fill",
            note: "当期应还账单"
        )
        context.insert(creditCard)

        // 目标
        let emergencyGoal = FinancialGoal(
            name: "🛡️ 3个月应急储备金",
            category: .emergencyBuffer,
            targetAmount: 35000,
            currentEarmarkedAmount: 10000,
            priority: .essential,
            targetDate: Date().addingMonths(8),
            note: "覆盖 3 个月刚性生活与还贷支出"
        )

        let debtFreeGoal = FinancialGoal(
            name: "⚡ 提前加速结清装修贷",
            category: .acceleratedDebtPaydown,
            targetAmount: 110000,
            currentEarmarkedAmount: 0,
            priority: .important,
            targetDate: Date().addingMonths(20),
            targetLoanId: renovationLoan.id,
            note: "通过雪崩法全力提前还清 7.2% 高息负债"
        )
        context.insert(emergencyGoal)
        context.insert(debtFreeGoal)
    }

    @MainActor
    private static func loadMultiGoalGrowthPersona(into context: ModelContext, settings: UserSettings) {
        // 设置参数
        settings.monthlyEstimatedIncome = 26000
        settings.monthlyLivingExpense = 6500
        settings.rateThreshold = 0.05
        settings.emergencyFundMonthsTarget = 6

        // 资产
        let bankAccount = CashAccount(
            name: "建设银行储蓄卡",
            balance: 65000,
            icon: "banknote",
            note: "家庭主要资金"
        )
        let fundAccount = CashAccount(
            name: "招商银行朝朝宝/货基",
            balance: 120000,
            icon: "chart.line.uptrend.xyaxis",
            note: "高流动性理财"
        )
        let alipayAccount = CashAccount(
            name: "支付宝余额宝",
            balance: 15000,
            icon: "dollarsign.circle",
            note: "日常零用"
        )
        context.insert(bankAccount)
        context.insert(fundAccount)
        context.insert(alipayAccount)

        // 负债: 纯公积金房贷 (2.85% 超低息)
        let provLoan = Loan(
            name: "公积金自住按揭",
            category: .mortgage,
            totalAmount: 600000,
            remainingPrincipal: 450000,
            annualRate: 0.0310,
            repaymentMethod: .equalPayment,
            totalPeriods: 240,
            paidPeriods: 60,
            monthlyPayment: 3280,
            paymentDayOfMonth: 20,
            startDate: Date().addingMonths(-60),
            endDate: Date().addingMonths(180),
            totalInterestPaid: 76000,
            icon: "house.fill",
            note: "优质公积金低息贷款"
        )
        context.insert(provLoan)

        // 公积金降息事件：2024年5月公积金降息至 2.85%
        let provEvent = LoanAdjustmentEvent(
            date: Date().addingMonths(-18),
            periodIndex: 42,
            type: .rateAdjustment,
            newAnnualRate: 0.0285,
            note: "2024年5月全国公积金贷款利率统一降息",
            loan: provLoan
        )
        provLoan.adjustmentEvents.append(provEvent)
        context.insert(provEvent)

        // 信用卡
        let creditCard = CreditCard(
            name: "浦发银行信用卡",
            creditLimit: 50000,
            currentBalance: 2100,
            billingDay: 2,
            dueDay: 18,
            icon: "creditcard.fill",
            note: "常规月度消费"
        )
        context.insert(creditCard)

        // 目标梯队
        let emergencyGoal = FinancialGoal(
            name: "🛡️ 6个月家庭防御备用金",
            category: .emergencyBuffer,
            targetAmount: 50000,
            currentEarmarkedAmount: 50000,
            priority: .essential,
            targetDate: Date().addingMonths(1),
            note: "已足额构建完毕的安全防御底线"
        )

        let carGoal = FinancialGoal(
            name: "🚗 购置新能源心愿车",
            category: .capitalMilestone,
            targetAmount: 180000,
            currentEarmarkedAmount: 80000,
            priority: .important,
            targetDate: Date().addingMonths(10),
            note: "计划在未来 10 个月内达成"
        )

        let downpaymentGoal = FinancialGoal(
            name: "🏡 改善置业首付蓄水池",
            category: .wealthAccumulation,
            targetAmount: 500000,
            currentEarmarkedAmount: 40000,
            priority: .aspirational,
            targetDate: Date().addingMonths(30),
            note: "长期资产积累"
        )

        context.insert(emergencyGoal)
        context.insert(carGoal)
        context.insert(downpaymentGoal)
    }
}
