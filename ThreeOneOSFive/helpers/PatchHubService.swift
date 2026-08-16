import CryptoKit
import Foundation

struct RemotePatchSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let version: String
    let fileName: String
    let sizeBytes: Int64
    let sha256: String
    let createdAt: String
    let gameId: String?
    let containerId: String?
}

/// A tab within a game's patch screen (e.g. Proxy / Định Vị / Mod NV), so a game's patches can
/// be grouped instead of always showing as one flat list.
struct RemoteContainerSummary: Decodable, Identifiable, Equatable {
    let id: String
    let gameId: String
    let name: String
    let icon: String
    let order: Int
}

struct RemoteGameSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let bundleID: String
    let bannerColor: String
    let iconPath: String?
    let createdAt: String

    var iconURL: URL? {
        guard let iconPath else { return nil }
        return PatchHubService.baseURL.appendingPathComponent(String(iconPath.dropFirst()))
    }
}

enum PatchHubError: Error {
    case invalidResponse
    case checksumMismatch
}

enum PatchHubService {
    static let baseURL = URL(string: "https://patches.cheatiosvip.net")!

    // XOR key = 0x4B — strings are never stored as plaintext in the compiled binary
    private static let _t: [UInt8] = [
        0x28, 0x22, 0x24, 0x38, 0x3D, 0x22, 0x3B, 0x14, 0x72, 0x19, 0x33, 0x7F, 0x20, 0x11,
        0x79, 0x26, 0x1A, 0x7C, 0x3C, 0x05, 0x78, 0x3B, 0x07, 0x73, 0x14, 0x0F, 0x01, 0x1F,
        0x06, 0x0E, 0x06, 0x0A, 0x12, 0x1F, 0x03, 0x0A, 0x05, 0x0C, 0x07, 0x04, 0x05, 0x08,
        0x19, 0x0A, 0x08, 0x00, 0x0D, 0x0A, 0x05, 0x0C, 0x05, 0x03, 0x0E, 0x0A, 0x05, 0x08,
        0x1E, 0x08, 0x0A, 0x08, 0x1F, 0x0A, 0x04, 0x05, 0x0E
    ]
    private static let _g: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x2C, 0x2A, 0x26, 0x2E, 0x38]
    private static let _p: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x3B, 0x2A, 0x3F, 0x28, 0x23, 0x2E, 0x38]
    private static let _c: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x28, 0x24, 0x25, 0x3F, 0x2A, 0x22, 0x25, 0x2E, 0x39, 0x38]
    private static let _n: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x25, 0x24, 0x3F, 0x22, 0x28, 0x2E]
    private static let _r: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x39, 0x2E, 0x2F, 0x2E, 0x2E, 0x26]
    private static let _s: [UInt8] = [0x2A, 0x3B, 0x22, 0x64, 0x20, 0x2E, 0x32, 0x38, 0x64, 0x38, 0x3F, 0x2A, 0x3F, 0x3E, 0x38]
    // HMAC signing secret — XOR key 0x4B, decodes to "D5W_hmac_sig_v2_9mQx7nR4pLk8"
    private static let _sk: [UInt8] = [
        0x0F, 0x7E, 0x1C, 0x14, 0x23, 0x26, 0x2A, 0x28, 0x14, 0x38, 0x22, 0x2C, 0x14, 0x3D,
        0x79, 0x14, 0x72, 0x26, 0x1A, 0x33, 0x7C, 0x25, 0x19, 0x7F, 0x3B, 0x07, 0x20, 0x73
    ]

    private static func d(_ b: [UInt8]) -> String {
        String(bytes: b.map { $0 ^ 0x4B }, encoding: .utf8) ?? ""
    }

    static var clientToken: String { d(_t) }
    static var pathGames: String { d(_g) }
    static var pathPatches: String { d(_p) }
    static var pathContainers: String { d(_c) }
    static var pathNotice: String { d(_n) }
    static var pathRedeem: String { d(_r) }
    static var pathStatus: String { d(_s) }

    /// Signs a key-API request with HMAC-SHA256 so the server can reject forged/replayed calls.
    /// Returns (timestamp ms string, nonce UUID string, hex signature).
    static func signKeyRequest(code: String, deviceId: String) -> (ts: String, nonce: String, sig: String) {
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let payload = "\(ts):\(nonce):\(code):\(deviceId)"
        let secret = d(_sk)
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        let sig = Data(mac).map { String(format: "%02x", $0) }.joined()
        return (ts, nonce, sig)
    }

    private static func get(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue(clientToken, forHTTPHeaderField: "X-App-Token")
        return r
    }

    static func fetchGames() async throws -> [RemoteGameSummary] {
        let url = baseURL.appendingPathComponent(pathGames)
        let (data, response) = try await URLSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let games: [RemoteGameSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).games
    }

    static func fetchPatches() async throws -> [RemotePatchSummary] {
        let url = baseURL.appendingPathComponent(pathPatches)
        let (data, response) = try await URLSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let patches: [RemotePatchSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).patches
    }

    static func fetchContainers() async throws -> [RemoteContainerSummary] {
        let url = baseURL.appendingPathComponent(pathContainers)
        let (data, response) = try await URLSession.shared.data(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let containers: [RemoteContainerSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).containers
    }

    static func downloadPatch(_ summary: RemotePatchSummary) async throws -> URL {
        let url = baseURL.appendingPathComponent("\(pathPatches)/\(summary.id)/download")
        let (tempURL, response) = try await URLSession.shared.download(for: get(url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.invalidResponse
        }
        guard try digest(of: tempURL) == summary.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.checksumMismatch
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("3105")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()).map { String(format: "%02x", $0) }.joined()
    }
}
