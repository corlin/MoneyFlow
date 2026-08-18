import SwiftUI

struct UpcomingPaymentsCard: View {
    let summary: UpcomingPaymentSummary
    let onSelect: (UpcomingPaymentReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("未来30天还款")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .tracking(-0.2)
                    Text("共 \(summary.totalCount) 笔待还支出")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.totalAmount.formattedCurrencyCompact)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)
            }

            Divider()
                .opacity(0.6)

            if summary.visibleReminders.isEmpty {
                Label("未来30天暂无已记录还款", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(summary.visibleReminders) { reminder in
                        Button { onSelect(reminder) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: reminder.isLoan ? "house.fill" : "creditcard.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.appPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(dueText(reminder))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(reminder.amount.formattedCurrencyCompact)
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(AppCardButtonStyle())
                        .accessibilityHint("打开对应负债")

                        if reminder.id != summary.visibleReminders.last?.id {
                            Divider()
                                .opacity(0.4)
                        }
                    }
                }

                if summary.totalCount > summary.visibleReminders.count {
                    Text("另有 \(summary.totalCount - summary.visibleReminders.count) 笔已计入合计")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
        )
        .accessibilityIdentifier("upcoming-payments-card")
    }

    private func dueText(_ reminder: UpcomingPaymentReminder) -> String {
        if reminder.daysRemaining == 0 { return "今天到期 · \(reminder.dueDate.yearMonthDayString)" }
        return "\(reminder.daysRemaining)天后 · \(reminder.dueDate.yearMonthDayString)"
    }
}
