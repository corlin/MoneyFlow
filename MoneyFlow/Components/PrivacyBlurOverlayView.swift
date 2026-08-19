import SwiftUI

public struct PrivacyBlurOverlayView: View {
    @ObservedObject var lockService = BiometricLockService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        ZStack {
            // 背景毛玻璃遮罩
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 安全盾牌图标
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 88, height: 88)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 8) {
                    Text("MoneyFlow 财务安全锁")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Text("您的资产与收支数据已处于加密保护状态")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = lockService.authenticationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    lockService.authenticate()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: lockService.availableBiometryType.systemImage)
                            .font(.headline)
                        Text("点击验证\(lockService.availableBiometryType.title)解锁")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.85))
                .padding(.top, 8)
            }
            .padding()
        }
        .transition(.opacity)
        .animation(AppMotion.animation(for: .spatial, reduceMotion: reduceMotion), value: lockService.isLocked)
    }
}
