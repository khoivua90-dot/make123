import Foundation
import Security

/// iOS gives no app — not even one with a kernel r/w bug — access to the real hardware serial
/// number; IOPlatformSerialNumber is gated by a code-signing entitlement Apple only grants to
/// its own daemons/MDM, not something a sandbox-escape bug can bypass. This is the practical
/// substitute: a random UUID generated once and kept in the Keychain, which (unlike
/// UserDefaults) survives an app delete + reinstall on the same device, so a license key stays
/// bound to "this device" the way a serial number would.
enum DeviceIdentity {
    private static let service = "com.cheatiosvip.device-identity"
    private static let account = "device-id"

    static let current: String = load() ?? {
        let fresh = UUID().uuidString
        save(fresh)
        return fresh
    }()

    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { return }
        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        SecItemAdd(newItem as CFDictionary, nil)
    }
}
