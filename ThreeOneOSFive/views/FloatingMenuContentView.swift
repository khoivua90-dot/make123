import SwiftUI

/// The content rendered inside the floating quick-access window: a bare spinning gear (no
/// background, no glow) while collapsed, and the target game's patch menu once tapped open —
/// both states live in the same view/window, never two separate floating pieces. Reads whatever
/// this game already has synced locally (same storage GamePatchesView writes to); this window is
/// a shortcut to that data, not a second sync path.
struct FloatingMenuContentView: View {
    @ObservedObject var store: PatchProjectStore
    let game: RemoteGameSummary
    var onRequestCollapse: () -> Void = {}
    /// The hosting PiP window is a fixed-size rectangle — it can't just shrink-wrap a bare icon
    /// on its own, so this tells `FloatingOverlayController` to resize the window itself to match
    /// whichever state is showing, instead of always reserving the full panel's footprint.
    var onExpansionChange: (Bool) -> Void = { _ in }

    @State private var isExpanded = false
    @State private var containers: [RemoteContainerSummary] = []
    @State private var selectedContainerID: String?
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @State private var rotationAngle: Double = 0
    @State private var spinColorIndex = 0

    @AppStorage("patch.gameAssignments") private var gameAssignmentsRaw = "{}"
    @AppStorage("patch.containerAssignments") private var containerAssignmentsRaw = "{}"
    @AppStorage("patch.remoteDisplayNames") private var remoteDisplayNamesRaw = "{}"

    private static let spinColors: [Color] = [
        AppTheme.techGlow,
        Color(red: 1.00, green: 0.56, blue: 0.24),
        Color(red: 0.96, green: 0.28, blue: 0.42),
        Color(red: 0.66, green: 0.46, blue: 0.98),
        Color(red: 0.36, green: 0.85, blue: 0.56)
    ]

    private var gameAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(gameAssignmentsRaw.utf8))) ?? [:]
    }
    private var containerAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(containerAssignmentsRaw.utf8))) ?? [:]
    }
    private var remoteDisplayNames: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remoteDisplayNamesRaw.utf8))) ?? [:]
    }

    private var items: [PatchLibraryItem] {
        let assignments = gameAssignments
        return store.items.filter { assignments[$0.id.uuidString] == game.id && !$0.isLocked }
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let selectedContainerID else { return items }
        let assignments = containerAssignments
        return items.filter { assignments[$0.id.uuidString] == selectedContainerID }
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        remoteDisplayNames[item.id.uuidString] ?? item.project?.name ?? ""
    }

    var body: some View {
        ZStack {
            if isExpanded {
                panel.transition(.opacity)
            } else {
                bubble.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: isExpanded) { onExpansionChange($0) }
        .task {
            await loadContainers()
            await loadProjectStates()
        }
        .task {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                spinColorIndex += 1
            }
        }
    }

    // MARK: - Collapsed bubble

    private var bubble: some View {
        Button {
            isExpanded = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(Self.spinColors[spinColorIndex % Self.spinColors.count])
                .rotationEffect(.degrees(rotationAngle))
                .frame(width: 58, height: 58)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded panel

    /// Always the landscape sidebar-on-the-left layout, regardless of device orientation.
    private var panel: some View {
        HStack(spacing: 0) {
            if !containers.isEmpty { sidebar }
            mainContent
        }
        .background(Color(red: 0.045, green: 0.06, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
        )
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().overlay(Color.white.opacity(0.08))
            ScrollView(showsIndicators: false) {
                rowsList
            }
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.techGlow)
            Text(game.name)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Spacer()
            // Only this button closes the panel back to the bare bubble — nothing else in the
            // panel does, so an X reads clearer here than an ambiguous chevron.
            Button {
                isExpanded = false
                onRequestCollapse()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    /// A borderless vertical tab rail down the left edge, with one sliding highlight behind the
    /// selected tab.
    private var sidebar: some View {
        VStack(spacing: 4) {
            ForEach(containers) { container in
                tabButton(container)
            }
        }
        .padding(8)
        .frame(width: 62)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1)
        }
    }

    private func tabButton(_ container: RemoteContainerSummary) -> some View {
        let isSelected = selectedContainerID == container.id
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selectedContainerID = container.id
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: container.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .scaleEffect(isSelected ? 1.16 : 1.0)
                Text(container.name)
                    .font(.system(size: 9.5, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? AppTheme.techGlow : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private var rowsList: some View {
        VStack(spacing: 0) {
            if displayedItems.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 26)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                    row(item, colorIndex: index)
                    if item.id != displayedItems.last?.id {
                        Divider().overlay(Color.white.opacity(0.055))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func row(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        let rules = item.project?.rules ?? []
        let toggleableCount = rules.filter(\.canToggle).count
        let rowColor = AppTheme.rowColor(colorIndex)

        return HStack(spacing: 9) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundStyle(rowColor)
                .frame(width: 26, height: 26)
                .background(rowColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            Text(displayName(for: item))
                .font(.system(size: 11.5, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if togglingProjectID == item.id {
                ProgressView().scaleEffect(0.7)
            } else {
                Toggle("", isOn: projectToggleBinding(for: item))
                    .labelsHidden()
                    .tint(AppTheme.techGlow)
                    .scaleEffect(0.82)
                    .disabled(toggleableCount == 0)
            }
        }
        .padding(.vertical, 8)
    }

    private func projectToggleBinding(for item: PatchLibraryItem) -> Binding<Bool> {
        Binding(
            get: { projectStates[item.id] ?? false },
            set: { setProjectState($0, item: item) }
        )
    }

    // MARK: - Data

    private func loadContainers() async {
        guard let fetched = try? await PatchHubService.fetchContainers() else { return }
        let forGame = fetched.filter { $0.gameId == game.id }.sorted { $0.order < $1.order }
        containers = forGame
        if selectedContainerID == nil || !forGame.contains(where: { $0.id == selectedContainerID }) {
            selectedContainerID = forGame.first?.id
        }
    }

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
            for rule in toggleableRules {
                try? DevicePatchService.setRuleState(isOn, rule: rule)
            }
            let actualState = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
            }
        }
    }
}
