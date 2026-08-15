import Foundation

struct LicenseRedeemResult {
    let redeemedAt: Date
    let durationDays: Int
    let expiresAt: Date
}

enum LicenseKeyError: Error {
    case notFound
    case revoked
    case expired
    case deviceMismatch
    case deviceLimitReached
    case network

    var localizationKey: String {
        switch self {
        case .notFound: return "license.error.not_found"
        case .revoked: return "license.error.revoked"
        case .expired: return "license.error.expired"
        case .deviceMismatch: return "license.error.device_mismatch"
        case .deviceLimitReached: return "license.error.device_limit_reached"
        case .network: return "license.error.network"
        }
    }
}

/// Talks to the same Patch Hub server as PatchHubService, at /api/keys/*. Kept as a separate
/// type since it has its own response shape and error mapping, not because it's a different
/// backend.
enum LicenseKeyService {
    private static let baseURL = PatchHubService.baseURL

    private struct KeyResponse: Decodable {
        let ok: Bool
        let error: String?
        let redeemedAt: String?
        let durationDays: Int?
        let expiresAt: String?
    }

    private static let dateFormatterWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return dateFormatterWithFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private static func mapError(_ code: String?) -> LicenseKeyError {
        switch code {
        case "not_found": return .notFound
        case "revoked": return .revoked
        case "expired": return .expired
        case "device_mismatch": return .deviceMismatch
        case "device_limit_reached": return .deviceLimitReached
        default: return .network
        }
    }

    private static func result(from response: KeyResponse, statusCode: Int) throws -> LicenseRedeemResult {
        guard statusCode == 200, response.ok,
              let redeemedAt = parseDate(response.redeemedAt),
              let expiresAt = parseDate(response.expiresAt),
              let durationDays = response.durationDays
        else {
            throw mapError(response.error)
        }
        return LicenseRedeemResult(redeemedAt: redeemedAt, durationDays: durationDays, expiresAt: expiresAt)
    }

    private static func formBody(_ params: [String: String]) -> Data {
        params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    static func redeem(code: String, deviceId: String, deviceModel: String) async throws -> LicenseRedeemResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/keys/redeem"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(["code": code, "deviceId": deviceId, "deviceModel": deviceModel])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LicenseKeyError.network
        }
        guard let http = response as? HTTPURLResponse, let decoded = try? JSONDecoder().decode(KeyResponse.self, from: data) else {
            throw LicenseKeyError.network
        }
        return try result(from: decoded, statusCode: http.statusCode)
    }

    static func status(code: String, deviceId: String) async throws -> LicenseRedeemResult {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/keys/status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "deviceId", value: deviceId)
        ]
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: components.url!)
        } catch {
            throw LicenseKeyError.network
        }
        guard let http = response as? HTTPURLResponse, let decoded = try? JSONDecoder().decode(KeyResponse.self, from: data) else {
            throw LicenseKeyError.network
        }
        return try result(from: decoded, statusCode: http.statusCode)
    }
}
