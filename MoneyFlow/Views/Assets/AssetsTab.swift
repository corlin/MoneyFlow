import SwiftUI
import SwiftData

struct AssetsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CashAccount.createdAt, order: .reverse) private var accounts: [CashAccount]
    @Query private var goals: [FinancialGoal]

    @State private var showingAddSheet = false
    @State private var accountToEdit: CashAccount?
    @State private var undoAction: UndoAction?
    @State private var errorMessage: String?

    private var totalBalance: Double { accounts.reduce(0) { $0 + $1.balance } }
    private var totalEarmarked: Double { goals.reduce(0) { $0 + $1.currentEarmarkedAmount } }
    private var freeCash: Double { max(0.0, totalBalance - totalEarmarked) }
    private var freeCashRatio: Double { totalBalance > 0 ? (freeCash / totalBalance) : 1.0 }

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    EmptyStateView(
                        icon: "banknote",
                        title: "还没有资产",
                        subtitle: "先记录一个可用于还款的现金账户。",
                        buttonTitle: "添加资产"
                    ) { showingAddSheet = true }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("现金流动资产")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                CurrencyText(
                                    amount: totalBalance,
                                    font: .system(.largeTitle, design: .rounded),
                                    weight: .bold,
                                    color: .appAsset
                                )

                                if totalEarmarked > 0 && totalBalance > 0 {
                                    // 双色流动性分配比例条 (Dual-tone Allocation Capsule Bar)
                                    GeometryReader { geo in
                                        let totalW = geo.size.width
                                        let freeW = totalW * CGFloat(freeCashRatio)
                                        let earmarkedW = totalW - freeW

                                        HStack(spacing: 2) {
                                            if freeW > 0 {
                                                Capsule()
                                                    .fill(Color.blue)
                                                    .frame(width: max(4, freeW), height: 6)
                                            }
                                            if earmarkedW > 0 {
                                                Capsule()
                                                    .fill(Color.purple)
                                                    .frame(width: max(4, earmarkedW), height: 6)
                                            }
                                        }
                                    }
                                    .frame(height: 6)
                                    .animation(AppMotion.animation(for: .momentum, reduceMotion: reduceMotion), value: freeCashRatio)

                                    HStack {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 7, height: 7)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("未锁定自由现金")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(freeCash.formattedCurrencyCompact)
                                                    .font(.subheadline.weight(.semibold))
                                                    .monospacedDigit()
                                                    .contentTransition(.numericText())
                                                    .foregroundStyle(.blue)
                                            }
                                        }

                                        Spacer()

                                        HStack(spacing: 6) {
                                            VStack(alignment: .trailing, spacing: 1) {
                                                Text("已锁定规划目标")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(totalEarmarked.formattedCurrencyCompact)
                                                    .font(.subheadline.weight(.semibold))
                                                    .monospacedDigit()
                                                    .contentTransition(.numericText())
                                                    .foregroundStyle(.purple)
                                            }
                                            Circle()
                                                .fill(Color.purple)
                                                .frame(width: 7, height: 7)
                                        }
                                    }
                                    .padding(.top, 2)
                                }

                                Text("\(accounts.count) 个账户 · \(goals.count) 个规划目标")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                        }
                        .listRowBackground(Color.appCardBackground)

                        Section("账户列表") {
                            ForEach(accounts) { account in
                                Button {
                                    accountToEdit = account
                                } label: {
                                    CashAccountRow(account: account)
                                }
                                .buttonStyle(.appCard)
                                .accessibilityHint("打开并编辑账户")
                            }
                            .onDelete(perform: deleteAccounts)
                        }
                    }
                }
            }
            .navigationTitle("资产")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: { Image(systemName: "plus") }
                        .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.92, pressedOpacity: 0.75))
                        .accessibilityLabel("添加资产")
                }
            }
            .sheet(isPresented: $showingAddSheet) { CashAccountForm() }
            .sheet(item: $accountToEdit) { CashAccountForm(accountToEdit: $0) }
            .safeAreaInset(edge: .bottom) {
                if let undoAction {
                    UndoBanner(action: undoAction) { dismissUndo() }
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) { Button("好", role: .cancel) {} } message: { Text(errorMessage ?? "未知错误") }
            .sensoryFeedback(.warning, trigger: undoAction?.id)
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        let copies = offsets.map { accounts[$0].detachedCopy() }
        for offset in offsets { modelContext.delete(accounts[offset]) }
        do {
            try modelContext.save()
            presentUndo(message: "已删除 \(copies.count) 个资产账户") {
                for copy in copies { modelContext.insert(copy) }
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = "无法恢复资产账户：\(error.localizedDescription)"
                }
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func presentUndo(message: String, perform: @escaping () -> Void) {
        let action = UndoAction(message: message, perform: perform)
        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
            undoAction = action
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if undoAction?.id == action.id { dismissUndo() }
        }
    }

    private func dismissUndo() {
        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
            undoAction = nil
        }
    }
}

