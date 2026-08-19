import SwiftUI
import SwiftData

enum GoalArchetype: String, CaseIterable, Identifiable {
    case emergency = "emergency"
    case debtPaydown = "debtPaydown"
    case dreamMilestone = "dreamMilestone"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergency: return "🛡️ 应急防线"
        case .debtPaydown: return "⚡ 提前还贷"
        case .dreamMilestone: return "🎯 储蓄心愿"
        }
    }

    var subtitle: String {
        switch self {
        case .emergency: return "防御底线 · 自动锁定 Tier 1 必需"
        case .debtPaydown: return "加速脱困 · 优先结清高息贷款"
        case .dreamMilestone: return "阶段目标 · 置业/购车/心愿积累"
        }
    }
}

struct GoalFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var goalToEdit: FinancialGoal?
    var totalCash: Double
    var totalExistingEarmarked: Double
    var activeLoans: [Loan]
    var estimatedMonthlyMustPay: Double = 5000

    @State private var archetype: GoalArchetype = .emergency
    @State private var name: String = ""
    @State private var targetAmountString: String = ""
    @State private var earmarkedAmountString: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedLoan: Loan? = nil
    @State private var note: String = ""
    @State private var errorMessage: String? = nil

    private var isEditing: Bool { goalToEdit != nil }

    private var availableCashToEarmark: Double {
        let otherEarmarked = totalExistingEarmarked - (goalToEdit?.currentEarmarkedAmount ?? 0.0)
        return max(0.0, totalCash - otherEarmarked)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("选择目标类型") {
                        Picker("目标类型", selection: $archetype) {
                            ForEach(GoalArchetype.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: archetype) { _, newType in
                            applyArchetypeDefaults(newType)
                        }

                        Text(archetype.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("目标详情") {
                    TextField("目标名称", text: $name)

                    if archetype == .debtPaydown && !activeLoans.isEmpty {
                        Picker("选择加速清偿的贷款", selection: $selectedLoan) {
                            Text("请选择贷款...").tag(Optional<Loan>.none)
                            ForEach(activeLoans) { loan in
                                Text("\(loan.name) (年化 \(String(format: "%.1f", loan.annualRate * 100))%)")
                                    .tag(Optional(loan))
                            }
                        }
                        .onChange(of: selectedLoan) { _, loan in
                            if let loan {
                                name = "⚡ 提前结清\(loan.name)"
                                targetAmountString = String(format: "%.0f", loan.remainingPrincipal)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("目标总金额")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if archetype == .emergency {
                                HStack(spacing: 6) {
                                    Button("3个月 (\(Int(estimatedMonthlyMustPay * 3 / 1000))k)") {
                                        targetAmountString = String(format: "%.0f", estimatedMonthlyMustPay * 3)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption2.weight(.medium))

                                    Button("6个月 (\(Int(estimatedMonthlyMustPay * 6 / 1000))k)") {
                                        targetAmountString = String(format: "%.0f", estimatedMonthlyMustPay * 6)
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption2.weight(.medium))
                                }
                            }
                        }

                        TextField("如 50,000", text: $targetAmountString)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("存量现金分账") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("从当前存量现金中虚拟锁定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("可用: \(availableCashToEarmark.formattedCurrencyCompact)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        TextField("0.00 (纯靠月结余可填 0)", text: $earmarkedAmountString)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .monospaced))

                        if availableCashToEarmark > 0 {
                            HStack(spacing: 8) {
                                Button("清零") { earmarkedAmountString = "0" }
                                    .font(.caption2)
                                    .buttonStyle(.borderless)
                                Button("注入全部可用自由现金") {
                                    earmarkedAmountString = String(format: "%.0f", availableCashToEarmark)
                                }
                                .font(.caption2)
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                if archetype == .dreamMilestone {
                    Section("期望时间") {
                        Toggle("设定截止日期 (推演延期风险)", isOn: $hasTargetDate)

                        if hasTargetDate {
                            DatePicker("期望达成年月", selection: $targetDate, displayedComponents: [.date])
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑规划目标" : "新建规划目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveGoal() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private func applyArchetypeDefaults(_ type: GoalArchetype) {
        switch type {
        case .emergency:
            name = "🛡️ 3个月家庭应急防线"
            targetAmountString = String(format: "%.0f", max(10000, estimatedMonthlyMustPay * 3))
            hasTargetDate = false
        case .debtPaydown:
            if let firstLoan = activeLoans.first {
                selectedLoan = firstLoan
                name = "⚡ 提前结清\(firstLoan.name)"
                targetAmountString = String(format: "%.0f", firstLoan.remainingPrincipal)
            } else {
                name = "⚡ 提前还贷加速"
                targetAmountString = ""
            }
            hasTargetDate = false
        case .dreamMilestone:
            name = "🎯 置业/购车心愿"
            targetAmountString = ""
            hasTargetDate = true
        }
    }

    private func setupInitialValues() {
        if let goal = goalToEdit {
            name = goal.name
            targetAmountString = String(format: "%.0f", goal.targetAmount)
            earmarkedAmountString = goal.currentEarmarkedAmount > 0 ? String(format: "%.0f", goal.currentEarmarkedAmount) : ""
            if let date = goal.targetDate {
                hasTargetDate = true
                targetDate = date
            } else {
                hasTargetDate = false
            }
            note = goal.note
            if let loanId = goal.targetLoanId {
                selectedLoan = activeLoans.first { $0.id == loanId }
            }
            switch goal.category {
            case .emergencyBuffer: archetype = .emergency
            case .acceleratedDebtPaydown: archetype = .debtPaydown
            default: archetype = .dreamMilestone
            }
        } else {
            applyArchetypeDefaults(.emergency)
        }
    }

    private func saveGoal() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "请输入目标名称"
            return
        }

        guard let targetAmount = FinancialInputParser.number(from: targetAmountString), targetAmount > 0 else {
            errorMessage = "请输入有效的目标总金额"
            return
        }

        let earmarked = FinancialInputParser.number(from: earmarkedAmountString) ?? 0.0

        if earmarked > availableCashToEarmark {
            errorMessage = "分账锁定金额不能超过当前可用自由现金 (\(availableCashToEarmark.formattedCurrency))"
            return
        }

        let category: GoalCategory
        let priority: GoalPriority

        switch archetype {
        case .emergency:
            category = .emergencyBuffer
            priority = .essential
        case .debtPaydown:
            category = .acceleratedDebtPaydown
            priority = .important
        case .dreamMilestone:
            category = .capitalMilestone
            priority = .aspirational
        }

        if let existing = goalToEdit {
            existing.name = trimmedName
            existing.category = category
            existing.targetAmount = targetAmount
            existing.currentEarmarkedAmount = earmarked
            existing.priority = priority
            existing.targetDate = hasTargetDate ? targetDate : nil
            existing.targetLoanId = selectedLoan?.id
            existing.note = note
            existing.updatedAt = Date()
        } else {
            let newGoal = FinancialGoal(
                name: trimmedName,
                category: category,
                targetAmount: targetAmount,
                currentEarmarkedAmount: earmarked,
                priority: priority,
                targetDate: hasTargetDate ? targetDate : nil,
                targetLoanId: selectedLoan?.id,
                note: note
            )
            modelContext.insert(newGoal)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
