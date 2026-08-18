import SwiftUI

/// MoneyFlow 全局物理动效设计规范（基于 Apple Fluid Interfaces 与 Emil Kowalski 动效哲学）
public enum AppMotion {
    
    public enum Level {
        /// 高频轻量交互（按压、微开关、数字跳动）：零超调、极速响应
        case interactive
        /// 空间层级与状态转场（折叠展开、卡片入场、页面切换）：临界阻尼、优雅沉稳
        case spatial
        /// 动量手势与成就达成（手势释放甩动、还款完成、成功反馈）：适度物理回弹
        case momentum
        
        public var spring: Animation {
            switch self {
            case .interactive:
                return .spring(response: 0.22, dampingFraction: 1.0)
            case .spatial:
                return .spring(response: 0.36, dampingFraction: 1.0)
            case .momentum:
                return .spring(response: 0.34, dampingFraction: 0.82)
            }
        }
        
        public var reducedAnimation: Animation {
            switch self {
            case .interactive:
                return .easeOut(duration: 0.1)
            case .spatial:
                return .easeOut(duration: 0.15)
            case .momentum:
                return .easeOut(duration: 0.18)
            }
        }
    }
    
    /// 获取适配无障碍减弱动态效果（Reduce Motion）的 Animation
    public static func animation(for level: Level, reduceMotion: Bool) -> Animation {
        reduceMotion ? level.reducedAnimation : level.spring
    }
    
    /// 执行适配 Reduce Motion 的全局动效包裹块
    public static func perform(level: Level = .spatial, reduceMotion: Bool, _ body: () -> Void) {
        withAnimation(animation(for: level, reduceMotion: reduceMotion), body)
    }
}

// MARK: - View Modifiers & Extensions

public extension View {
    /// 绑定特定数值变化的流体动画（自动适配 reduceMotion）
    func appMotion<V: Equatable>(_ level: AppMotion.Level = .spatial, value: V, reduceMotion: Bool = false) -> some View {
        self.animation(AppMotion.animation(for: level, reduceMotion: reduceMotion), value: value)
    }
}

// MARK: - Apple Fluid Button Styles

/// 适用于主操作按钮（Prominent / Bordered）的 Apple 物理按压手感
public struct AppSpringButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var scaleAmount: CGFloat
    public var pressedOpacity: CGFloat
    
    public init(scaleAmount: CGFloat = 0.97, pressedOpacity: CGFloat = 0.88) {
        self.scaleAmount = scaleAmount
        self.pressedOpacity = pressedOpacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(AppMotion.animation(for: .interactive, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

/// 适用于卡片、列表行及轻量跳转项的物理微动量按压手感
public struct AppCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var scaleAmount: CGFloat
    public var pressedOpacity: CGFloat
    
    public init(scaleAmount: CGFloat = 0.985, pressedOpacity: CGFloat = 0.92) {
        self.scaleAmount = scaleAmount
        self.pressedOpacity = pressedOpacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(AppMotion.animation(for: .interactive, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AppSpringButtonStyle {
    static var appSpring: AppSpringButtonStyle { AppSpringButtonStyle() }
}

public extension ButtonStyle where Self == AppCardButtonStyle {
    static var appCard: AppCardButtonStyle { AppCardButtonStyle() }
}
