import SwiftUI

struct ContentView: View {
    @StateObject private var netSecurity = NetworkSecurityMonitor()
    @State private var isCheckingMaintenance = true
    @State private var maintenanceNotice: MaintenanceNotice?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if netSecurity.isVPNActive {
                VPNBlockView(isVPN: true, onRetry: { netSecurity.refresh() })
            } else if netSecurity.isProxyActive {
                VPNBlockView(isVPN: false, onRetry: { netSecurity.refresh() })
            } else if isCheckingMaintenance {
                ZStack {
                    TechBackground()
                    ProgressView()
                }
                .preferredColorScheme(.dark)
            } else if let maintenanceNotice {
                MaintenanceView(notice: maintenanceNotice)
            } else {
                GamesHomeView()
            }
        }
        .task {
            netSecurity.start()
            await checkMaintenance()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                netSecurity.refresh()
                Task {
                    await checkMaintenance()
                }
            }
        }
    }

    private func checkMaintenance() async {
        if case .maintenance(let notice) = await AnnouncementService.fetchState() {
            maintenanceNotice = notice
        } else {
            maintenanceNotice = nil
        }
        isCheckingMaintenance = false
    }
}
