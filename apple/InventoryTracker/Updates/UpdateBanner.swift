#if os(macOS)
import SwiftUI

struct UpdateBanner: View {
    let release: AppRelease
    let onDismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update available")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Version \(release.version) is ready to download.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Button("Download") { openURL(release.pageURL) }
                .buttonStyle(.themedPrimary)
            RowIconButton(systemImage: "xmark", label: "Dismiss", action: onDismiss)
        }
        .padding(.vertical, 12)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.border))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}
#endif
