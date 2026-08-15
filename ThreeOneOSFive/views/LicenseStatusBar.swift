import SwiftUI

/// Pinned footer on the Home screen showing the active key (masked) and remaining time, matching
/// the reference layout: status dot, masked key + countdown, an info button, and "Đổi Key".
struct LicenseStatusBar: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green.opacity(0.7), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("KEY \(licenseGate.maskedKeyCode)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text(remainingText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)
            }

            Spacer()

            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }

            Button {
                licenseGate.changeKey()
            } label: {
                Text(language.text("license.change_key"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [AppTheme.techGlow, .purple], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
        .alert(language.text("license.info_title"), isPresented: $showInfo) {
            Button(language.text("common.ok"), role: .cancel) {}
        } message: {
            Text(language.text("license.info_message", licenseGate.maskedKeyCode, remainingText))
        }
    }

    private var remainingText: String {
        guard let expiresAt = licenseGate.expiresAt else { return "" }
        let seconds = expiresAt.timeIntervalSinceNow
        guard seconds > 0 else { return language.text("license.expired") }
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        return language.text("license.remaining", Int64(days), Int64(hours))
    }
}
