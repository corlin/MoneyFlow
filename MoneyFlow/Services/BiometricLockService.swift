import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class BiometricLockService: ObservableObject {
    static let shared = BiometricLockService()

    @Published var isLocked: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authenticationError: String? = nil

    private var backgroundTimestamp: Date? = nil
    private var isColdBoot: Bool = true

    enum BiometryType {
        case faceID
        case touchID
        case opticID
        case none

        var title: String {
            switch self {
            case .faceID: return "面容 ID"
            case .touchID: return "触控 ID"
            case .opticID: return "视线 ID"
            case .none: return "设备密码"
            }
        }

        var systemImage: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.fill"
            }
        }
    }

    var availableBiometryType: BiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none: return .none
        @unknown default: return .none
        }
    }

    var isBiometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    private init() {}

    /// 处理冷启动初始化
    func handleColdBoot(isEnabled: Bool) {
        guard isColdBoot else { return }
        isColdBoot = false
        if isEnabled {
            isLocked = true
            authenticate()
        }
    }

    /// 处理 App 进入后台
    func handleAppDidEnterBackground(isEnabled: Bool, timeoutSeconds: Int = 0) {
        guard isEnabled else { return }
        // 如果正在进行 Face ID 验证，不计入离线后台
        guard !isAuthenticating else { return }
        backgroundTimestamp = Date()
        if timeoutSeconds == 0 {
            isLocked = true
        }
    }

    /// 处理 App 回到前台
    func handleAppWillEnterForeground(isEnabled: Bool, timeoutSeconds: Int) {
        guard isEnabled else {
            isLocked = false
            return
        }

        // 如果正在认证中，避免重复触发
        if isAuthenticating { return }

        if let backgroundTime = backgroundTimestamp {
            let elapsed = Date().timeIntervalSince(backgroundTime)
            if elapsed >= Double(timeoutSeconds) {
                isLocked = true
            }
        }

        backgroundTimestamp = nil

        if isLocked {
            authenticate()
        }
    }

    /// 请求生物识别或系统密码解锁
    func authenticate(reason: String = "请验证身份以解锁 MoneyFlow 财务看板") {
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "取消"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 如果设备未设置任何生物识别或密码，直接放行
            self.isLocked = false
            return
        }

        isAuthenticating = true
        authenticationError = nil

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, evalError in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isAuthenticating = false
                if success {
                    self.isLocked = false
                    self.authenticationError = nil
                    self.backgroundTimestamp = nil
                } else if let error = evalError as? LAError {
                    if error.code != .userCancel && error.code != .appCancel {
                        self.authenticationError = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 手动加锁
    func lockNow() {
        self.isLocked = true
        self.backgroundTimestamp = nil
    }
}
