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
    private var latestPath: NWPath?

    func start() {
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.latestPath = path
                self?.applyPath(path)
            }
        }
        m.start(queue: DispatchQueue(label: "cios.netsec", qos: .utility))
        pathMonitor = m
    }

    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func refresh() {
        if let p = latestPath {
            applyPath(p)
        } else {
            isProxyActive = Self.detectProxy()
        }
    }

    // MARK: - Private

    private func applyPath(_ path: NWPath) {
        // On iOS, type .other is the VPN tunnel interface family.
        // We require the active network path to route through it so that
        // dormant utun interfaces (iCloud Private Relay, Screen Time content
        // filter, MDM profiles) that have an IPv4 address but carry no user
        // traffic don't cause a false positive.
        let pathUsesVPNType = path.usesInterfaceType(.other)

        // Belt-and-suspenders: also confirm a tunnel interface actually has an
        // AF_INET address, so a USB-Ethernet dongle alone (also .other) can't
        // trigger the block.
        let tunnelHasIPv4 = Self.tunnelInterfaceHasIPv4()

        isVPNActive   = pathUsesVPNType && tunnelHasIPv4
        isProxyActive = Self.detectProxy()
    }

    /// Returns true when any tunnel interface (utun*, ipsec*, ppp*) carries an
    /// active IPv4 address — the reliable signal that a VPN tunnel is up.
    private static func tunnelInterfaceHasIPv4() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let head = ifaddr else { return false }
        defer { freeifaddrs(head) }

        var cur: UnsafeMutablePointer<ifaddrs>? = head
        while let node = cur {
            let name = String(cString: node.pointee.ifa_name)
            let isTunnel = name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")
            if isTunnel, let addr = node.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                return true
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
