import SwiftUI
import SwiftData

struct LoanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var loan: Loan
    let rateThreshold: Double

    @State private var showingEditSheet = false
    @State private var showingFullSchedule = false
    @State private var showingEventSheet = false
    @State private var eventSheetDefaultType: AdjustmentType = .rateAdjustment
    @State private var eventToEdit: LoanAdjustmentEvent? = nil
    @State private var undoAction: UndoAction?
    @State private var errorMessage: String?
    @State private var paymentFeedback = false

    private var summary: RepaymentSummary { calculateSummary() }

    private var savingsBannerSubtext: String {
        var text = "历次变更已累计为您节省利息 \(summary.cumulativeInterestSaved.formattedCurrencyCompact)"
        if summary.monthsAheadSaved > 0 {
            text += " · 提前 \(summary.monthsAheadSaved) 个月结清"
        }
        return text
    }

    private var displayedSchedule: [RepaymentScheduleItem] {
        if showingFullSchedule { return summary.schedule }
        return Array(summary.schedule.dropFirst(min(loan.paidPeriods, summary.schedule.count)).prefix(12))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 1. 累计省息勋章 Banner
                if summary.cumulativeInterestSaved > 0 || summary.monthsAheadSaved > 0 {
                    savingsAchievementBanner
                }

                // 2. 核心概览卡片
                overviewCard

                // 3. 还款进度卡片
                progressCard

                // 4. 调息与提前还款时间轴卡片 (Adjustment Timeline)
                adjustmentTimelineCard

                // 5. 分段自适应还款计划表
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
        .sheet(isPresented: $showingEventSheet) {
            LoanAdjustmentEventSheet(
                loan: loan,
                eventToEdit: eventToEdit,
                defaultType: eventSheetDefaultType
            )
        }
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
        .sensoryFeedback(.success, trigger: paymentFeedback)
    }

    // MARK: - 累计省息成就勋章
    private var savingsAchievementBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("分段调息与提前还款效果显著")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text(savingsBannerSubtext)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
            }

            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    // MARK: - 核心概览卡片
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: loan.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(loan.latestAnnualRate <= rateThreshold ? Color.appHealthyDebt : Color.appWarningDebt)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.name)
                        .font(.title3.bold())
                    HStack {
                        HealthBadge(annualRate: loan.latestAnnualRate, threshold: rateThreshold)
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
        metric("当前月供", summary.currentMonthlyPayment.formattedCurrencyCompact, .appLiability)
        metric("当前利率", loan.latestAnnualRate.formattedRatePercentage, .primary)
    }

    // MARK: - 进度卡片
    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("还款进度").font(.headline)
                Spacer()
                Text("\(Int(loan.progress * 100))%")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(AppMotion.animation(for: .momentum, reduceMotion: reduceMotion), value: loan.progress)
            }
            ProgressView(value: loan.progress)
                .tint(loan.latestAnnualRate <= rateThreshold ? Color.appHealthyDebt : Color.appWarningDebt)
                .animation(AppMotion.animation(for: .momentum, reduceMotion: reduceMotion), value: loan.progress)
                .accessibilityLabel("还款进度")
                .accessibilityValue("已还 \(loan.paidPeriods) 期，共 \(loan.totalPeriods) 期")

            Text("已还 \(loan.paidPeriods) 期，剩余 \(loan.remainingPeriods) 期")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            if loan.remainingPeriods > 0 {
                Button(action: completePayment) {
                    Label("完成本期还款", systemImage: "checkmark.circle.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.96, pressedOpacity: 0.85))
                .tint(.appPrimary)
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 调息与还贷变更时间轴 (Adjustment Timeline Card)
    private var adjustmentTimelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("变更记录与时间轴")
                        .font(.headline)
                    Text("调息与提前还款事件流水")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        eventToEdit = nil
                        eventSheetDefaultType = .prepayment
                        showingEventSheet = true
                    } label: {
                        Label("提前还款", systemImage: "bolt.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button {
                        eventToEdit = nil
                        eventSheetDefaultType = .rateAdjustment
                        showingEventSheet = true
                    } label: {
                        Label("调整利率", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }

            Divider()

            if loan.adjustmentEvents.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("暂无调息或提前还款记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("点击上方按钮可随时补录历史调息或提前还款")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(loan.sortedAdjustmentEvents) { event in
                        timelineEventRow(event)
                    }
                }
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func timelineEventRow(_ event: LoanAdjustmentEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(event.type.themeColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.date.yearMonthDayString)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("第 \(event.periodIndex) 期")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        eventToEdit = event
                        showingEventSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        deleteEvent(event)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }

                if event.type == .rateAdjustment {
                    Text("利率调至 \((event.newAnnualRate ?? 0).formattedRatePercentage)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.blue)
                } else {
                    HStack(spacing: 4) {
                        Text("提前还本 \((event.prepaymentAmount ?? 0).formattedCurrencyCompact)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.orange)
                        Text("(\(event.prepaymentEffect.shortTitle))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !event.note.isEmpty {
                    Text(event.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func deleteEvent(_ event: LoanAdjustmentEvent) {
        withAnimation {
            if let idx = loan.adjustmentEvents.firstIndex(where: { $0.id == event.id }) {
                loan.adjustmentEvents.remove(at: idx)
            }
            modelContext.delete(event)
            loan.updatedAt = Date()
            try? modelContext.save()
        }
    }

    // MARK: - 分段还款计划表卡片
    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(showingFullSchedule ? "完整分段计划" : "接下来12期")
                        .font(.headline)
                    Text("按历次调息与还贷自适应重排")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(showingFullSchedule ? "收起" : "查看全部") {
                    AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                        showingFullSchedule.toggle()
                    }
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.94, pressedOpacity: 0.75))
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
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
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
            paymentDay: loan.paymentDayOfMonth,
            events: loan.adjustmentEvents
        )
    }

    private func completePayment() {
        guard loan.paidPeriods < summary.schedule.count else { return }
        let previousPaid = loan.paidPeriods
        let previousPrincipal = loan.remainingPrincipal
        let previousInterest = loan.totalInterestPaid

        AppMotion.perform(level: .momentum, reduceMotion: reduceMotion) {
            loan.paidPeriods += 1
            if let period = summary.schedule.first(where: { $0.period == loan.paidPeriods }) {
                loan.remainingPrincipal = period.remainingPrincipal
                loan.totalInterestPaid += period.interest
            }
            loan.updatedAt = Date()
        }

        do {
            try modelContext.save()
            paymentFeedback.toggle()
            let action = UndoAction(message: "已记录第 \(loan.paidPeriods) 期还款") {
                AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                    loan.paidPeriods = previousPaid
                    loan.remainingPrincipal = previousPrincipal
                    loan.totalInterestPaid = previousInterest
                    loan.updatedAt = Date()
                }
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    errorMessage = "无法撤销还款记录：\(error.localizedDescription)"
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

private struct ScheduleRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: RepaymentScheduleItem
    let isCurrent: Bool
    let isPaid: Bool

    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded.animation(AppMotion.animation(for: .spatial, reduceMotion: reduceMotion))) {
            VStack(spacing: 8) {
                LabeledContent("执行年化利率", value: item.annualRate.formattedRatePercentage)
                LabeledContent("偿还本金", value: item.principal.formattedCurrency)
                LabeledContent("支付利息", value: item.interest.formattedCurrency)
                if item.prepaymentAmount > 0 {
                    LabeledContent("当期额外提前还本", value: item.prepaymentAmount.formattedCurrency)
                }
                LabeledContent("还款后剩余本金", value: item.remainingPrincipal.formattedCurrency)
            }
            .font(.caption)
            .monospacedDigit()
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPaid ? "checkmark.circle.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                    .foregroundStyle(isPaid ? Color.appAsset : (isCurrent ? Color.appPrimary : Color.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("第 \(item.period) 期")
                            .fontWeight(isCurrent ? .bold : .regular)
                        if let badge = item.adjustmentBadge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
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
