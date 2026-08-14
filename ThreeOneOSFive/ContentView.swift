import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var selectedTab: Int

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 1
        } else {
            initialTab = 0
        }
        _selectedTab = State(initialValue: initialTab)
#else
        _selectedTab = State(initialValue: 0)
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PatchProjectsView()
                .tabItem {
                    Label(language.text("tab.home"), systemImage: "house")
                }
                .tag(0)

            CleanerView()
                .tabItem {
                    Label(language.text("tab.cleaner"), systemImage: "sparkles")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label(language.text("tab.settings"), systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(AppTheme.accent)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { selectedTab = 0 }
        }
    }
}
