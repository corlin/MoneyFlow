import SwiftUI
import SwiftData

public struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var onCompleteWithDemo: () -> Void
    var onCompleteManual: () -> Void

    @State private var currentPage = 0

    private struct OnboardingPageData: Identifiable {
        let id: Int
        let systemImage: String
        let gradientColors: [Color]
        let title: String
        let subtitle: String
        let highlightPill: String
    }

    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            id: 0,
            systemImage: "chart.line.uptrend.xyaxis",
            gradientColors: [Color.green, Color.blue],
            title: "看清未来 12 个月账户余钱",
            subtitle: "告别盲目繁琐记账。自动测算安全缓冲天数与月度还款压力，让每一分余钱心中有数。",
            highlightPill: "🛡️ 安全感筑底"
        ),
        OnboardingPageData(
            id: 1,
            systemImage: "sparkles",
            gradientColors: [Color.orange, Color.yellow],
            title: "一键推演省息与心愿储蓄",
            subtitle: "科学测算提前还款缩期省息，月度结余资金自动分配给你的购房、旅行与心愿目标。",
            highlightPill: "⚡ 智能推演"
        ),
        OnboardingPageData(
            id: 2,
            systemImage: "lock.shield.fill",
            gradientColors: [Color.blue, Color.indigo],
            title: "100% 本地离线，隐私绝对安全",
            subtitle: "财务数据完全保存在设备本地，支持 Face ID 安全防护。无第三方追踪，无云端泄露隐患。",
            highlightPill: "🔒 纯净离线"
        )
    ]

    public init(onCompleteWithDemo: @escaping () -> Void, onCompleteManual: @escaping () -> Void) {
        self.onCompleteWithDemo = onCompleteWithDemo
        self.onCompleteManual = onCompleteManual
    }

    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部跳过按钮
                HStack {
                    Spacer()
                    Button("跳过") {
                        onCompleteManual()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }

                // 核心翻页内容
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        pageCard(page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(AppMotion.animation(for: .spatial, reduceMotion: reduceMotion), value: currentPage)

                // 底部行动号召按钮组 (CTA)
                VStack(spacing: 12) {
                    Button(action: onCompleteWithDemo) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("载入示例数据，即刻体验")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.97, pressedOpacity: 0.85))

                    Button(action: onCompleteManual) {
                        Text("空白开始，录入我的第一笔账目")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func pageCard(_ page: OnboardingPageData) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // 渐变图标容器
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors.map { $0.opacity(0.20) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: page.gradientColors.first?.opacity(0.35) ?? .clear, radius: 16, y: 8)

                Image(systemName: page.systemImage)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(page.highlightPill)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(page.gradientColors.first ?? .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((page.gradientColors.first ?? .primary).opacity(0.12), in: Capsule())

                Text(page.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}
