import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PatchProjectsView()
                .tabItem {
                    Label(language.text("tab.home"), systemImage: "house")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label(language.text("tab.settings"), systemImage: "gearshape")
                }
                .tag(1)
        }
        .tint(AppTheme.accent)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { selectedTab = 0 }
        }
    }
}
