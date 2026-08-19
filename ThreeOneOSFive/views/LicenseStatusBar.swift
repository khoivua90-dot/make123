import SwiftUI

struct LicenseStatusBar: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 12) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.85, blue: 0.50).opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: "shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.88, blue: 0.52))
                    .shadow(color: Color(red: 0.10, green: 0.88, blue: 0.52).opacity(0.65), radius: 5)
            }

            // Key info
            VStack(alignment: .leading, spacing: 2) {
                Text(licenseGate.maskedKeyCode)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.10, green: 0.90, blue: 0.55))
                    .shadow(color: Color(red: 0.10, green: 0.88, blue: 0.52).opacity(0.60), radius: 4)
                    .lineLimit(1)

                Text(licenseGate.remainingTimeText(language: language))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.62, blue: 0.85))
                    .lineLimit(1)
            }

            Spacer()

            // Change key button
            Button {
                licenseGate.changeKey()
            } label: {
                Text("Đổi Key")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(0.3)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonPurple, AppTheme.techGlow],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: AppTheme.neonPurple.opacity(0.50), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(alignment: .top) {
            // Neon top border
            LinearGradient(
                colors: [AppTheme.neonPurple, AppTheme.techGlow, AppTheme.neonPurple],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
        .background {
            ZStack {
                Color(red: 0.020, green: 0.030, blue: 0.078).opacity(0.92)
                Color.clear.background(.ultraThinMaterial)
            }
        }
        .shadow(color: AppTheme.neonPurple.opacity(0.20), radius: 20, y: -4)
    }
}
