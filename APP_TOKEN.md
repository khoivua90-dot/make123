# X-App-Token — Token bí mật API

## Token hiện tại

```
ciosvip_9Rx4kZ2mQ7wN3pL8_DJTMEMAYTHANGLONCRACKFANGNHEANCUCACTAONE
```

## Nơi khai báo

| Vị trí | File / Dòng |
|--------|-------------|
| Server (VPS) | `/opt/patch-hub/server.js` — `const CLIENT_TOKEN = '...'` |
| App iOS | `ThreeOneOSFive/helpers/PatchHubService.swift` — `static let clientToken = "..."` |

## Cách hoạt động

- Mọi request đến `/api/*` phải có header `X-App-Token: <token>`
- Không có token hoặc sai → server trả `404` (trông như endpoint không tồn tại)
- App iOS tự động gắn header này vào tất cả request

## Khi cần đổi token

1. Sửa `CLIENT_TOKEN` trong `/opt/patch-hub/server.js` trên VPS → restart PM2
2. Sửa `clientToken` trong `PatchHubService.swift`
3. Build và phát hành IPA mới
4. Cập nhật file này

## Lịch sử

| Ngày | Token cũ | Lý do đổi |
|------|----------|-----------|
| 2026-08-15 | `ciosvip_9Rx4kZ2mQ7wN3pL8` | Token khởi tạo |
| 2026-08-17 | `ciosvip_9Rx4kZ2mQ7wN3pL8_DJTMEMAYTHANGLONCRACKFANGNHEANCUCACTAONE` | Đổi theo yêu cầu |
