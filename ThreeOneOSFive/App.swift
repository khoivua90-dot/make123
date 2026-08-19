import SwiftUI
import Darwin
import Security

// Returns true nếu CodeDirectory identifier (chữ ký thực) là com.apple.mobile.MobileHouseArrest.
// Info.plist bundle ID có thể đúng nhưng CodeDirectory vẫn sai nếu signing tool tự đổi.
func hasMobileHouseArrestCodeDirectory() -> Bool {
    guard let task = SecTaskCreateFromSelf(kCFAllocatorDefault) else { return false }
    let id = SecTaskCopySigningIdentifier(task, nil) as String?
    return id == "com.apple.mobile.MobileHouseArrest"
}

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
            return
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        guard supported else {
            exploitStatus = .unsupported(unsupportedMessage ?? "")
            return
        }

        // Kiểm tra xem app có native access không (TrollStore / entitlements).
        let testFd = open("/var/mobile/Containers/Data/Application", O_RDONLY | O_DIRECTORY)
        if testFd >= 0 {
            close(testFd)
            exploitStatus = .success(method: "native")
            return
        }

        // Chạy kexploit_opa334 trên background thread để tránh block UI.
        // Nếu thành công → sandbox_escape → full filesystem access.
        // Nếu fail → fall back sang MCM MHA path.
        exploitStatus = .running
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = kexploit_and_escape()
            DispatchQueue.main.async {
                guard let self else { return }
                if result == 0 {
                    self.exploitStatus = .success(method: "kexploit")
                } else {
                    NSLog("[3105] kexploit_and_escape failed code=\(result), trying MCM fallback")
                    self.resolveMHAFallback()
                }
            }
        }
    }

    private func resolveMHAFallback() {
        // iOS 17 và 18: MCM cấp token khi CodeDirectory = MHA.
        if hasMobileHouseArrestCodeDirectory() {
            exploitStatus = .success(method: "mha")
        } else {
            exploitStatus = .failed(method: "mha-cert", code: -1)
        }
    }
}
