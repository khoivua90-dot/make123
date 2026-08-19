import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // Original accent — kept for compatibility with non-cyber views
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.64, blue: 0.42, alpha: 1.00)
                : UIColor(red: 0.85, green: 0.42, blue: 0.20, alpha: 1.00)
        }
    )
    static let pageBackground = Color(uiColor: .systemBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18

    // MARK: Cyberpunk palette
    static let cyberBase      = Color(red: 0.012, green: 0.031, blue: 0.090)
    static let techGlow       = Color(red: 0.180, green: 0.522, blue: 1.000)   // electric blue
    static let neonPurple     = Color(red: 0.580, green: 0.227, blue: 0.949)   // neon purple
    static let neonCyan       = Color(red: 0.102, green: 0.851, blue: 1.000)   // cyan
    static let techCardFill   = Color(red: 0.068, green: 0.098, blue: 0.180)

    static var techCardStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.52, blue: 1.00).opacity(0.55),
                Color(red: 0.58, green: 0.23, blue: 0.95).opacity(0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func resolvedBannerColor(_ hex: String?) -> Color {
        guard let hex, let color = Color(hex: hex) else {
            return Color(red: 0.12, green: 0.09, blue: 0.28)
        }
        return color
    }
}

// MARK: - Color hex initializer

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - TechBackground

struct TechBackground: View {
    var body: some View {
        ZStack {
            AppTheme.cyberBase

            // Blue atmospheric radial — top centre
            GeometryReader { geo in
                RadialGradient(
                    colors: [AppTheme.techGlow.opacity(0.13), Color.clear],
                    center: UnitPoint(x: 0.5, y: -0.05),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.75
                )
            }

            // Purple radial — bottom right
            GeometryReader { geo in
                RadialGradient(
                    colors: [AppTheme.neonPurple.opacity(0.10), Color.clear],
                    center: UnitPoint(x: 1.05, y: 1.05),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.65
                )
            }

            // Subtle blue radial — mid left
            GeometryReader { geo in
                RadialGradient(
                    colors: [AppTheme.techGlow.opacity(0.05), Color.clear],
                    center: UnitPoint(x: -0.1, y: 0.55),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.45
                )
            }

            // Grid
            GeometryReader { geo in
                Canvas { ctx, size in
                    let spacing: CGFloat = 38
                    let lineColor = GraphicsContext.Shading.color(
                        Color(red: 0.22, green: 0.42, blue: 0.82).opacity(0.07)
                    )
                    var x: CGFloat = 0
                    while x <= size.width {
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(p, with: lineColor, lineWidth: 0.5)
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: lineColor, lineWidth: 0.5)
                        y += spacing
                    }
                }
            }

            // Sparse star particles
            GeometryReader { geo in
                Canvas { ctx, size in
                    let dots: [(CGFloat, CGFloat, CGFloat, Double)] = [
                        (0.10, 0.14, 1.3, 0.50), (0.28, 0.07, 1.0, 0.40),
                        (0.68, 0.11, 1.4, 0.55), (0.91, 0.19, 0.9, 0.35),
                        (0.14, 0.43, 1.1, 0.45), (0.82, 0.33, 1.5, 0.50),
                        (0.23, 0.68, 0.9, 0.38), (0.61, 0.78, 1.1, 0.42),
                        (0.79, 0.62, 1.3, 0.48), (0.44, 0.24, 1.0, 0.40),
                        (0.53, 0.52, 0.8, 0.32), (0.04, 0.57, 1.4, 0.45),
                        (0.96, 0.48, 1.0, 0.38), (0.38, 0.88, 0.9, 0.35),
                        (0.72, 0.40, 1.2, 0.43), (0.50, 0.95, 1.0, 0.30),
                        (0.87, 0.82, 0.8, 0.30), (0.06, 0.30, 1.1, 0.40),
                    ]
                    for (xf, yf, r, a) in dots {
                        let pt = CGPoint(x: xf * size.width, y: yf * size.height)
                        let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                        ctx.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color(red: 0.45, green: 0.72, blue: 1.00).opacity(a))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - TechCard modifier

struct TechCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(AppTheme.techCardFill)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.techGlow.opacity(0.10), radius: 18, y: 5)
    }
}

extension View {
    func techCard(_ cornerRadius: CGFloat = 20) -> some View {
        modifier(TechCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Reusable components (original)

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png")
                    .flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
