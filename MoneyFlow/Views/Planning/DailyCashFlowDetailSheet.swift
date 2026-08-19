import SwiftUI
import SwiftData

struct DailyCashFlowDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let summary: DailyCashFlowSummary
    let yearMonthKey: String
    let accounts: [CashAccount]
    let onRefresh: () -> Void

    @State private var itemToReconcile: CalendarFlowItem?
    @State private var showingAddEventSheet = false

    private var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: summary.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 资金水位全景卡片
                    balanceProgressionCard

                    // 缺口预警横幅
                    if summary.isDeficitRisk {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("资金透支预警")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                                Text("当日扣款后账户预计穿底透支 (¥\(summary.endingBalance, specifier: "%.2f"))，请提前归集可用资金。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if summary.isShortfallRisk {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("流动性偏低预警")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                Text("当日出账后账户余额低于 1 个月刚性安全防线，建议控制非必要大额开销。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // 进账明细
                    if !summary.inflows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🟢 预计进账 (\(summary.inflows.count) 笔)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ForEach(summary.inflows) { item in
                                flowItemRow(item: item)
                            }
                        }
                    }

                    // 出账与对账明细
                    if !summary.outflows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("🔴 预计出账 (\(summary.outflows.count) 笔)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if summary.pendingReconciliationCount > 0 {
                                    Text("\(summary.pendingReconciliationCount) 笔待对账")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("已全部结清 ✅")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }

                            ForEach(summary.outflows) { item in
                                flowItemRow(item: item)
                            }
                        }
                    }

                    if !summary.hasEvents {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("当日无收支或还款安排")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                    }

                    // 快速添加收支按钮
                    Button {
                        showingAddEventSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加当日自定义收支")
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(formattedDateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Color.appPrimary)
                }
            }
            .sheet(item: $itemToReconcile) { item in
                if let sourceID = item.sourceID {
                    ReconciliationConfirmSheet(
                        sourceID: sourceID,
                        sourceName: item.title,
                        sourceType: item.type == .loanPayment ? "loan" : "creditCard",
                        yearMonth: yearMonthKey,
                        scheduledDate: summary.date,
                        scheduledAmount: item.amount,
                        accounts: accounts
                    )
                    .onDisappear {
                        onRefresh()
                    }
                }
            }
            .sheet(isPresented: $showingAddEventSheet) {
                CustomCashFlowEventFormSheet(initialDate: summary.date)
                    .onDisappear {
                        onRefresh()
                    }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var balanceProgressionCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("日初预计水位")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("¥\(summary.startingBalance, specifier: "%.2f")")
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("日终推演水位")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("¥\(summary.endingBalance, specifier: "%.2f")")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(summary.endingBalance < 0 ? .red : (summary.isShortfallRisk ? .orange : .primary))
                }
            }

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.left")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("进账 +¥\(summary.totalInflow, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("出账 -¥\(summary.totalOutflow, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func flowItemRow(item: CalendarFlowItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(item.isIncome ? .green : (item.isReconciled ? .secondary : Color.appPrimary))
                .frame(width: 32, height: 32)
                .background((item.isIncome ? Color.green : Color.appPrimary).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if let badge = item.badgeText {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.isReconciled ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            .foregroundColor(item.isReconciled ? .green : .orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.isIncome ? "+" : "-")¥\(item.amount, specifier: "%.2f")")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(item.isIncome ? .green : .primary)

                if (item.type == .loanPayment || item.type == .creditCardPayment) {
                    if item.isReconciled {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("已对账")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                    } else {
                        Button {
                            itemToReconcile = item
                        } label: {
                            Text("对账结清")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appPrimary)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
