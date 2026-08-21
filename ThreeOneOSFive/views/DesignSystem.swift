import SwiftUI
import UIKit

enum AppTheme {
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

    // MARK: - Ocean sunset palette
    static let techBackgroundTop    = Color(red: 0.04, green: 0.12, blue: 0.28)
    static let techBackgroundBottom = Color(red: 0.02, green: 0.06, blue: 0.16)
    static let techGlow             = Color(red: 1.00, green: 0.60, blue: 0.15)   // sunset gold
    static let techCardFill         = Color(red: 0.20, green: 0.45, blue: 0.80).opacity(0.12)
    static let techCardStroke       = Color(red: 1.00, green: 0.65, blue: 0.20).opacity(0.35)

    static let rowPalette: [Color] = [
        Color(red: 1.00, green: 0.56, blue: 0.24),
        Color(red: 0.96, green: 0.28, blue: 0.42),
        Color(red: 0.30, green: 0.78, blue: 0.96),
        Color(red: 0.66, green: 0.46, blue: 0.98),
        Color(red: 0.36, green: 0.85, blue: 0.56),
    ]

    static func rowColor(_ index: Int) -> Color {
        rowPalette[index % rowPalette.count]
    }

    static func resolvedBannerColor(_ raw: String) -> Color {
        raw == "transparent" ? .clear : (Color(hex: raw) ?? accent)
    }
}

// MARK: - Ocean Background

struct TechBackground: View {
    var body: some View {
        GeometryReader { geo in
            Image("AppBg")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }
}

// MARK: - UIViewRepresentable wrapper

struct MatrixRainView: UIViewRepresentable {
    func makeUIView(context: Context) -> MatrixRainUIView { MatrixRainUIView() }
    func updateUIView(_ uiView: MatrixRainUIView, context: Context) {}
}

// MARK: - Core UIView that draws the rain

final class MatrixRainUIView: UIView {

    private var displayLink: CADisplayLink?

    private let colSpacing: CGFloat = 13
    private let rowSpacing: CGFloat = 14
    private let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    // Characters used in rain — mix of digits, letters, katakana for Matrix vibe
    private let charset: [Character] = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" +
        "!@#$%&*+-=~<>|\\/?[]{}ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ"
    )

    private struct Column {
        var x: CGFloat
        var headY: CGFloat
        var speed: CGFloat
        var trailLen: Int
        var chars: [Character]
    }

    private var columns: [Column] = []

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func layoutSubviews() {
        super.layoutSubviews()
        let needed = max(1, Int(bounds.width / colSpacing))
        if columns.count != needed { buildColumns(count: needed) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window != nil ? startRain() : stopRain()
    }

    deinit { stopRain() }

    // MARK: Column setup

    private func buildColumns(count: Int) {
        let h = max(bounds.height, 100)
        columns = (0..<count).map { i in
            let tl = Int.random(in: 8...22)
            return Column(
                x: CGFloat(i) * colSpacing + colSpacing * 0.5,
                headY: CGFloat.random(in: -h...h),
                speed: CGFloat.random(in: 2.5...10),
                trailLen: tl,
                chars: (0...tl).map { [self] _ in charset.randomElement()! }
            )
        }
    }

    // MARK: Display link

    private func startRain() {
        stopRain()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = .init(minimum: 18, maximum: 28, preferred: 24)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopRain() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let h = bounds.height
        let charsetCount = UInt32(charset.count)
        for i in 0..<columns.count {
            // Advance head
            columns[i].headY += columns[i].speed

            // Random character mutation (gives the "flickering" feel)
            if arc4random_uniform(3) == 0 {
                let j = Int(arc4random_uniform(UInt32(columns[i].chars.count)))
                columns[i].chars[j] = charset[Int(arc4random_uniform(charsetCount))]
            }

            // Reset column when tail exits bottom
            let tailY = columns[i].headY - CGFloat(columns[i].trailLen) * rowSpacing
            if tailY > h {
                let tl = Int.random(in: 8...24)
                columns[i].headY = -CGFloat.random(in: 0...(h * 0.7))
                columns[i].speed = CGFloat.random(in: 2.5...10)
                columns[i].trailLen = tl
                columns[i].chars = (0...tl).map { _ in charset[Int(arc4random_uniform(charsetCount))] }
            }
        }
        setNeedsDisplay()
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        for col in columns {
            for j in 0...col.trailLen {
                let cy = col.headY - CGFloat(j) * rowSpacing
                guard cy > -rowSpacing && cy < rect.height else { continue }

                let fraction = 1.0 - CGFloat(j) / CGFloat(col.trailLen)
                let alpha = fraction * fraction

                let color: UIColor
                switch j {
                case 0:
                    // Head: near-white with green tint
                    color = UIColor(red: 0.88, green: 1.00, blue: 0.90, alpha: 1.0)
                case 1:
                    // Neck: full bright green
                    color = UIColor(red: 0.12, green: 1.00, blue: 0.38, alpha: 1.0)
                default:
                    // Trail: fading green
                    let g = max(0.08, 0.75 * alpha)
                    color = UIColor(red: 0.0, green: g, blue: 0.04, alpha: alpha * 0.90)
                }

                let ci = j % col.chars.count
                let str = String(col.chars[ci]) as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let sz = str.size(withAttributes: attrs)
                str.draw(
                    at: CGPoint(x: col.x - sz.width * 0.5, y: cy),
                    withAttributes: attrs
                )
            }
        }
    }
}

// MARK: - Tech card style

private struct TechCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
            )
            .shadow(color: AppTheme.techGlow.opacity(0.14), radius: 16, y: 0)
    }
}

extension View {
    func techCard() -> some View {
        modifier(TechCardStyle())
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

private struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.rowColor(4))
                            .padding(.top, 1)
                        Text(toast.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.techGlow.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.techGlow.opacity(0.25), radius: 18, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        if self.toast?.id == toast.id {
                            self.toast = nil
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: toast)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}

// MARK: - App Logo

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
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
