import SwiftUI
import SwiftData

struct ReconciliationConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let sourceID: UUID
    let sourceName: String
    let sourceType: String
    let yearMonth: String
    let scheduledDate: Date
    let scheduledAmount: Double
    let accounts: [CashAccount]

    @State private var actualAmountString: String = ""
    @State private var isDeductFromAccount: Bool = true
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
                        Text("负债名称")
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
                        Text("计划应还")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("¥\(scheduledAmount, specifier: "%.2f")")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    HStack {
                        Text("实扣金额")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("金额", text: $actualAmountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.appPrimary)
                    }
                } header: {
                    Text("对账信息")
                }

                Section {
                    Toggle("同步扣减现金账户余额", isOn: $isDeductFromAccount)
                        .tint(Color.appPrimary)

                    if isDeductFromAccount && !accounts.isEmpty {
                        Picker("选择扣款账户", selection: $selectedAccountID) {
                            ForEach(accounts) { account in
                                HStack {
                                    Text(account.name)
                                    Spacer()
                                    Text("可用 ¥\(account.balance, specifier: "%.2f")")
                                        .foregroundStyle(.secondary)
                                }
                                .tag(account.id as UUID?)
                            }
                        }

                        if let acc = selectedAccount {
                            HStack {
                                Text("扣款后预计余额")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let remaining = acc.balance - parsedAmount
                                Text("¥\(remaining, specifier: "%.2f")")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(remaining < 0 ? .red : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("资金账户联动")
                } footer: {
                    Text(isDeductFromAccount ? "确认对账后，系统将自动从所选账户扣除实还金额，保持资产与流水账目实时一致。" : "仅记录还款结清状态，不改变现金账户余额。")
                        .font(.caption2)
                }

                Section {
                    TextField("添加对账备注（可选）", text: $notes)
                } header: {
                    Text("备注")
                }
            }
            .navigationTitle("还款对账确认")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认结清") {
                        performReconciliation()
                    }
                    .fontWeight(.semibold)
                    .tint(Color.appPrimary)
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

        // 1. 同步扣款
        if isDeductFromAccount, let account = selectedAccount {
            account.balance = max(0, account.balance - finalAmount)
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
            isReconciled: true,
            deductedAccountID: isDeductFromAccount ? selectedAccountID : nil,
            notes: notes
        )
        modelContext.insert(record)
        try? modelContext.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
