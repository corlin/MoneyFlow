import SwiftUI
import SwiftData

struct AssetsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \CashAccount.createdAt, order: .reverse) private var accounts: [CashAccount]

    @State private var showingAddSheet = false
    @State private var accountToEdit: CashAccount?
    @State private var undoAction: UndoAction?
    @State private var errorMessage: String?

    private var totalBalance: Double { accounts.reduce(0) { $0 + $1.balance } }

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
                            VStack(alignment: .leading, spacing: 8) {
                                Text("可用现金资产")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                CurrencyText(
                                    amount: totalBalance,
                                    font: .system(.largeTitle, design: .rounded),
                                    weight: .bold,
                                    color: .appAsset
                                )
                                Text("\(accounts.count) 个账户")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            .accessibilityElement(children: .combine)
                        }
                        .listRowBackground(Color.appCardBackground)

                        Section("账户") {
                            ForEach(accounts) { account in
                                CashAccountRow(account: account)
                                    .contentShape(Rectangle())
                                    .onTapGesture { accountToEdit = account }
                                    .accessibilityAddTraits(.isButton)
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
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 1)) {
            undoAction = action
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if undoAction?.id == action.id { dismissUndo() }
        }
    }

    private func dismissUndo() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1)) {
            undoAction = nil
        }
    }
}
