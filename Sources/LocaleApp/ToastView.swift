import SwiftUI

struct ToastView: View {
    let toast: ToastMessage
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(toast.type.color)

            Text(toast.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 16, y: 4)
        )
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
