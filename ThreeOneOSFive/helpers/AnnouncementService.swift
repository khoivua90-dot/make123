import Foundation

struct Announcement: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let linkLabel: String
    let linkURL: String
}

private struct AnnouncementResponse: Decodable {
    let enabled: Bool
    let id: String?
    let title: String?
    let message: String?
    let linkLabel: String?
    let linkURL: String?
}

/// Backs the bottom-sheet popup admins can push from the web "Thông báo" panel. `nil` means
/// either announcements are off or the fetch failed — both are treated the same: say nothing.
enum AnnouncementService {
    static func fetch() async -> Announcement? {
        let url = PatchHubService.baseURL.appendingPathComponent("api/announcement")
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AnnouncementResponse.self, from: data),
              decoded.enabled, let id = decoded.id
        else {
            return nil
        }
        return Announcement(
            id: id,
            title: decoded.title ?? "",
            message: decoded.message ?? "",
            linkLabel: decoded.linkLabel ?? "",
            linkURL: decoded.linkURL ?? ""
        )
    }
}
