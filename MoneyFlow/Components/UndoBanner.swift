import SwiftUI

struct UndoAction: Identifiable {
    let id = UUID()
    let message: String
    let perform: () -> Void
}

struct UndoBanner: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let action: UndoAction
    let dismiss: () -> Void

    @State private var dragOffsetY: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Color.appPrimary)
                .font(.title3)
                .accessibilityHidden(true)

            Text(action.message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            Button("撤销") {
                action.perform()
                dismiss()
            }
            .buttonStyle(AppSpringButtonStyle(scaleAmount: 0.95, pressedOpacity: 0.8))
            .fontWeight(.semibold)
            .foregroundStyle(Color.appPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .padding(.horizontal)
        .offset(y: dragOffsetY)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    let translation = value.translation.height
                    if translation > 0 {
                        // 下滑 1:1 跟手
                        dragOffsetY = translation
                    } else {
                        // 上推应用 Apple 级橡皮筋阻尼
                        dragOffsetY = -pow(-translation, 0.75) * 2.5
                    }
                }
                .onEnded { value in
                    if value.translation.height > 40 || value.predictedEndTranslation.height > 80 {
                        // 达到划走阈值，顺势滑出消退
                        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                            dragOffsetY = 120
                        }
                        dismiss()
                    } else {
                        // 未达阈值，弹性回弹归位
                        AppMotion.perform(level: .spatial, reduceMotion: reduceMotion) {
                            dragOffsetY = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
    }
}
