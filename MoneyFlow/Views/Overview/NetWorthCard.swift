import SwiftUI

struct DebtProgressCard: View {
    let summary: DebtProgressSummary
    let netCashPosition: Double

    private var reductionRatio: Double {
        summary.currentDebt > 0 ? summary.projectedPrincipalReduction / summary.currentDebt : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("负债改善").font(.headline)
                Text("未来12个月预计本金变化")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("预计减少").font(.caption).foregroundStyle(.secondary)
                    Text(summary.projectedPrincipalReduction.formattedCurrencyCompact)
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                Text("\(Int((reductionRatio * 100).rounded()))%")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.appPrimary)
            }

            ProgressView(value: reductionRatio)
                .tint(Color.appPrimary)
                .accessibilityLabel("未来12个月预计本金减少比例")
                .accessibilityValue("百分之 \(Int((reductionRatio * 100).rounded()))")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { debtMetrics }
                VStack(alignment: .leading, spacing: 10) { debtMetrics }
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前净现金头寸")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("现金资产－已记录负债")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(netCashPosition.formattedCurrencyCompact)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(netCashPosition < 0 ? Color.appWarningDebt : .primary)
            }

            Text("信用卡欠款按首月还清、贷款按当前计划偿还；不计新增借款或消费。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("debt-progress-card")
    }

    @ViewBuilder
    private var debtMetrics: some View {
        metric("当前已记录负债", summary.currentDebt)
        metric("12个月后预计剩余", summary.projectedRemainingDebt)
    }

    private func metric(_ title: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(amount.formattedCurrencyCompact).font(.subheadline.bold()).monospacedDigit()
        }
    }
}

struct UpcomingPaymentsCard: View {
    let summary: UpcomingPaymentSummary
    let onSelect: (UpcomingPaymentReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("未来30天还款").font(.headline)
                    Text("共 \(summary.totalCount) 笔")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.totalAmount.formattedCurrencyCompact)
                    .font(.title3.bold())
                    .monospacedDigit()
            }

            if summary.visibleReminders.isEmpty {
                Label("未来30天暂无已记录还款", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(summary.visibleReminders) { reminder in
                    Button { onSelect(reminder) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: reminder.isLoan ? "house" : "creditcard")
                                .foregroundStyle(Color.appPrimary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(dueText(reminder))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(reminder.amount.formattedCurrencyCompact)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("打开对应负债")

                    if reminder.id != summary.visibleReminders.last?.id { Divider() }
                }

                if summary.totalCount > summary.visibleReminders.count {
                    Text("另有 \(summary.totalCount - summary.visibleReminders.count) 笔已计入合计")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("upcoming-payments-card")
    }

    private func dueText(_ reminder: UpcomingPaymentReminder) -> String {
        if reminder.daysRemaining == 0 { return "今天到期 · \(reminder.dueDate.yearMonthDayString)" }
        return "\(reminder.daysRemaining)天后 · \(reminder.dueDate.yearMonthDayString)"
    }
}
