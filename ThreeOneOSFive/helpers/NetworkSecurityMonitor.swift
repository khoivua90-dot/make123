import Darwin
import Foundation
import Network

/// Monitors for active VPN connections and system proxy settings.
/// Publishes `isBlocked = true` the moment either is detected so the UI can
/// show a hard blocking screen without any async delay.
@MainActor
final class NetworkSecurityMonitor: ObservableObject {
    @Published private(set) var isVPNActive = false
    @Published private(set) var isProxyActive = false

    var isBlocked: Bool { isVPNActive || isProxyActive }

    private var pathMonitor: NWPathMonitor?

    func start() {
        refresh()
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        m.start(queue: DispatchQueue(label: "cios.netsec", qos: .utility))
        pathMonitor = m
    }

    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func refresh() {
        isVPNActive  = Self.detectVPN()
        isProxyActive = Self.detectProxy()
    }

    // MARK: - Detection

    /// Returns true when a VPN tunnel interface has an active IPv4 address —
    /// that is the reliable signal that iOS shows the VPN badge in the status bar.
    private static func detectVPN() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let head = ifaddr else { return false }
        defer { freeifaddrs(head) }

        var cur: UnsafeMutablePointer<ifaddrs>? = head
        while let node = cur {
            let name = String(cString: node.pointee.ifa_name)
            let isTunnel = name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            if isTunnel, let addr = node.pointee.ifa_addr {
                // Only flag when there is a real IPv4 address — link-local IPv6
                // exists on utun0 even without VPN, so we ignore AF_INET6 here.
                if addr.pointee.sa_family == UInt8(AF_INET) {
                    return true
                }
            }
            cur = node.pointee.ifa_next
        }
        return false
    }

    /// Returns true when an HTTP, HTTPS, or SOCKS proxy is configured system-wide.
    private static func detectProxy() -> Bool {
        guard let raw = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let settings = raw as? [String: Any] else { return false }
        for key in ["HTTPProxy", "HTTPSProxy", "SOCKSProxy"] {
            if let host = settings[key] as? String, !host.isEmpty { return true }
        }
        return false
    }
}
