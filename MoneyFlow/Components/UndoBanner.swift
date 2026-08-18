import SwiftUI

struct UndoAction: Identifiable {
    let id = UUID()
    let message: String
    let perform: () -> Void
}

struct UndoBanner: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let action: UndoAction
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(action.message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            Button("撤销") {
                action.perform()
                dismiss()
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(uiColor: .secondarySystemBackground))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
