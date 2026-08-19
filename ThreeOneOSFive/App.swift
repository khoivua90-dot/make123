import SwiftUI
import Darwin

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patchDraftCoordinator)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .onAppear {
                    appState.detectSupport()
                }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        guard supported else {
            exploitStatus = .unsupported(unsupportedMessage ?? "")
            return
        }

        // Nếu đã có native access (TrollStore / entitlements), không cần exploit.
        let testFd = open("/var/mobile/Containers/Data/Application", O_RDONLY | O_DIRECTORY)
        if testFd >= 0 {
            close(testFd)
            exploitStatus = .success(method: "native")
            return
        }

        // eSigned device — cần kernel exploit để escape sandbox trước khi patch.
        Task.detached(priority: .userInitiated) { [weak self] in
            let kr = kexploit_opa334()
            guard kr == 0 else {
                await MainActor.run { [weak self] in
                    self?.exploitStatus = .failed(method: "kexploit_opa334", code: Int64(kr))
                }
                return
            }
            let sp = proc_self()
            let sbxr = sandbox_escape(sp)
            await MainActor.run { [weak self] in
                self?.exploitStatus = sbxr == 0
                    ? .success(method: "kexploit_opa334")
                    : .failed(method: "sandbox_escape", code: Int64(sbxr))
            }
        }
    }
}
