import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
public final class BiometricLockService: ObservableObject {
    public static let shared = BiometricLockService()

    @Published public var isLocked: Bool = false
    @Published public var isAuthenticating: Bool = false
    @Published public var authenticationError: String? = nil

    private var backgroundTimestamp: Date? = nil

    public enum BiometryType {
        case faceID
        case touchID
        case opticID
        case none

        public var title: String {
            switch self {
            case .faceID: return "面容 ID"
            case .touchID: return "触控 ID"
            case .opticID: return "视线 ID"
            case .none: return "设备密码"
            }
        }

        public var systemImage: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.fill"
            }
        }
    }

    public var availableBiometryType: BiometryType {
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

    public var isBiometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    private init() {}

    /// 处理 App 进入后台
    public func handleAppDidEnterBackground(isEnabled: Bool) {
        guard isEnabled else { return }
        backgroundTimestamp = Date()
    }

    /// 处理 App 回到前台
    public func handleAppWillEnterForeground(isEnabled: Bool, timeoutSeconds: Int) {
        guard isEnabled else {
            isLocked = false
            return
        }

        if let backgroundTime = backgroundTimestamp {
            let elapsed = Date().timeIntervalSince(backgroundTime)
            if elapsed >= Double(timeoutSeconds) {
                isLocked = true
            }
        } else {
            isLocked = true
        }

        backgroundTimestamp = nil

        if isLocked {
            authenticate()
        }
    }

    /// 请求生物识别或系统密码解锁
    public func authenticate(reason: String = "请验证身份以解锁 MoneyFlow 财务看板") {
        guard !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "取消"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // 如果设备未设置任何密码，直接放行
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
                } else if let error = evalError as? LAError {
                    if error.code != .userCancel && error.code != .appCancel {
                        self.authenticationError = error.localizedDescription
                    }
                }
            }
        }
    }

    /// 手动加锁
    public func lockNow() {
        self.isLocked = true
    }
}
