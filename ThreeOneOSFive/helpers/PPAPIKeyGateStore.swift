import Foundation

/// Gates the whole app behind PPAPIKey (pp7803/APIKey) instead of the previous custom
/// Panel Key backend. `loading(_:)` presents PPAPIKey's own native key-entry UI when no
/// valid key is stored yet and only calls back once a key has been accepted, so this store
/// just waits for that callback rather than driving its own entry screen.
@MainActor
final class PPAPIKeyGateStore: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isChecking = true
    @Published var activationToast: ToastMessage?

    private static let packageToken = "ifGEaV6xVgR1jXGt1jIqmNOoPjo2XVG3r2wDEfmRTusQmj4u2tGXAoC6BlWkICqNkjRwxBme5gLk1XCz7U4BhdGINJy3MtIyYCRC"
    private var didBootstrap = false

    var maskedKeyCode: String {
        let code = PPAPIKey.shared().getDeviceKey()
        guard code.count > 8 else { return code }
        return "\(code.prefix(4))••••\(code.suffix(4))"
    }

    var remainingTimeText: String {
        PPAPIKey.shared().getExpire()
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        isChecking = true

        let language = LocalizedStringResource.currentLanguage
        let api = PPAPIKey.shared()
        api.setToken(Self.packageToken)
        api.setVer(AppInfo.osVersion)
        api.setEN(language == .english)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            api.loading {
                continuation.resume()
            }
        }

        isChecking = false
        isUnlocked = true
        let detail = language.text("license.activated_detail", AppInfo.hardwareDisplayName, remainingTimeText)
        activationToast = ToastMessage(text: "\(language.text("license.activated_success"))\n\(detail)")
    }

    /// Removes the current key and re-runs the PPAPIKey flow, which shows its own key-entry
    /// UI again since there's no longer a valid key stored.
    func changeKey() {
        isUnlocked = false
        isChecking = true
        didBootstrap = false
        PPAPIKey.shared().exitKey { [weak self] _ in
            Task { @MainActor in
                await self?.bootstrap()
            }
        }
    }
}

/// Small shim so PPAPIKeyGateStore (a plain ObservableObject, not a View) can still resolve a
/// message through the app's language system without needing an `AppLanguage` passed in from
/// every call site.
private enum LocalizedStringResource {
    static var currentLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? "") ?? .english
    }
}
