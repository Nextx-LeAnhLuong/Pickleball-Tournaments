# PICKLEBALL APP — API OVERVIEW

## Tổng Quan API

| Thông tin | Chi tiết |
|-----------|----------|
| **Base URL** | `https://api.pickleball-app.com/api` |
| **Phiên bản** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Xác thực** | Bearer Token (JWT) |
| **Công nghệ** | .NET 8 Web API |

---

## Danh Sách Modules

| # | Module | File | Endpoints | Phase | Mô tả |
|---|--------|------|:---------:|:-----:|-------|
| 01 | [Authentication](./01_Authentication_API_Contracts.md) | `01_Authentication_API_Contracts.md` | 5 | 1 | Đăng ký, đăng nhập, OAuth2, refresh token, đổi mật khẩu |
| 02 | [User & Profile](./02_User_Profile_API_Contracts.md) | `02_User_Profile_API_Contracts.md` | 10 | 1 | Profile cá nhân, upload avatar, follow system, xem profile người khác |
| 03 | [Tournament Management](./03_Tournament_Management_API_Contracts.md) | `03_Tournament_Management_API_Contracts.md` | 7 | 1 | Tạo/sửa/hủy giải, chuyển trạng thái, quản lý đội & bảng đấu |
| 04 | [Participant Management](./04_Participant_Management_API_Contracts.md) | `04_Participant_Management_API_Contracts.md` | 7 | 1 | Mời, xin tham gia, duyệt, danh sách, rời/xóa, ghép đội, xếp bảng |
| 05 | [Match & Scoring](./05_Match_Scoring_API_Contracts.md) | `05_Match_Scoring_API_Contracts.md` | 6 | 1 | Lịch thi đấu, nhập/sửa điểm, BXH, kết quả tổng |
| 06 | [Community Game](./06_Community_Game_API_Contracts.md) | `06_Community_Game_API_Contracts.md` | 8 | 2 | Tạo/sửa/xóa game giao hữu, lobby, tham gia, mời |
| 07 | [Chat & Notification](./07_Chat_Notification_API_Contracts.md) | `07_Chat_Notification_API_Contracts.md` | 7 | 1-2 | Chat 1-1, group chat, thông báo in-app, push |

**Tổng cộng: 50 endpoints**

---

## Common Headers

| Header | Giá trị | Bắt buộc | Mô tả |
|--------|---------|:--------:|-------|
| `Authorization` | `Bearer {accessToken}` | Có (Auth) | JWT access token |
| `Content-Type` | `application/json` | Có | Định dạng body |
| `Accept` | `application/json` | Không | Định dạng response |
| `Accept-Language` | `vi` / `en` | Không | Ngôn ngữ (default: vi) |

---

## Common Response Format

### Thành công — Đối tượng đơn
```json
{
  "data": { ... }
}
```

### Thành công — Danh sách phân trang
```json
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 45,
    "totalPages": 3
  }
}
```

### Lỗi — RFC 7807 Problem Details
```json
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Validation Error",
  "status": 400,
  "detail": "Một hoặc nhiều lỗi validation xảy ra",
  "errors": {
    "FieldName": ["Thông báo lỗi"]
  }
}
```

---

## Common Query Params (Phân trang)

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| `page` | int | 1 | Trang hiện tại |
| `pageSize` | int | 20 | Số item/trang (max 100) |
| `sortBy` | string | `createdAt` | Trường sắp xếp |
| `sortOrder` | string | `desc` | `asc` / `desc` |

---

## Enum Reference

| Enum | Values |
|------|--------|
| TournamentType | `singles`, `doubles` |
| TournamentStatus | `draft`, `open`, `ready`, `in_progress`, `completed`, `cancelled` |
| ScoringFormat | `best_of_1`, `best_of_3` |
| ParticipantStatus | `confirmed`, `invited_pending`, `request_pending`, `rejected` |
| MatchStatus | `scheduled`, `in_progress`, `completed`, `walkover` |
| GameStatus | `open`, `full`, `in_progress`, `completed`, `cancelled` |
| GameParticipantStatus | `confirmed`, `waitlist`, `invited_pending`, `cancelled` |
| ChatRoomType | `direct`, `group` |
| MessageType | `text`, `image`, `system` |
| NotificationType | `tournament_invite`, `request_approved`, `request_rejected`, `tournament_started`, `match_scheduled`, `match_result`, `tournament_completed`, `tournament_cancelled`, `game_invite`, `new_message`, `new_follower` |

---

## HTTP Status Codes

| Code | Ý nghĩa | Khi nào |
|------|---------|---------|
| 200 | OK | Thành công (GET, PUT) |
| 201 | Created | Tạo mới thành công (POST) |
| 204 | No Content | Thành công, không có body (DELETE) |
| 400 | Bad Request | Input validation lỗi |
| 401 | Unauthorized | Chưa đăng nhập / token hết hạn |
| 403 | Forbidden | Không có quyền |
| 404 | Not Found | Resource không tồn tại |
| 409 | Conflict | Trùng lặp (đã follow, đã request) |
| 422 | Unprocessable Entity | Vi phạm quy tắc nghiệp vụ |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Lỗi hệ thống |

---

## Tổng Hợp Endpoints

### Module 01: Authentication (5 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 1.1 | POST | `/auth/register` | ❌ | Đăng ký tài khoản |
| 1.2 | POST | `/auth/login` | ❌ | Đăng nhập |
| 1.3 | POST | `/auth/social` | ❌ | Đăng nhập qua Google/Apple |
| 1.4 | POST | `/auth/refresh` | ❌ | Làm mới access token |
| 1.5 | PUT | `/auth/password` | ✅ | Đổi mật khẩu |

### Module 02: User & Profile (10 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 2.1 | GET | `/users/me` | ✅ | Xem profile cá nhân |
| 2.2 | PUT | `/users/me` | ✅ | Cập nhật profile |
| 2.3 | POST | `/users/me/avatar` | ✅ | Upload ảnh đại diện |
| 2.4 | GET | `/users/me/tournaments` | ✅ | Lịch sử giải đấu |
| 2.5 | GET | `/users/me/following` | ✅ | DS đang theo dõi |
| 2.6 | GET | `/users/me/followers` | ✅ | DS người theo dõi |
| 2.7 | POST | `/users/:id/follow` | ✅ | Theo dõi |
| 2.8 | DELETE | `/users/:id/follow` | ✅ | Bỏ theo dõi |
| 2.9 | GET | `/users/:id/profile` | ✅ | Xem profile người khác |
| 2.10 | GET | `/users/:id/matches` | ✅ | Lịch sử trận đấu người khác |

### Module 03: Tournament Management (7 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 3.1 | GET | `/tournaments` | ✅ | Danh sách giải đấu |
| 3.2 | POST | `/tournaments` | ✅ | Tạo giải đấu |
| 3.3 | GET | `/tournaments/:id` | ✅ | Chi tiết giải đấu |
| 3.4 | PUT | `/tournaments/:id` | Creator | Cập nhật giải đấu |
| 3.5 | DELETE | `/tournaments/:id` | Creator | Hủy giải đấu |
| 3.6 | PUT | `/tournaments/:id/status` | Creator | Chuyển trạng thái |
| 3.7 | POST | `/tournaments/:id/banner` | Creator | Upload ảnh bìa |

### Module 04: Participant Management (7 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 4.1 | POST | `/tournaments/:id/invite` | Creator | Mời người chơi |
| 4.2 | POST | `/tournaments/:id/request` | ✅ | Xin tham gia |
| 4.3 | PUT | `/tournaments/:id/requests/:rid` | Creator | Duyệt/từ chối |
| 4.4 | GET | `/tournaments/:id/participants` | ✅ | Danh sách người tham gia |
| 4.5 | DELETE | `/tournaments/:id/participants/:uid` | ✅/Creator | Rời/xóa người chơi |
| 4.6 | POST | `/tournaments/:id/teams` | Creator | Ghép đội (doubles) |
| 4.7 | POST | `/tournaments/:id/groups` | Creator | Xếp bảng |

### Module 05: Match & Scoring (6 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 5.1 | GET | `/tournaments/:id/matches` | ✅ | Lịch thi đấu |
| 5.2 | GET | `/tournaments/:id/draw` | ✅ | Bracket data |
| 5.3 | POST | `/matches/:id/score` | Creator | Nhập điểm |
| 5.4 | PUT | `/matches/:id/score` | Creator | Sửa điểm |
| 5.5 | GET | `/tournaments/:id/groups/:gid/standings` | ✅ | BXH bảng |
| 5.6 | GET | `/tournaments/:id/results` | ✅ | Kết quả tổng |

### Module 06: Community Game (8 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 6.1 | GET | `/community/lobby` | ✅ | Danh sách game |
| 6.2 | POST | `/community/games` | ✅ | Tạo game |
| 6.3 | GET | `/community/games/:id` | ✅ | Chi tiết game |
| 6.4 | PUT | `/community/games/:id` | GameCreator | Sửa game |
| 6.5 | DELETE | `/community/games/:id` | GameCreator | Xóa game |
| 6.6 | POST | `/community/games/:id/invite` | GameCreator | Mời người chơi |
| 6.7 | POST | `/community/games/:id/join` | ✅ | Tham gia game |
| 6.8 | DELETE | `/community/games/:id/leave` | ✅ | Rời game |

### Module 07: Chat & Notification (7 endpoints)

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 7.1 | GET | `/chats` | ✅ | Danh sách phòng chat |
| 7.2 | POST | `/chats` | ✅ | Tạo phòng chat |
| 7.3 | GET | `/chats/:id/messages` | Member | Xem tin nhắn |
| 7.4 | POST | `/chats/:id/messages` | Member | Gửi tin nhắn |
| 7.5 | GET | `/notifications` | ✅ | Danh sách thông báo |
| 7.6 | PUT | `/notifications/:id/read` | ✅ | Đánh dấu đã đọc |
| 7.7 | PUT | `/notifications/read-all` | ✅ | Đọc tất cả |
