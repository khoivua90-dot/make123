import Foundation

enum ExploitSupportPolicy {
    /// The kernel exploit and offset-finding logic underneath this (kexploit_opa334 + pattern
    /// -matched offsets, ported from FilzaSlop) targets iOS 17–26 generally, but this app has
    /// only actually been verified against the ranges below — FilzaSlop's own README, and
    /// independently `rooootdev/lara`'s support table, both draw the same line at 18.7.1: iOS
    /// 18.7.2 and later change something the current offsets don't account for.
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0–26.6.1"

    static let verifiedIOS27Builds: [(beta: Int, build: String)] = [
        (1, "24A5355q"),
        (2, "24A5370h"),
        (3, "24A5380h"),
        (4, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if major == 17 {
            return true
        }
        if major == 18 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 7 || (minor == 7 && patch <= 1)
        }
        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            return minor < 6 || (minor == 6 && patch <= 1)
        }

        guard major == 27, minor == 0, patch == 0 else { return false }
        return iOS27BetaNumber(for: build) != nil
    }
}
