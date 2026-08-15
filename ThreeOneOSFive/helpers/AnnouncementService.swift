import Foundation

struct Announcement: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let linkLabel: String
    let linkURL: String
}

struct MaintenanceNotice: Equatable {
    let title: String
    let message: String
}

enum RemoteNoticeState: Equatable {
    case none
    /// Takes priority over everything else in the app, including the license gate — the whole
    /// point is a hard, un-dismissable block while the server side is down or being worked on.
    case maintenance(MaintenanceNotice)
    case announcement(Announcement)
}

private struct AnnouncementResponse: Decodable {
    let enabled: Bool
    let maintenance: Bool?
    let id: String?
    let title: String?
    let message: String?
    let linkLabel: String?
    let linkURL: String?
    let maintenanceTitle: String?
    let maintenanceMessage: String?
}

/// Backs both the dismissable "Thông báo" popup and the "Bảo trì" kill switch admins can flip
/// from the same web panel — a single endpoint, since the app needs to check both together on
/// every launch/foreground anyway.
enum AnnouncementService {
    static func fetchState() async -> RemoteNoticeState {
        let url = PatchHubService.baseURL.appendingPathComponent("api/announcement")
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AnnouncementResponse.self, from: data)
        else {
            return .none
        }

        if decoded.maintenance == true {
            return .maintenance(
                MaintenanceNotice(title: decoded.maintenanceTitle ?? "", message: decoded.maintenanceMessage ?? "")
            )
        }
        guard decoded.enabled, let id = decoded.id else { return .none }
        return .announcement(
            Announcement(
                id: id,
                title: decoded.title ?? "",
                message: decoded.message ?? "",
                linkLabel: decoded.linkLabel ?? "",
                linkURL: decoded.linkURL ?? ""
            )
        )
    }
}
