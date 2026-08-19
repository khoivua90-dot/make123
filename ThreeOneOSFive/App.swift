import SwiftUI

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
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
            return
        }
#endif
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        // FilzaJailedDS exploit supports iOS 17.0–26.0.x only.
        // iOS 26.1+ (including iOS 27) uses MCM via MobileHouseArrest — no kernel exploit needed.
        let major = v.major
        let minor = v.minor
        let exploitSupported = (major == 17) || (major == 18) || (major == 26 && minor == 0)
        guard exploitSupported else {
            exploitStatus = .success(method: "mha")
            return
        }

        exploitStatus = .running
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let kret = kexploit_opa334()
            guard kret == 0 else {
                DispatchQueue.main.async { self.exploitStatus = .failed(method: "kexploit", code: Int64(kret)) }
                return
            }
            NSLog("[3105] kexploit OK")

            let kcret = grab_kernelcache()
            guard kcret == 0 else {
                DispatchQueue.main.async { self.exploitStatus = .failed(method: "grab-kc", code: Int64(kcret)) }
                return
            }
            NSLog("[3105] kernelcache grabbed OK")

            let xret = init_xpf()
            guard xret == 0 else {
                DispatchQueue.main.async { self.exploitStatus = .failed(method: "xpf", code: Int64(xret)) }
                return
            }
            NSLog("[3105] XPF offsets OK")

            let selfProc = proc_self()
            let eret = sandbox_escape(selfProc)
            guard eret == 0 else {
                DispatchQueue.main.async { self.exploitStatus = .failed(method: "escape", code: Int64(eret)) }
                return
            }
            NSLog("[3105] sandbox escaped OK proc=0x%llx", selfProc)

            DispatchQueue.main.async { self.exploitStatus = .success(method: "dsw") }
        }
    }
}
