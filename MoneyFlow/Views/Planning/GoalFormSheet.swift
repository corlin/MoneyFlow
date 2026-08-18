import SwiftUI
import SwiftData

struct GoalFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var goalToEdit: FinancialGoal?
    var totalCash: Double
    var totalExistingEarmarked: Double
    var activeLoans: [Loan]

    @State private var name: String = ""
    @State private var category: GoalCategory = .capitalMilestone
    @State private var targetAmountString: String = ""
    @State private var earmarkedAmountString: String = ""
    @State private var priority: GoalPriority = .important
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedLoanId: UUID? = nil
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
                Section("目标基本信息") {
                    TextField("目标名称（如：购车首付、应急金）", text: $name)

                    Picker("目标类别", selection: $category) {
                        ForEach(GoalCategory.allCases) { cat in
                            Label(cat.title, systemImage: cat.systemImage).tag(cat)
                        }
                    }

                    Picker("规划优先级", selection: $priority) {
                        ForEach(GoalPriority.allCases) { pri in
                            Text(pri.title).tag(pri)
                        }
                    }
                }

                Section("资金与分账") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("目标所需总金额")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("如 100,000", text: $targetAmountString)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("从当前存量现金中虚拟分账锁定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("可用自由现金: \(availableCashToEarmark.formattedCurrency(style: .compact))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        TextField("如 20,000 (可为 0)", text: $earmarkedAmountString)
                            .keyboardType(.decimalPad)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                if category == .acceleratedDebtPaydown && !activeLoans.isEmpty {
                    Section("关联加速还款贷款") {
                        Picker("指定偿还贷款", selection: $selectedLoanId) {
                            Text("无特定贷款 (全量加速)").tag(Optional<UUID>.none)
                            ForEach(activeLoans) { loan in
                                Text("\(loan.name) (年化 \(String(format: "%.1f", loan.annualRate * 100))%)")
                                    .tag(Optional(loan.id))
                            }
                        }
                    }
                }

                Section("期望达成时间") {
                    Toggle("设定截止日期 (用于推演延期风险)", isOn: $hasTargetDate)

                    if hasTargetDate {
                        DatePicker("期望达成年月", selection: $targetDate, displayedComponents: [.date])
                    }
                }

                Section("备注说明") {
                    TextField("记录目标背景或具体考量（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑目标" : "新建规划目标")
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

    private func setupInitialValues() {
        if let goal = goalToEdit {
            name = goal.name
            category = goal.category
            targetAmountString = String(format: "%.0f", goal.targetAmount)
            earmarkedAmountString = goal.currentEarmarkedAmount > 0 ? String(format: "%.0f", goal.currentEarmarkedAmount) : ""
            priority = goal.priority
            if let date = goal.targetDate {
                hasTargetDate = true
                targetDate = date
            } else {
                hasTargetDate = false
            }
            selectedLoanId = goal.targetLoanId
            note = goal.note
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

        if let existing = goalToEdit {
            existing.name = trimmedName
            existing.category = category
            existing.targetAmount = targetAmount
            existing.currentEarmarkedAmount = earmarked
            existing.priority = priority
            existing.targetDate = hasTargetDate ? targetDate : nil
            existing.targetLoanId = selectedLoanId
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
                targetLoanId: selectedLoanId,
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
