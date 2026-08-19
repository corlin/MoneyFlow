import SwiftUI
import SwiftData

struct LoanAdjustmentEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let loan: Loan
    var eventToEdit: LoanAdjustmentEvent? = nil
    var defaultType: AdjustmentType = .rateAdjustment

    @State private var type: AdjustmentType = .rateAdjustment
    @State private var eventDate: Date = Date()
    @State private var periodIndex: Int = 1
    @State private var rateString: String = ""
    @State private var prepaymentAmountString: String = ""
    @State private var prepaymentEffect: PrepaymentEffect = .reducePayment
    @State private var note: String = ""
    @State private var errorMessage: String? = nil

    private var isEditing: Bool { eventToEdit != nil }

    // 实时推演比较
    private var simulatedNewRate: Double? {
        guard let r = FinancialInputParser.number(from: rateString) else { return nil }
        return r > 1.0 ? r / 100.0 : r
    }

    private var simulatedPrepaymentAmount: Double {
        FinancialInputParser.number(from: prepaymentAmountString) ?? 0.0
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("选择事件类型") {
                        Picker("事件类型", selection: $type) {
                            ForEach(AdjustmentType.allCases) { t in
                                Label(t.title, systemImage: t.systemImage).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("生效时间与期数") {
                    DatePicker("生效日期", selection: $eventDate, displayedComponents: [.date])
                    HStack {
                        Text("对应生效期数")
                        Spacer()
                        TextField("期数", value: $periodIndex, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                        Text("期")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $periodIndex, in: 1...max(loan.totalPeriods, 600))
                            .labelsHidden()
                    }
                }

                if type == .rateAdjustment {
                    rateAdjustmentSection
                } else {
                    prepaymentSection
                }

                Section("备注说明 (可选)") {
                    TextField("如：2024年10月存量房贷统一下调", text: $note)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑变更记录" : (type == .rateAdjustment ? "记录利率调整" : "记录提前还款"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveEvent() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupInitialData()
            }
        }
    }

    // MARK: - 利率调整表单与实时影响
    private var rateAdjustmentSection: some View {
        Section("新执行利率") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("年化利率 (%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("当前: \(loan.latestAnnualRate.formattedRatePercentage)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TextField("如 3.1250", text: $rateString)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))
            }

            if let newRate = simulatedNewRate, newRate > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚡ 调息影响实时预览")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)

                    let diff = newRate - loan.annualRate
                    HStack {
                        Text("利率变化:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(loan.annualRate.formattedRatePercentage) → \(newRate.formattedRatePercentage) (\(diff >= 0 ? "+" : "")\(diff.formattedRatePercentage))")
                            .font(.caption2.bold())
                            .foregroundStyle(diff <= 0 ? .green : .red)
                    }

                    Text("保存后将自动从第 \(periodIndex) 期开始，以新利率分段重算后续所有月供与利息。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - 提前还贷表单与方案对比
    private var prepaymentSection: some View {
        Section("提前还贷设置") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("提前偿还本金 (元)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("剩余本金: \(loan.remainingPrincipal.formattedCurrencyCompact)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TextField("如 100,000", text: $prepaymentAmountString)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))
            }

            Picker("还款后重算方式", selection: $prepaymentEffect) {
                ForEach(PrepaymentEffect.allCases) { eff in
                    Text(eff.title).tag(eff)
                }
            }

            Text(prepaymentEffect.description)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if simulatedPrepaymentAmount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 方案收益测算")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        benefitBox(
                            title: "月供降低",
                            subtitle: "期限不变 · 现金流改善",
                            isSelected: prepaymentEffect == .reducePayment
                        ) {
                            prepaymentEffect = .reducePayment
                        }

                        benefitBox(
                            title: "期限缩短",
                            subtitle: "提前无债 · 省息最大化",
                            isSelected: prepaymentEffect == .shortenTerm
                        ) {
                            prepaymentEffect = .shortenTerm
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func benefitBox(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.bold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.borderless)
    }

    private func setupInitialData() {
        if let existing = eventToEdit {
            type = existing.type
            eventDate = existing.date
            periodIndex = existing.periodIndex
            if let rate = existing.newAnnualRate {
                rateString = (rate * 100).formatted(.number.precision(.fractionLength(0...4)))
            }
            if let amount = existing.prepaymentAmount {
                prepaymentAmountString = String(format: "%.0f", amount)
            }
            prepaymentEffect = existing.prepaymentEffect
            note = existing.note
        } else {
            type = defaultType
            eventDate = Date()
            periodIndex = max(1, loan.paidPeriods + 1)
            rateString = (loan.latestAnnualRate * 100).formatted(.number.precision(.fractionLength(0...4)))
        }
    }

    private func saveEvent() {
        if type == .rateAdjustment {
            guard let rate = simulatedNewRate, rate > 0 else {
                errorMessage = "请输入有效的新年化利率"
                return
            }

            if let existing = eventToEdit {
                existing.date = eventDate
                existing.periodIndex = periodIndex
                existing.type = .rateAdjustment
                existing.newAnnualRate = rate
                existing.note = note
                existing.updatedAt = Date()
            } else {
                let newEvent = LoanAdjustmentEvent(
                    date: eventDate,
                    periodIndex: periodIndex,
                    type: .rateAdjustment,
                    newAnnualRate: rate,
                    note: note,
                    loan: loan
                )
                loan.adjustmentEvents.append(newEvent)
                modelContext.insert(newEvent)
            }
        } else {
            let amount = simulatedPrepaymentAmount
            guard amount > 0 else {
                errorMessage = "请输入有效的提前还款金额"
                return
            }

            if let existing = eventToEdit {
                existing.date = eventDate
                existing.periodIndex = periodIndex
                existing.type = .prepayment
                existing.prepaymentAmount = amount
                existing.prepaymentEffect = prepaymentEffect
                existing.note = note
                existing.updatedAt = Date()
            } else {
                let newEvent = LoanAdjustmentEvent(
                    date: eventDate,
                    periodIndex: periodIndex,
                    type: .prepayment,
                    prepaymentAmount: amount,
                    prepaymentEffect: prepaymentEffect,
                    note: note,
                    loan: loan
                )
                loan.adjustmentEvents.append(newEvent)
                modelContext.insert(newEvent)
            }
        }

        loan.updatedAt = Date()

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
