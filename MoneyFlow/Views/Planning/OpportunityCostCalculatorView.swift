import SwiftUI
import SwiftData

struct OpportunityCostCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Loan.createdAt) private var loans: [Loan]
    @Query private var cashAccounts: [CashAccount]

    /// 外部预传入的贷款（如从 LoanDetailView 传入）
    var initialLoan: Loan? = nil

    // MARK: - State

    @State private var selectedLoanID: UUID? = nil
    @State private var isManualMode: Bool = false

    // 参数输入
    @State private var lumpSumAmountString: String = "100000"
    @State private var manualRemainingPrincipalString: String = "1000000"
    @State private var manualRateString: String = "3.85"
    @State private var manualRemainingPeriods: Int = 240
    @State private var manualMethod: RepaymentMethod = .equalPayment
    @State private var prepaymentEffect: OpportunityCostPrepaymentEffect = .shortenTerm
    @State private var investmentAnnualRate: Double = 0.025 // 默认 2.5%

    // 总可用流动资金
    private var totalAvailableCash: Double {
        cashAccounts.reduce(0.0) { $0 + $1.balance }
    }

    private var activeLoan: Loan? {
        if let selectedLoanID {
            return loans.first { $0.id == selectedLoanID }
        }
        return nil
    }

    private var currentInput: OpportunityCostInput {
        let lumpSum = FinancialInputParser.number(from: lumpSumAmountString) ?? 0.0

        if !isManualMode, let loan = activeLoan {
            return OpportunityCostInput(
                lumpSumAmount: lumpSum,
                remainingPrincipal: loan.remainingPrincipal,
                loanAnnualRate: loan.latestAnnualRate,
                remainingPeriods: max(1, loan.totalPeriods - loan.paidPeriods),
                repaymentMethod: loan.repaymentMethod,
                prepaymentEffect: prepaymentEffect,
                investmentAnnualRate: investmentAnnualRate,
                availableCash: totalAvailableCash
            )
        } else {
            let principal = FinancialInputParser.number(from: manualRemainingPrincipalString) ?? 0.0
            let ratePercent = FinancialInputParser.number(from: manualRateString) ?? 3.85
            return OpportunityCostInput(
                lumpSumAmount: lumpSum,
                remainingPrincipal: principal,
                loanAnnualRate: ratePercent / 100.0,
                remainingPeriods: manualRemainingPeriods,
                repaymentMethod: manualMethod,
                prepaymentEffect: prepaymentEffect,
                investmentAnnualRate: investmentAnnualRate,
                availableCash: totalAvailableCash
            )
        }
    }

    private var calculationResult: OpportunityCostResult {
        OpportunityCostEngine.calculate(input: currentInput)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 顶部黄金决策卡片
                    verdictCard

                    // 2. 收益对比双色看板
                    comparisonVisualCard

                    // 3. 贷款与资金参数设置
                    loanParameterSection

                    // 4. 理财收益率配置
                    investmentParameterSection

                    // 5. 流动性安全评估
                    if let warning = calculationResult.liquidityWarning {
                        liquidityWarningCard(warning: warning)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("还贷 vs 理财机会成本精算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupInitialState()
            }
        }
    }

    // MARK: - Subviews

    private var verdictCard: some View {
        let result = calculationResult
        let themeColor: Color = {
            switch result.recommendation {
            case .stronglyPrepay, .prepay: return .green
            case .stronglyInvest, .invest: return .blue
            case .balanced: return .purple
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: result.recommendation.iconName)
                    .font(.headline)
                    .foregroundStyle(themeColor)

                Text(result.recommendation.rawValue)
                    .font(.headline)
                    .foregroundStyle(themeColor)

                Spacer()

                Text("差额 \(abs(result.netAdvantage).formattedCurrencyCompact)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColor)
            }

            Text(result.verdictStatement)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(.primary)

            Divider()
                .opacity(0.6)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("保本平衡理财利率")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(result.breakEvenInvestmentRate.formattedRatePercentage)
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if result.periodsSaved > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("还清时间提前")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(result.periodsSaved) 个月")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                    }
                } else if result.newMonthlyPayment > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("月供降至")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(result.newMonthlyPayment.formattedCurrencyCompact)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(themeColor.opacity(0.25), lineWidth: 1.2)
        }
    }

    private var comparisonVisualCard: some View {
        let result = calculationResult
        let maxVal = max(result.loanInterestSaved, result.investmentTotalReturn, 1.0)
        let prepayRatio = min(1.0, result.loanInterestSaved / maxVal)
        let investRatio = min(1.0, result.investmentTotalReturn / maxVal)

        return VStack(alignment: .leading, spacing: 14) {
            Text("收益对标对比 (对标 \(result.comparisonHorizonMonths) 个月)")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // 提前还贷省息条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("提前还贷节省总利息", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.loanInterestSaved.formattedCurrency)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(uiColor: .tertiarySystemFill))
                        Capsule()
                            .fill(LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * prepayRatio))
                    }
                }
                .frame(height: 10)
            }

            // 稳健理财收益条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("稳健理财复利总收益", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(result.investmentTotalReturn.formattedCurrency)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(uiColor: .tertiarySystemFill))
                        Capsule()
                            .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * investRatio))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var loanParameterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("贷款与闲钱设置")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            // 选择已有贷款 or 手动模式
            Picker("数据来源", selection: $isManualMode) {
                Text("从已有贷款选择").tag(false)
                Text("自定义借款参数").tag(true)
            }
            .pickerStyle(.segmented)

            if !isManualMode {
                if loans.isEmpty {
                    Text("当前暂无已录入贷款，已自动切换为自定义模式。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("选择目标贷款", selection: $selectedLoanID) {
                        ForEach(loans) { loan in
                            Text("\(loan.name) (年化 \(loan.latestAnnualRate.formattedRatePercentage))")
                                .tag(Optional(loan.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                // 手动参数输入
                VStack(spacing: 10) {
                    HStack {
                        Text("剩余本金 (元)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("1000000", text: $manualRemainingPrincipalString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                    }
                    Divider()

                    HStack {
                        Text("年化利率 (%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("3.85", text: $manualRateString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .monospaced))
                    }
                    Divider()

                    HStack {
                        Text("剩余期数 (月)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(manualRemainingPeriods) 期 (\(manualRemainingPeriods / 12)年)", value: $manualRemainingPeriods, in: 6...360, step: 12)
                            .font(.caption)
                    }
                }
            }

            Divider()

            // 拟提前还款/理财金额
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("拟对比闲钱金额 (元)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("100000", text: $lumpSumAmountString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.headline, design: .monospaced, weight: .bold))
                }

                // 快捷比例标签
                HStack(spacing: 8) {
                    quickAmountChip(title: "5 万", amount: 50_000)
                    quickAmountChip(title: "10 万", amount: 100_000)
                    quickAmountChip(title: "20 万", amount: 200_000)
                    if let loan = activeLoan {
                        quickAmountChip(title: "全额结清", amount: loan.remainingPrincipal)
                    }
                }
            }

            Divider()

            // 还贷效果选择
            VStack(alignment: .leading, spacing: 8) {
                Text("提前还款倾向")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("还款策略", selection: $prepaymentEffect) {
                    ForEach(OpportunityCostPrepaymentEffect.allCases) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var investmentParameterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("理财预期年化收益率")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(investmentAnnualRate.formattedRatePercentage)
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.blue)
            }

            Slider(value: $investmentAnnualRate, in: 0.01...0.08, step: 0.001) {
                Text("理财年化")
            }
            .tint(.blue)

            HStack(spacing: 8) {
                ratePresetChip(title: "固收 2.0%", rate: 0.020)
                ratePresetChip(title: "大额存单 2.5%", rate: 0.025)
                ratePresetChip(title: "增额寿 3.0%", rate: 0.030)
                ratePresetChip(title: "固收+ 4.0%", rate: 0.040)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func liquidityWarningCard(warning: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            Text(warning)
                .font(.caption)
                .lineSpacing(3)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 0.8)
        }
    }

    private func quickAmountChip(title: String, amount: Double) -> some View {
        Button {
            lumpSumAmountString = String(format: "%.0f", amount)
        } label: {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.appSpring)
    }

    private func ratePresetChip(title: String, rate: Double) -> some View {
        let isSelected = abs(investmentAnnualRate - rate) < 0.0005
        return Button {
            investmentAnnualRate = rate
        } label: {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color(uiColor: .tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.appSpring)
    }

    private func setupInitialState() {
        if let initialLoan {
            selectedLoanID = initialLoan.id
            isManualMode = false
        } else if let firstLoan = loans.first {
            selectedLoanID = firstLoan.id
            isManualMode = false
        } else {
            isManualMode = true
        }
    }
}
