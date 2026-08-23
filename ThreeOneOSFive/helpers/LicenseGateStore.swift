import Foundation

@MainActor
final class LicenseGateStore: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isChecking = true
    @Published var errorMessage: String?
    @Published var activationToast: ToastMessage?

    private static let ppToken = "TKsA8JJzYfLlvTXCLgOSsOfVBlco0J6ASizdYH2FjavN3YY3XupvrxQphqcARpDgmiLRq8CER1u2OkxICggrgzftTxChW76tKRNo"

    var storedKeyCode: String? {
        let k = PPAPIKey.shared().getDeviceKey()
        return (k?.isEmpty == false) ? k : nil
    }

    var maskedKeyCode: String {
        guard let code = storedKeyCode else { return "" }
        guard code.count > 8 else { return code }
        return "\(code.prefix(4))••••\(code.suffix(4))"
    }

    var expiresAt: Date? {
        guard let raw = PPAPIKey.shared().getKeyExpire(), !raw.isEmpty else { return nil }
        let formats = ["dd/MM/yyyy HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy", "yyyy-MM-dd"]
        for fmt in formats {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = fmt
            if let d = f.date(from: raw) { return d }
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    var licenseDevices: [LicenseDeviceEntry] { [] }

    func remainingTimeText(language: AppLanguage) -> String {
        guard let expiresAt else { return "" }
        let seconds = expiresAt.timeIntervalSinceNow
        guard seconds > 0 else { return language.text("license.expired") }
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        return language.text("license.remaining", Int64(days), Int64(hours))
    }

    func bootstrap() async {
        PPAPIKey.shared().setToken(Self.ppToken)
        PPAPIKey.shared().setEN(false)
        PPAPIKey.shared().setVer("1.0")
        isChecking = false
        PPAPIKey.shared().loading {
            Task { @MainActor in
                self.isUnlocked = true
            }
        }
    }

    func revalidateIfNeeded() async {}

    @discardableResult
    func redeem(code rawCode: String) async -> Bool { return false }

    func changeKey() {
        isUnlocked = false
        PPAPIKey.shared().exitKey { _ in
            Task { @MainActor in
                PPAPIKey.shared().loading {
                    Task { @MainActor in
                        self.isUnlocked = true
                    }
                }
            }
        }
    }
}
