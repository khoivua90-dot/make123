import SwiftUI

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(games) { game in
                        NavigationLink {
                            GamePatchesView(game: game, store: store)
                        } label: {
                            GameCardView(
                                title: game.name,
                                subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                                bannerColor: Color(hex: game.bannerColor) ?? AppTheme.accent,
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
            .navigationTitle(language.text("tab.home"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        PatchProjectsView(store: store)
                    } label: {
                        Image(systemName: "shippingbox")
                    }
                    .accessibilityLabel(language.text("patch.my_patches"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("tab.settings"))
                }
            }
            .refreshable { await loadGames() }
            .task { await loadGames() }
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
    }

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
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
            .background(AppTheme.consoleBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            AsyncImage(url: iconURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderIcon
                }
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

private extension Color {
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
