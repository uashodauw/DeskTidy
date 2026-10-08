import SwiftUI
import DeskTidyCore

struct ToastView: View {
    let feedback: CleanupFeedback

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 22, weight: .semibold))
            Text(feedback.message)
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .tidyGlass(in: Capsule())
        // 浮窗窗口本身是透明的，四周留一点空，玻璃的阴影和高光才不会被窗口边缘切掉
        .padding(12)
    }
}
