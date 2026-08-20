import SwiftUI

struct SafeToSpendHeroCard: View {
    let result: SafeToSpendResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部标题与状态徽章
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.appPrimary)
                    Text("今日随心花")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(result.status.title)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusBackgroundColor)
                    .foregroundColor(statusForegroundColor)
                    .clipShape(Capsule())
            }

            // 大字号核心指标
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("¥")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(statusForegroundColor)
                    Text("\(Int(result.dailySafeToSpend))")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text("/ 天")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(result.statusDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()
                .opacity(0.6)

            // 本月闲钱池与剩余天数
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本月自由零花池")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("¥\(Int(result.monthlySafeToSpend))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("本月还剩")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(result.daysRemainingInMonth) 天")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }

            // 智能备款诊断横幅 (Buffer Advisor)
            if let alert = result.bufferAlert {
                HStack(spacing: 8) {
                    Image(systemName: alert.isSufficient ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundColor(alert.isSufficient ? .green : .orange)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(alert.title)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundColor(alert.isSufficient ? .green : .orange)
                        Text(alert.message)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(10)
                .background(alert.isSufficient ? Color.green.opacity(0.08) : Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(UIColor.separator).opacity(0.12), lineWidth: 0.5)
        )
    }

    private var statusForegroundColor: Color {
        switch result.status {
        case .relaxed: return .green
        case .moderate: return .orange
        case .tight: return .red
        case .deficit: return .purple
        }
    }

    private var statusBackgroundColor: Color {
        statusForegroundColor.opacity(0.12)
    }
}
