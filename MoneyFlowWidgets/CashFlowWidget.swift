import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let snapshot = WidgetSnapshotData.loadFromSharedDefaults()
        let entry = SimpleEntry(date: Date(), snapshot: snapshot)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let snapshot = WidgetSnapshotData.loadFromSharedDefaults()
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate, snapshot: snapshot)

        // 30 分钟后定时刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate.addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotData
}

struct CashFlowWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "moneyflow://overview"))
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "moneyflow://overview"))
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "moneyflow://liabilities"))
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
                .widgetURL(URL(string: "moneyflow://overview"))
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - 桌面小号小组件 (System Small)
struct SmallWidgetView: View {
    let snapshot: WidgetSnapshotData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "yensign.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline)
                Text("自由流动资金")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formatCurrency(snapshot.availableCash))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }

            Spacer()

            Divider().opacity(0.6)

            HStack {
                if let nearest = snapshot.nearestReminder {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(nearest.title)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(nearest.daysRemaining)天后待还")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text(snapshot.riskStatusText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(hex: snapshot.riskStatusColorHex))
                }
                Spacer()
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

// MARK: - 桌面中号小组件 (System Medium)
struct MediumWidgetView: View {
    let snapshot: WidgetSnapshotData

    var body: some View {
        HStack(spacing: 16) {
            // 左侧：结余与水位
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("MoneyFlow 现金流")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("预测月底余钱")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(snapshot.predictedEndingCash))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("当月总待还")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatCurrency(snapshot.totalMustPayThisMonth))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    ProgressView(value: min(1.0, snapshot.dsrRatio))
                        .tint(Color(hex: snapshot.riskStatusColorHex))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // 右侧：近期待还清单
            VStack(alignment: .leading, spacing: 6) {
                Text("近期待还")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if snapshot.upcomingReminders.isEmpty {
                    Spacer()
                    Text("近 30 天无待还账目")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(snapshot.upcomingReminders.prefix(3)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(item.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.daysRemaining)天")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.daysRemaining <= 3 ? .red : .orange)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

// MARK: - 锁屏/StandBy 条形小组件 (Accessory Rectangular)
struct AccessoryRectangularView: View {
    let snapshot: WidgetSnapshotData

    var body: some View {
        if let nearest = snapshot.nearestReminder {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: nearest.icon)
                    Text(nearest.title)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(nearest.daysRemaining)天后")
                        .fontWeight(.bold)
                }
                .font(.caption2)

                Text(formatCurrency(nearest.amount))
                    .font(.system(.footnote, design: .rounded, weight: .bold))

                Text("本月底安全结余 \(formatCurrency(snapshot.predictedEndingCash))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("MoneyFlow 现金流")
                    .font(.caption2.bold())
                Text("暂无待还负债")
                    .font(.caption)
                Text("安全结余 \(formatCurrency(snapshot.availableCash))")
                    .font(.system(size: 9))
            }
        }
    }
}

// MARK: - 锁屏/StandBy 圆形小组件 (Accessory Circular)
struct AccessoryCircularView: View {
    let snapshot: WidgetSnapshotData

    var body: some View {
        Gauge(value: min(1.0, snapshot.dsrRatio)) {
            Image(systemName: "yensign")
                .font(.system(size: 10, weight: .bold))
        } currentValueLabel: {
            if let nearest = snapshot.nearestReminder {
                Text("\(nearest.daysRemaining)d")
                    .font(.system(size: 11, weight: .bold))
            } else {
                Text("OK")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Helpers

private func formatCurrency(_ value: Double) -> String {
    if abs(value) >= 10000 {
        return String(format: "¥%.1f万", value / 10000.0)
    } else {
        return String(format: "¥%.0f", value)
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1.0
        )
    }
}

struct CashFlowWidget: Widget {
    let kind: String = "CashFlowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CashFlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("现金流与待还看板")
        .description("即时查看当前自由可用流动资金、月底预测结余与近期还款倒计时。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}
