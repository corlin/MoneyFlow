import SwiftUI
import SwiftData

struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var loan: Loan
    let rateThreshold: Double

    @State private var showingEditSheet = false
    @State private var showingFullSchedule = false
    @State private var cachedSummary: RepaymentSummary?
    @State private var undoAction: UndoAction?
    @State private var errorMessage: String?
    @State private var paymentFeedback = false

    private var summary: RepaymentSummary { cachedSummary ?? calculateSummary() }

    private var calculationKey: String {
        [
            String(loan.totalAmount), String(loan.annualRate), String(loan.totalPeriods),
            loan.repaymentMethod.rawValue, String(loan.startDate.timeIntervalSince1970),
            String(loan.paymentDayOfMonth)
        ].joined(separator: "|")
    }

    private var displayedSchedule: [RepaymentScheduleItem] {
        if showingFullSchedule { return summary.schedule }
        return Array(summary.schedule.dropFirst(min(loan.paidPeriods, summary.schedule.count)).prefix(12))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                overviewCard
                progressCard
                scheduleCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("贷款详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) { LoanForm(loanToEdit: loan) }
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
        .task(id: calculationKey) { cachedSummary = calculateSummary() }
        .sensoryFeedback(.success, trigger: paymentFeedback)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: loan.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(loan.annualRate <= rateThreshold ? Color.appHealthyDebt : Color.appWarningDebt)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name)
                        .font(.title3.bold())
                    HStack {
                        HealthBadge(annualRate: loan.annualRate, threshold: rateThreshold)
                        Text(loan.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 22) { overviewMetrics }
                VStack(alignment: .leading, spacing: 14) { overviewMetrics }
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var overviewMetrics: some View {
        metric("剩余本金", loan.remainingPrincipal.formattedCurrencyCompact, .primary)
        metric("当前月供", loan.monthlyPayment.formattedCurrencyCompact, .appLiability)
        metric("年化利率", String(format: "%.2f%%", loan.annualRate * 100), .primary)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("还款进度").font(.headline)
                Spacer()
                Text("\(Int(loan.progress * 100))%")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
            ProgressView(value: loan.progress)
                .tint(loan.annualRate <= rateThreshold ? Color.appHealthyDebt : Color.appWarningDebt)
                .accessibilityLabel("还款进度")
                .accessibilityValue("已还 \(loan.paidPeriods) 期，共 \(loan.totalPeriods) 期")

            Text("已还 \(loan.paidPeriods) 期，剩余 \(loan.remainingPeriods) 期")
                .font(.caption)
                .foregroundStyle(.secondary)

            if loan.remainingPeriods > 0 {
                Button(action: completePayment) {
                    Label("完成本期还款", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.appPrimary)
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(showingFullSchedule ? "完整还款计划" : "接下来12期")
                        .font(.headline)
                    Text("月供为主信息，本金与利息可展开查看")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(showingFullSchedule ? "收起" : "查看全部") {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 1)) {
                        showingFullSchedule.toggle()
                    }
                }
                .font(.subheadline)
            }

            Divider()

            LazyVStack(spacing: 0) {
                ForEach(displayedSchedule) { item in
                    ScheduleRowView(
                        item: item,
                        isCurrent: item.period == loan.paidPeriods + 1,
                        isPaid: item.period <= loan.paidPeriods
                    )
                    if item.id != displayedSchedule.last?.id { Divider() }
                }
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).fontWeight(.bold).monospacedDigit().foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func calculateSummary() -> RepaymentSummary {
        RepaymentCalculator.calculateSchedule(
            principal: loan.totalAmount,
            annualRate: loan.annualRate,
            totalPeriods: loan.totalPeriods,
            method: loan.repaymentMethod,
            startDate: loan.startDate,
            paymentDay: loan.paymentDayOfMonth
        )
    }

    private func completePayment() {
        guard loan.paidPeriods < loan.totalPeriods else { return }
        let previousPaid = loan.paidPeriods
        let previousPrincipal = loan.remainingPrincipal
        let previousInterest = loan.totalInterestPaid

        loan.paidPeriods += 1
        if let period = summary.schedule.first(where: { $0.period == loan.paidPeriods }) {
            loan.remainingPrincipal = period.remainingPrincipal
            loan.totalInterestPaid += period.interest
        }
        loan.updatedAt = Date()

        do {
            try modelContext.save()
            paymentFeedback.toggle()
            let action = UndoAction(message: "已记录第 \(loan.paidPeriods) 期还款") {
                loan.paidPeriods = previousPaid
                loan.remainingPrincipal = previousPrincipal
                loan.totalInterestPaid = previousInterest
                loan.updatedAt = Date()
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = "无法撤销还款记录：\(error.localizedDescription)"
                }
            }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 1)) {
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
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 1)) {
            undoAction = nil
        }
    }
}

private struct ScheduleRowView: View {
    let item: RepaymentScheduleItem
    let isCurrent: Bool
    let isPaid: Bool

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(spacing: 8) {
                LabeledContent("偿还本金", value: item.principal.formattedCurrency)
                LabeledContent("支付利息", value: item.interest.formattedCurrency)
                LabeledContent("还款后本金", value: item.remainingPrincipal.formattedCurrency)
            }
            .font(.caption)
            .monospacedDigit()
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPaid ? "checkmark.circle.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                    .foregroundStyle(isPaid ? Color.appAsset : (isCurrent ? Color.appPrimary : Color.secondary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \(item.period) 期")
                        .fontWeight(isCurrent ? .bold : .regular)
                    Text(item.paymentDate.yearMonthDayString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.monthlyPayment.formattedCurrencyCompact)
                    .fontWeight(isCurrent ? .bold : .semibold)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 10)
        .accessibilityLabel("第 \(item.period) 期，\(item.paymentDate.yearMonthDayString)，月供 \(item.monthlyPayment.formattedCurrency)")
    }
}
