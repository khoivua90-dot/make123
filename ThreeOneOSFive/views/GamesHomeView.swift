import SwiftUI
import UIKit

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showLanguagePicker = false
    @AppStorage("language.hasPicked") private var hasPickedLanguage = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

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

                ScrollView {
                    deviceInfoCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(games) { game in
                            NavigationLink {
                                GamePatchesView(game: game, store: store)
                            } label: {
                                GameCardView(
                                    title: game.name,
                                    subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                                    bannerColor: AppTheme.resolvedBannerColor(game.bannerColor),
                                    iconURL: game.iconURL,
                                    systemIconName: "app.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)

                    if games.isEmpty && !isLoadingGames {
                        Text(language.text("patch.no_games_yet"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(language.text("tab.home"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color(red: 0.15, green: 0.48, blue: 0.93))
                    }
                    .accessibilityLabel(language.text("tab.settings"))
                }
            }
            .refreshable { await loadGames() }
            .task { await loadGames() }
            .safeAreaInset(edge: .bottom) {
                LicenseStatusBar()
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

    private var deviceInfoCard: some View {
        VStack(spacing: 12) {
            deviceInfoRow(icon: "apple.logo", iconColor: .purple, label: language.text("common.ios"), value: shortOSVersion)
            deviceInfoRow(icon: "iphone", iconColor: AppTheme.techGlow, label: language.text("common.device"), value: AppInfo.hardwareDisplayName)
            deviceInfoRow(
                icon: appState.isSupported ? "checkmark.seal.fill" : "xmark.seal.fill",
                iconColor: appState.isSupported ? .green : .red,
                label: language.text("settings.support"),
                value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported")
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard()
    }

    private func deviceInfoRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 18)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
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

struct GameCardView: View {
    let title: String
    let subtitle: String
    let bannerColor: Color
    let iconURL: URL?
    let systemIconName: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                bannerColor
                iconView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            }
            .frame(height: 88)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.techCardFill)
        }
        .background(Color.black.opacity(0.001))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
        )
        .shadow(color: AppTheme.techGlow.opacity(0.10), radius: 10, y: 0)
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            CachedAsyncImage(url: iconURL) {
                placeholderIcon
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: systemIconName)
            .resizable()
            .scaledToFit()
            .padding(13)
            .foregroundStyle(.white)
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
