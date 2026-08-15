import Foundation

/// Gates the whole app behind a license key, mirroring the reference "enter key first" flow:
/// nothing else renders until `isUnlocked` is true. A rejection the server explicitly returned
/// (revoked / expired / bound to a different device) locks the app back out immediately; a
/// plain network hiccup does not, so a brief connectivity blip doesn't kick out an already
/// -verified user.
@MainActor
final class LicenseGateStore: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isChecking = true
    @Published private(set) var expiresAt: Date?
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let keyCodeDefaultsKey = "license.keyCode"

    private(set) var storedKeyCode: String? {
        get { defaults.string(forKey: keyCodeDefaultsKey) }
        set { defaults.set(newValue, forKey: keyCodeDefaultsKey) }
    }

    var maskedKeyCode: String {
        guard let code = storedKeyCode else { return "" }
        guard code.count > 8 else { return code }
        return "\(code.prefix(4))••••\(code.suffix(4))"
    }

    func bootstrap() async {
        isChecking = true
        defer { isChecking = false }
        guard let code = storedKeyCode, !code.isEmpty else {
            isUnlocked = false
            return
        }
        await refreshStatus(code: code)
    }

    /// Called periodically (e.g. on foreground) once already unlocked, to catch a key being
    /// revoked or expiring server-side while the app just sits open.
    func revalidateIfNeeded() async {
        guard isUnlocked, let code = storedKeyCode else { return }
        await refreshStatus(code: code)
    }

    @discardableResult
    func redeem(code rawCode: String) async -> Bool {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        errorMessage = nil
        do {
            let result = try await LicenseKeyService.redeem(
                code: code,
                deviceId: DeviceIdentity.current,
                deviceModel: AppInfo.hardwareDisplayName
            )
            storedKeyCode = code
            expiresAt = result.expiresAt
            isUnlocked = true
            return true
        } catch let error as LicenseKeyError {
            errorMessage = LocalizedStringResource.errorText(error)
            return false
        } catch {
            errorMessage = LocalizedStringResource.errorText(.network)
            return false
        }
    }

    func changeKey() {
        storedKeyCode = nil
        expiresAt = nil
        isUnlocked = false
        errorMessage = nil
    }

    private func refreshStatus(code: String) async {
        do {
            let result = try await LicenseKeyService.status(code: code, deviceId: DeviceIdentity.current)
            expiresAt = result.expiresAt
            isUnlocked = true
        } catch LicenseKeyError.network {
            // Connectivity issue only — keep whatever unlocked state we already had.
        } catch {
            isUnlocked = false
        }
    }
}

/// Small shim so LicenseGateStore (a plain ObservableObject, not a View) can still resolve a
/// message through the app's language system without needing an `AppLanguage` passed in from
/// every call site.
private enum LocalizedStringResource {
    static func errorText(_ error: LicenseKeyError) -> String {
        let code = AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? "") ?? .english
        return code.text(error.localizationKey)
    }
}
