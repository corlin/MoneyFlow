import SwiftUI
import SwiftData

struct LiabilitiesTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Loan.createdAt, order: .reverse) private var loans: [Loan]
    @Query(sort: \CreditCard.createdAt, order: .reverse) private var creditCards: [CreditCard]
    @Query private var userSettingsList: [UserSettings]

    @State private var showingAddLoanSheet = false
    @State private var showingAddCreditCardSheet = false
    @State private var creditCardToEdit: CreditCard?
    @State private var undoAction: UndoAction?
    @State private var errorMessage: String?

    private var rateThreshold: Double { userSettingsList.first?.rateThreshold ?? 0.05 }
    private var totalLoanPrincipal: Double { loans.reduce(0) { $0 + $1.remainingPrincipal } }
    private var totalCardDebt: Double { creditCards.reduce(0) { $0 + $1.currentBalance } }
    private var totalLiabilities: Double { totalLoanPrincipal + totalCardDebt }
    private var totalMonthlyPayment: Double { loans.reduce(0) { $0 + $1.monthlyPayment } }

    var body: some View {
        NavigationStack {
            Group {
                if loans.isEmpty && creditCards.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "还没有负债",
                        subtitle: "记录贷款或信用卡，查看还款日和现金压力。",
                        buttonTitle: "添加贷款"
                    ) { showingAddLoanSheet = true }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("待偿还总额")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                CurrencyText(
                                    amount: totalLiabilities,
                                    font: .system(.largeTitle, design: .rounded),
                                    weight: .bold,
                                    color: .appLiability
                                )
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 24) { summaryMetrics }
                                    VStack(alignment: .leading, spacing: 8) { summaryMetrics }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.appCardBackground)

                        if !loans.isEmpty {
                            Section("贷款 · \(loans.count)") {
                                ForEach(loans) { loan in
                                    NavigationLink {
                                        LoanDetailView(loan: loan, rateThreshold: rateThreshold)
                                    } label: {
                                        LoanRow(loan: loan, rateThreshold: rateThreshold)
                                    }
                                }
                                .onDelete(perform: deleteLoans)
                            }
                        }

                        if !creditCards.isEmpty {
                            Section("信用卡 · \(creditCards.count)") {
                                ForEach(creditCards) { card in
                                    Button {
                                        creditCardToEdit = card
                                    } label: {
                                        CreditCardRow(card: card)
                                    }
                                    .buttonStyle(AppCardButtonStyle())
                                    .accessibilityHint("打开并编辑信用卡")
                                }
                                .onDelete(perform: deleteCards)
                            }
                        }
                    }
                }
            }
            .navigationTitle("负债")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("添加贷款", systemImage: "house") { showingAddLoanSheet = true }
                        Button("添加信用卡", systemImage: "creditcard") { showingAddCreditCardSheet = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.92, pressedOpacity: 0.75))
                    .accessibilityLabel("添加负债")
                }
            }
            .sheet(isPresented: $showingAddLoanSheet) { LoanForm() }
            .sheet(isPresented: $showingAddCreditCardSheet) { CreditCardForm() }
            .sheet(item: $creditCardToEdit) { CreditCardForm(cardToEdit: $0) }
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

    @ViewBuilder
    private var summaryMetrics: some View {
        LabeledContent("每月还贷", value: totalMonthlyPayment.formattedCurrencyCompact)
        LabeledContent("信用卡应还", value: totalCardDebt.formattedCurrencyCompact)
    }

    private func deleteLoans(at offsets: IndexSet) {
        let copies = offsets.map { loans[$0].detachedCopy() }
        for offset in offsets { modelContext.delete(loans[offset]) }
        saveDeletion(message: "已删除 \(copies.count) 笔贷款") {
            for copy in copies { modelContext.insert(copy) }
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        let copies = offsets.map { creditCards[$0].detachedCopy() }
        for offset in offsets { modelContext.delete(creditCards[offset]) }
        saveDeletion(message: "已删除 \(copies.count) 张信用卡") {
            for copy in copies { modelContext.insert(copy) }
        }
    }

    private func saveDeletion(message: String, undo: @escaping () -> Void) {
        do {
            try modelContext.save()
            let action = UndoAction(message: message) {
                undo()
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = "无法撤销删除：\(error.localizedDescription)"
                }
            }
            AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                undoAction = action
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                if undoAction?.id == action.id { dismissUndo() }
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func dismissUndo() {
        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
            undoAction = nil
        }
    }
}
