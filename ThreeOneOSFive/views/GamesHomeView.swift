import SwiftUI
import UIKit

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showLanguagePicker = false
    @AppStorage("language.hasPicked") private var hasPickedLanguage = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            homeStack

            if showLanguagePicker {
                languagePickerOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showLanguagePicker)
        .task {
            if !hasPickedLanguage { showLanguagePicker = true }
        }
    }

    private var homeStack: some View {
        NavigationStack {
            ZStack {
                TechBackground()

                // Ambient glow at top
                VStack {
                    RadialGradient(
                        colors: [AppTheme.techGlow.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                    .frame(height: 320)
                    .blur(radius: 50)
                    Spacer()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 0) {
                        cyberHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 16)

                        deviceInfoCard
                            .padding(.horizontal, 16)

                        gameSectionHeader
                            .padding(.top, 22)
                            .padding(.bottom, 4)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(games) { game in
                                NavigationLink {
                                    GamePatchesView(game: game, store: store)
                                } label: {
                                    GameCardView(game: game)
                                }
                                .buttonStyle(GameCard3DPressStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                        if games.isEmpty && !isLoadingGames {
                            Text("App đang tiến hành nâng cấp mới")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 24)
                        }

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await loadGames()
            }
            .task { await loadGames() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LicenseStatusBar()
                    .padding(.bottom, 8)
            }
            .toast($licenseGate.activationToast)
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.dark)
    }

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
    }

    // MARK: - Custom header

    private var cyberHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ALAPHAREGEDIT.COM")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                     Color(red: 0.48, green: 0.37, blue: 1.00)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Trợ thủ game · An toàn · Ổn định")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(red: 0.012, green: 0.031, blue: 0.090).opacity(0.80))
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.neonPurple.opacity(0.80),
                                                 AppTheme.techGlow.opacity(0.40)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: AppTheme.neonPurple.opacity(0.30), radius: 10)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(AppTheme.neonPurple)
                }
            }
            .accessibilityLabel(language.text("tab.settings"))
        }
    }

    // MARK: - Games section header

    private var gameSectionHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppTheme.techGlow)
                .frame(width: 3, height: 15)
                .clipShape(Capsule())
            Text("GAMES")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .kerning(2.5)
            Spacer()
            if !games.isEmpty {
                Text("\(games.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.techGlow.opacity(0.8))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.techGlow.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.techGlow.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Device info — compact horizontal glass strip

    private var deviceInfoCard: some View {
        HStack(spacing: 0) {
            deviceChip(icon: "apple.logo", iconColor: .purple, value: "iOS \(shortOSVersion)")
            chipDivider
            deviceChip(icon: "iphone", iconColor: AppTheme.techGlow, value: AppInfo.hardwareDisplayName)
            chipDivider
            deviceChip(
                icon: appState.isSupported ? "checkmark.seal.fill" : "xmark.seal.fill",
                iconColor: appState.isSupported ? .green : .red,
                value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported")
            )
        }
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.white.opacity(0.04)
                LinearGradient(
                    colors: [AppTheme.techGlow.opacity(0.07), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), AppTheme.techGlow.opacity(0.45), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppTheme.techGlow.opacity(0.18), radius: 18, x: 0, y: 8)
    }

    private func deviceChip(icon: String, iconColor: Color, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var chipDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 38)
    }

    private var shortOSVersion: String {
        let version = AppInfo.osVersion
        if version.hasSuffix(".0") {
            return String(version.dropLast(2))
        }
        return version
    }

    /// Shown once, the very first time the app is reached (right after the first key redeems
    /// successfully) — the app doesn't know which language to speak yet, so the prompt itself is
    /// bilingual rather than guessing.
    private var languagePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "globe")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.techGlow)

                Text("Chọn ngôn ngữ / Choose Language")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                VStack(spacing: 12) {
                    languageOptionButton(title: "Tiếng Việt", code: .vietnamese)
                    languageOptionButton(title: "English", code: .english)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .techCard()
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }

    private func languageOptionButton(title: String, code: AppLanguage) -> some View {
        Button {
            languageCode = code.rawValue
            hasPickedLanguage = true
            showLanguagePicker = false
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button style: 3D press effect without blocking NavigationLink

private struct GameCard3DPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? -6 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.8
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Game Card (ảnh 2 style)

struct GameCardView: View {
    let game: RemoteGameSummary

    private var bannerColor: Color { AppTheme.resolvedBannerColor(game.bannerColor) }

    private var category: (label: String, color: Color) {
        let n = game.name.lowercased()
        if n.contains("free fire") || n.contains("pubg") || n.contains("cod") {
            return (n.contains("max") ? "BATTLE ROYALE" : "BATTLE ROYALE",
                    Color(red: 1.0, green: 0.55, blue: 0.10))
        }
        if n.contains("liên quân") || n.contains("lien quan") || n.contains("arena") {
            return ("MOBA", Color(red: 0.20, green: 0.55, blue: 1.00))
        }
        if n.contains("capcut") || n.contains("locket") || game.type == "app" {
            return ("TIỆN ÍCH", Color(red: 0.18, green: 0.80, blue: 0.44))
        }
        return ("GAME", bannerColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category badge
            HStack {
                Text(category.label)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color, in: Capsule())
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Icon
            Spacer()
            iconView
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: bannerColor.opacity(0.85), radius: 18, x: 0, y: 0)
                .shadow(color: bannerColor.opacity(0.40), radius: 36, x: 0, y: 0)
            Spacer()

            // Bottom strip
            VStack(spacing: 0) {
                Divider().overlay(bannerColor.opacity(0.25))
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(game.name)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(red: 0.18, green: 0.85, blue: 0.44))
                                .frame(width: 6, height: 6)
                            Text("Đã sẵn sàng")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color(red: 0.18, green: 0.85, blue: 0.44))
                        }
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(bannerColor)
                        .padding(7)
                        .background(bannerColor.opacity(0.18), in: Circle())
                        .overlay(Circle().strokeBorder(bannerColor.opacity(0.5), lineWidth: 1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(height: 190)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.04, green: 0.03, blue: 0.10)
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [bannerColor.opacity(0.9), bannerColor.opacity(0.3), bannerColor.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: bannerColor.opacity(0.45), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var iconView: some View {
        if let url = game.iconURL {
            CachedAsyncImage(url: url) { placeholderIcon }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        ZStack {
            bannerColor.opacity(0.3)
            Image(systemName: "app.fill")
                .resizable().scaledToFit().padding(16).foregroundStyle(.white)
        }
    }
}

/// Shows a locally cached copy immediately if one exists (so icons still render offline after
/// their first successful load), then refreshes from the network in the background when
/// possible. See RemoteImageCache for the on-disk persistence.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = RemoteImageCache.cachedImage(for: url) {
                uiImage = cached
            }
            if let fresh = await RemoteImageCache.fetchAndCache(url) {
                uiImage = fresh
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
