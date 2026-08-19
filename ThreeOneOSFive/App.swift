import SwiftUI
import Darwin

// csops CS_OPS_IDENTITY returns the CodeDirectory identifier string for a pid.
// SecTaskCreateFromSelf/SecTaskCopySigningIdentifier are macOS-only; csops works on iOS.
@_silgen_name("csops")
private func csops_raw(_ pid: pid_t, _ ops: UInt32, _ useraddr: UnsafeMutableRawPointer?, _ usersize: Int) -> Int32

func hasMobileHouseArrestCodeDirectory() -> Bool {
    var buf = [UInt8](repeating: 0, count: 256)
    guard csops_raw(getpid(), 8 /* CS_OPS_IDENTITY */, &buf, buf.count) == 0 else { return false }
    return String(cString: buf) == "com.apple.mobile.MobileHouseArrest"
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
        guard hasMobileHouseArrestCodeDirectory() else {
            exploitStatus = .failed(method: "mha-cert", code: -1)
            return
        }
        // Xác minh MCM thực sự cấp sandbox extension trên thiết bị này.
        // iOS 18 containermanagerd yêu cầu platform binary / entitlement riêng;
        // eSigned app chỉ với bundle ID đúng vẫn bị từ chối trên iOS 18.2+.
        var testErr: NSString?
        let testPath = MCMActivateContainerPath(2, "com.apple.mobilesafari", false, &testErr)
        if testPath != nil {
            exploitStatus = .success(method: "mha")
        } else {
            let reason = (testErr as String?) ?? "denied"
            NSLog("[3105] MCM probe failed: \(reason)")
            exploitStatus = .failed(method: "mha-os", code: -2)
        }
    }
}
