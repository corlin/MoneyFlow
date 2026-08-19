import SwiftUI
import SwiftData

struct CashFlowCalendarCardView: View {
    @Environment(\.modelContext) private var modelContext

    let accounts: [CashAccount]
    let loans: [Loan]
    let creditCards: [CreditCard]
    let settings: UserSettings
    let reconciliations: [PaymentReconciliationRecord]
    let customEvents: [CustomCashFlowEvent]

    @State private var currentSelectedDate = Date()
    @State private var isExpandedToMonth = false
    @State private var selectedDaySummary: DailyCashFlowSummary?
    @State private var refreshTrigger = UUID()

    private var currentTotalCash: Double {
        accounts.reduce(0.0) { $0 + $1.balance }
    }

    private var projection: MonthlyCalendarProjection {
        _ = refreshTrigger
        return CashFlowCalendarEngine.projectMonth(
            for: currentSelectedDate,
            currentTotalCash: currentTotalCash,
            settings: settings,
            loans: loans,
            creditCards: creditCards,
            customEvents: customEvents,
            reconciliations: reconciliations
        )
    }

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        VStack(spacing: 14) {
            // 头部与月份导航
            headerView

            // 核心统计指标条
            metricsDashboardBar

            // 星期表头
            weekdayHeaderView

            // 日期网格 (周视图 / 月视图)
            if isExpandedToMonth {
                monthGridView
            } else {
                weekStripView
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .sheet(item: $selectedDaySummary) { summary in
            DailyCashFlowDetailSheet(
                summary: summary,
                yearMonthKey: projection.yearMonth,
                accounts: accounts,
                onRefresh: {
                    refreshTrigger = UUID()
                }
            )
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appPrimary)
                Text("现金流全景日历")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }

            Spacer()

            // 月份切换
            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Text(projection.monthTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 展开/折叠按钮
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpandedToMonth.toggle()
                }
            } label: {
                Image(systemName: isExpandedToMonth ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appPrimary)
            }
        }
    }

    private var metricsDashboardBar: some View {
        HStack(spacing: 10) {
            // 当月净流向
            let net = projection.totalMonthInflow - projection.totalMonthOutflow
            metricPill(
                title: "月预计净结余",
                value: "\(net >= 0 ? "+" : "")¥\(Int(net))",
                color: net >= 0 ? .green : .red
            )

            // 最低资金水位
            metricPill(
                title: "最低资金水位",
                value: "¥\(Int(projection.lowestBalance))",
                color: projection.deficitDaysCount > 0 ? .red : (projection.shortfallDaysCount > 0 ? .orange : .primary)
            )

            // 待对账笔数
            metricPill(
                title: "待还对账",
                value: "\(projection.totalPendingCount) 笔",
                color: projection.totalPendingCount > 0 ? .orange : .green
            )
        }
    }

    private func metricPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var weekdayHeaderView: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // 周视图 (当前日期所在周或当月首周 7 天)
    private var weekStripView: some View {
        let summaries = projection.dailySummaries
        let today = Date()
        let todayDay = calendar.component(.day, from: today)
        let startIndex: Int = {
            if let index = summaries.firstIndex(where: { $0.dayNumber == todayDay }) {
                return max(0, min(index - 3, max(0, summaries.count - 7)))
            }
            return 0
        }()
        let weekSummaries = Array(summaries.dropFirst(startIndex).prefix(7))

        return HStack(spacing: 6) {
            ForEach(weekSummaries) { summary in
                dayCell(summary: summary)
            }
        }
    }

    // 月视图 (完整 7xN 日历网格)
    private var monthGridView: some View {
        let firstDayDate = projection.dailySummaries.first?.date ?? Date()
        let firstWeekday = calendar.component(.weekday, from: firstDayDate) - 1 // 0 (Sun) ~ 6 (Sat)
        let leadingEmptyCount = firstWeekday

        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            // 前置空白补齐
            ForEach(0..<leadingEmptyCount, id: \.self) { _ in
                Color.clear
                    .frame(height: 48)
            }

            ForEach(projection.dailySummaries) { summary in
                dayCell(summary: summary)
            }
        }
    }

    private func dayCell(summary: DailyCashFlowSummary) -> some View {
        Button {
            selectedDaySummary = summary
        } label: {
            VStack(spacing: 3) {
                // 日期数字
                Text("\(summary.dayNumber)")
                    .font(.system(.subheadline, design: .rounded, weight: summary.isToday ? .bold : .medium))
                    .foregroundColor(summary.isToday ? .white : .primary)
                    .frame(width: 26, height: 26)
                    .background(summary.isToday ? Color.appPrimary : Color.clear)
                    .clipShape(Circle())

                // 状态指示点与微胶囊
                HStack(spacing: 2) {
                    // 1. 进账状态
                    if summary.totalInflow > 0 {
                        if summary.allInflowsReconciled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5, height: 5)
                        }
                    }

                    // 2. 出账状态
                    if summary.totalOutflow > 0 {
                        if summary.allOutflowsReconciled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(summary.totalInflow > 0 ? Color.appPrimary : .green)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                        }
                    }

                    // 3. 风险状态
                    if summary.isDeficitRisk {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 5, height: 5)
                    } else if summary.isShortfallRisk && summary.totalOutflow > 0 {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(summary.isDeficitRisk ? Color.red.opacity(0.12) : (summary.isShortfallRisk && summary.totalOutflow > 0 ? Color.orange.opacity(0.1) : Color(.systemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(summary.isToday ? Color.appPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func changeMonth(by value: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let newDate = calendar.date(byAdding: .month, value: value, to: currentSelectedDate) {
                currentSelectedDate = newDate
            }
        }
    }
}
