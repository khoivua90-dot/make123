import SwiftUI

struct ContentView: View {
    @StateObject private var licenseGate = LicenseGateStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if licenseGate.isChecking {
                ZStack {
                    TechBackground()
                    ProgressView()
                }
                .preferredColorScheme(.dark)
            } else if licenseGate.isUnlocked {
                GamesHomeView()
            } else {
                KeyEntryView()
            }
        }
        .environmentObject(licenseGate)
        .task {
            await licenseGate.bootstrap()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task { await licenseGate.revalidateIfNeeded() }
            }
        }
    }
}
