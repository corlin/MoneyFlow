import SwiftUI
import SwiftData

struct ReconciliationConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let sourceID: UUID
    let sourceName: String
    let sourceType: String
    let isIncome: Bool
    let yearMonth: String
    let scheduledDate: Date
    let scheduledAmount: Double
    let accounts: [CashAccount]

    @State private var actualAmountString: String = ""
    @State private var isSyncWithAccount: Bool = true
    @State private var selectedAccountID: UUID?
    @State private var notes: String = ""

    private var parsedAmount: Double {
        Double(actualAmountString) ?? scheduledAmount
    }

    private var selectedAccount: CashAccount? {
        accounts.first { $0.id == selectedAccountID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(isIncome ? "收入项目" : "负债名称")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(sourceName)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }

                    HStack {
                        Text("归属月份")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(yearMonth)
                            .font(.system(.body, design: .monospaced))
                    }

                    HStack {
                        Text(isIncome ? "预计收入" : "计划应还")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("¥\(scheduledAmount, specifier: "%.2f")")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Text(isIncome ? "实收金额" : "实扣金额")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("金额", text: $actualAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(isIncome ? .green : Color.appPrimary)
                    }
                } header: {
                    Text("对账信息")
                }

                Section {
                    Toggle(isIncome ? "同步存入现金账户" : "同步扣减现金账户余额", isOn: $isSyncWithAccount)
                        .tint(isIncome ? .green : Color.appPrimary)

                    if isSyncWithAccount && !accounts.isEmpty {
                        Picker(isIncome ? "选择存入账户" : "选择扣款账户", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                HStack {
                                    Text(account.name)
                                    Spacer()
                                    Text("当前 ¥\(account.balance, specifier: "%.2f")")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(account.id as UUID?)
                            }
                        }

                        if let acc = selectedAccount {
                            HStack {
                                Text(isIncome ? "存入后预计余额" : "扣款后预计余额")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let newBal = isIncome ? (acc.balance + parsedAmount) : (acc.balance - parsedAmount)
                                Text("¥\(newBal, specifier: "%.2f")")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(newBal < 0 ? .red : (isIncome ? .green : .secondary))
                            }
                        }
                    }
                } header: {
                    Text("资金账户联动")
                } footer: {
                    Text(isSyncWithAccount
                         ? (isIncome ? "确认到账后，系统将自动向所选账户存入实发金额，更新总可用流动资金。" : "确认对账后，系统将自动从所选账户扣除实还金额，保持资产与流水账目实时一致。")
                         : (isIncome ? "仅记录收入到账状态，不改变现金账户余额。" : "仅记录还款结清状态，不改变现金账户余额。")
                    )
                    .font(.caption2)
                }

                Section {
                    TextField("添加对账备注（可选）", text: $notes)
                } header: {
                    Text("备注")
                }
            }
            .navigationTitle(isIncome ? "收入到账确认" : "还款对账确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isIncome ? "确认已到账" : "确认结清") {
                        performReconciliation()
                    }
                    .fontWeight(.semibold)
                    .tint(isIncome ? .green : Color.appPrimary)
                }
            }
            .onAppear {
                actualAmountString = String(format: "%.2f", scheduledAmount)
                selectedAccountID = accounts.first?.id
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func performReconciliation() {
        let finalAmount = parsedAmount

        // 1. 同步现金账户余额
        if isSyncWithAccount, let account = selectedAccount {
            if isIncome {
                account.balance += finalAmount
            } else {
                account.balance = max(0, account.balance - finalAmount)
            }
            account.updatedAt = Date()
        }

        // 2. 插入或更新对账记录
        let record = PaymentReconciliationRecord(
            sourceID: sourceID,
            sourceName: sourceName,
            sourceType: sourceType,
            yearMonth: yearMonth,
            scheduledDate: scheduledDate,
            reconciledDate: Date(),
            scheduledAmount: scheduledAmount,
            actualAmount: finalAmount,
            isIncome: isIncome,
            isReconciled: true,
            deductedAccountID: isSyncWithAccount ? selectedAccountID : nil,
            notes: notes
        )
        modelContext.insert(record)
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
