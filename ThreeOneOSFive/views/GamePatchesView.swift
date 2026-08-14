import SwiftUI

struct GamePatchesView: View {
    @Environment(\.appLanguage) private var language
    let game: RemoteGameSummary
    @ObservedObject var store: PatchProjectStore

    @State private var isSyncing = false
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @AppStorage("patch.importedOnlineIDs") private var importedOnlineIDsRaw = ""
    @AppStorage("patch.gameAssignments") private var gameAssignmentsRaw = "{}"

    private var importedOnlineIDs: Set<String> {
        Set(importedOnlineIDsRaw.split(separator: ",").map(String.init))
    }

    private var gameAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(gameAssignmentsRaw.utf8))) ?? [:]
    }

    private var items: [PatchLibraryItem] {
        let assignments = gameAssignments
        return store.items.filter { assignments[$0.id.uuidString] == game.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                if items.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(items) { item in
                        itemRow(item)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await sync() }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSyncing {
                    ProgressView()
                }
            }
        }
        .task {
            await sync()
            await loadProjectStates()
        }
        .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { _ in
            PatchUnlockView(store: store)
        }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            gameIconView
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

            Text(game.name)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            if !game.bundleID.isEmpty {
                Text(game.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var gameIconView: some View {
        if let url = game.iconURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    gameIconPlaceholder
                }
            }
        } else {
            gameIconPlaceholder
        }
    }

    private var gameIconPlaceholder: some View {
        ZStack {
            Color(hex: game.bannerColor) ?? AppTheme.accent
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(20)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: {
                PatchProjectRow(item: item, language: language)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                PatchProjectDetailView(store: store, projectID: item.id)
            } label: {
                toggleRow(item)
            }
        }
    }

    private func toggleRow(_ item: PatchLibraryItem) -> some View {
        let rules = item.project?.rules ?? []
        let toggleableCount = rules.filter(\.canToggle).count

        return HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(language.text("patch.rules_count", Int64(rules.count)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if togglingProjectID == item.id {
                ProgressView()
            } else {
                Toggle("", isOn: projectToggleBinding(for: item))
                    .labelsHidden()
                    .disabled(toggleableCount == 0)
            }
        }
        .padding(.vertical, 4)
    }

    private func projectToggleBinding(for item: PatchLibraryItem) -> Binding<Bool> {
        Binding(
            get: { projectStates[item.id] ?? false },
            set: { setProjectState($0, item: item) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if isSyncing {
                ProgressView()
            } else {
                Image(systemName: "shippingbox")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(AppTheme.accent)
                Text(language.text("patch.empty_title"))
                    .font(.headline)
                Text(language.text("patch.game_empty_message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    /// Downloads only this game's patches from the hub straight into the local library, so
    /// they show up here without any manual tap. The gameId -> local packageID mapping is
    /// recorded locally since the encrypted .3105 format itself carries no game association.
    private func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let remoteItems = try? await PatchHubService.fetchPatches() else { return }
        let pending = remoteItems.filter { $0.gameId == game.id && !importedOnlineIDs.contains($0.id) }
        guard !pending.isEmpty else { return }

        var imported = importedOnlineIDs
        var assignments = gameAssignments
        var didImportAny = false

        for item in pending {
            do {
                let fileURL = try await PatchHubService.downloadPatch(item)
                let packageIDString: String? = await Task.detached(priority: .utility) {
                    do {
                        let data = try PatchProjectLibrary.readPackage(at: fileURL)
                        let summary = try PatchPackageCodec.inspect(data)
                        _ = try PatchProjectLibrary.save(data: data, projectName: item.name)
                        try? FileManager.default.removeItem(at: fileURL)
                        return summary.packageID.uuidString
                    } catch {
                        return nil
                    }
                }.value
                if let packageIDString {
                    imported.insert(item.id)
                    assignments[packageIDString] = game.id
                    didImportAny = true
                }
            } catch {
                continue
            }
        }

        importedOnlineIDsRaw = imported.joined(separator: ",")
        if let encoded = try? JSONEncoder().encode(assignments), let json = String(data: encoded, encoding: .utf8) {
            gameAssignmentsRaw = json
        }
        if didImportAny {
            store.reload()
        }
    }

    /// A patch's toggle reflects every toggle-capable rule in it at once: on only when all of
    /// them currently show their replacement active on disk, off otherwise (including "never
    /// applied yet"). Rules without a bundled original are skipped — they simply can't report
    /// or accept an "off" state.
    private func loadProjectStates() async {
        let currentItems = items
        guard !currentItems.isEmpty else { return }
        let states: [UUID: Bool] = await Task.detached(priority: .userInitiated) {
            var result: [UUID: Bool] = [:]
            for item in currentItems {
                let toggleableRules = (item.project?.rules ?? []).filter(\.canToggle)
                guard !toggleableRules.isEmpty else { continue }
                let allOn = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
                result[item.id] = allOn
            }
            return result
        }.value
        projectStates = states
    }

    private func setProjectState(_ isOn: Bool, item: PatchLibraryItem) {
        let toggleableRules = (item.project?.rules ?? []).filter(\.canToggle)
        guard !toggleableRules.isEmpty, togglingProjectID == nil else { return }
        togglingProjectID = item.id
        Task.detached(priority: .userInitiated) {
            var failure: PatchPackageError?
            for rule in toggleableRules {
                do {
                    try DevicePatchService.setRuleState(isOn, rule: rule)
                } catch let error as PatchPackageError {
                    failure = error
                } catch {
                    failure = .applyFailed
                }
            }
            // Re-read actual on-device state rather than assume success, since a partial
            // failure partway through the loop would otherwise show a state that never
            // really landed on every file.
            let actualState = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
                if let failure {
                    store.alert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: failure.localizationKey,
                        messageArgument: failure.localizationArgument
                    )
                }
            }
        }
    }
}
