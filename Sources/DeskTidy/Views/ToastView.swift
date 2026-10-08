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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
