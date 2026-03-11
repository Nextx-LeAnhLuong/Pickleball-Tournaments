# Module 02: User & Profile — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | User & Profile |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 1 (profile), 2 (follow) |
| **Số endpoints** | 10 |
| **DB Tables** | Users, Follows, Tournaments, Participants, Matches |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 2.1 | GET | `/users/me` | ✅ | Xem profile cá nhân + thống kê |
| 2.2 | PUT | `/users/me` | ✅ | Cập nhật thông tin profile |
| 2.3 | POST | `/users/me/avatar` | ✅ | Upload ảnh đại diện |
| 2.4 | GET | `/users/me/tournaments` | ✅ | Lịch sử giải đấu của tôi |
| 2.5 | GET | `/users/me/following` | ✅ | Danh sách tôi đang theo dõi |
| 2.6 | GET | `/users/me/followers` | ✅ | Danh sách người theo dõi tôi |
| 2.7 | POST | `/users/:id/follow` | ✅ | Theo dõi người chơi khác |
| 2.8 | DELETE | `/users/:id/follow` | ✅ | Bỏ theo dõi |
| 2.9 | GET | `/users/:id/profile` | ✅ | Xem profile người khác |
| 2.10 | GET | `/users/:id/matches` | ✅ | Lịch sử trận đấu người khác |

---

## 2.1. GET /users/me — Xem profile cá nhân

### Summary
Trả về toàn bộ thông tin profile và thống kê thi đấu của người dùng đang đăng nhập.

### User Story
```
Là một người chơi đã đăng nhập,
Tôi muốn xem profile cá nhân của mình,
Để biết thống kê thi đấu, tỷ lệ thắng, số giải đã tham gia.

Acceptance Criteria:
- Hiển thị thông tin cá nhân: tên, avatar, bio, skill level
- Hiển thị thống kê: tổng giải, tổng trận, thắng/thua, tỷ lệ thắng
- Hiển thị số following/followers
```

### Auth & Role

| Yêu cầu | Giá trị |
|---------|---------|
| Authentication | ✅ Bearer Token |
| Authorization | Chỉ xem được profile của chính mình |

### Request

**Headers:**
```
Authorization: Bearer {accessToken}
```

Không có query params.

### Response

**200 OK:**
```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "player@example.com",
    "name": "Nguyễn Văn A",
    "avatarUrl": "https://s3.../avatar.webp",
    "bio": "Pickleball lover since 2024",
    "skillLevel": 3.5,
    "dominantHand": "right",
    "paddleType": "Joola Hyperion CFS 16",
    "provider": "local",
    "stats": {
      "totalTournaments": 12,
      "totalMatches": 48,
      "wins": 30,
      "losses": 18,
      "winRate": 62.5,
      "followingCount": 25,
      "followersCount": 42
    },
    "createdAt": "2026-01-15T08:30:00Z"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập / token hết hạn |

### Business Rules

1. `stats` được tính từ bảng Participants + Matches (aggregate query hoặc cache Redis)
2. `winRate` = (wins / totalMatches) * 100, làm tròn 1 chữ số thập phân
3. Cache profile 30 phút trong Redis, invalidate khi update

---

## 2.2. PUT /users/me — Cập nhật profile

### Summary
Cập nhật thông tin cá nhân (partial update — chỉ gửi fields cần sửa).

### User Story
```
Là một người chơi,
Tôi muốn cập nhật thông tin cá nhân (tên, bio, skill level, tay thuận, vợt),
Để hồ sơ của tôi phản ánh đúng trình độ và phong cách chơi.

Acceptance Criteria:
- Tôi có thể sửa tên, bio, skill level, tay thuận, loại vợt
- Không được sửa email (phải dùng flow riêng)
- Chỉ gửi fields cần sửa, fields không gửi giữ nguyên
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  PUT /users/me                │                               │
  │  {name, skillLevel}           │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate input               │
  │                               │  (name length, skill range)   │
  │                               │                               │
  │                               │  Update user record           │
  │                               │  (chỉ fields được gửi)       │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Invalidate Redis cache       │
  │                               │  key: user:{id}:profile       │
  │                               │                               │
  │  200 {updated profile}        │                               │
  │<──────────────────────────────│                               │
```

### Request

**Body:**
```json
{
  "name": "Nguyễn Văn A",
  "bio": "Pickleball lover since 2024",
  "skillLevel": 3.5,
  "dominantHand": "right",
  "paddleType": "Joola Hyperion CFS 16"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| name | string | ❌ | 2-100 ký tự |
| bio | string | ❌ | Max 500 ký tự |
| skillLevel | decimal | ❌ | 1.0 - 5.0, bước 0.5 (1.0, 1.5, 2.0, ..., 5.0) |
| dominantHand | string | ❌ | `"left"` / `"right"` |
| paddleType | string | ❌ | Max 100 ký tự |

### Response

**200 OK:** Trả về profile đã cập nhật (format giống 2.1)

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 400 | VALIDATION_ERROR | skillLevel ngoài khoảng, name quá ngắn/dài |
| 401 | UNAUTHORIZED | Chưa đăng nhập |

---

## 2.3. POST /users/me/avatar — Upload ảnh đại diện

### Summary
Upload ảnh đại diện mới. Server tự resize (256x256) và convert sang WebP.

### User Story
```
Là một người chơi,
Tôi muốn tải lên ảnh đại diện,
Để người chơi khác dễ nhận diện tôi.

Acceptance Criteria:
- Hỗ trợ JPEG, PNG, WebP
- Tối đa 5 MB
- Server tự resize xuống 256x256 và chuyển sang WebP
- Ảnh cũ trên S3 bị xóa
```

### Luồng xử lý

```
Client                   Server                    S3/MinIO
  │                        │                          │
  │  POST /users/me/avatar │                          │
  │  Content-Type:         │                          │
  │    multipart/form-data │                          │
  │  file: image.jpg       │                          │
  │───────────────────────>│                          │
  │                        │  Validate:               │
  │                        │  - MIME type              │
  │                        │  - File size <= 5MB       │
  │                        │                          │
  │                        │  Resize 256x256          │
  │                        │  Convert to WebP         │
  │                        │  Quality: 80%            │
  │                        │                          │
  │                        │  Upload to S3            │
  │                        │─────────────────────────>│
  │                        │  → newUrl                │
  │                        │<─────────────────────────│
  │                        │                          │
  │                        │  Delete old avatar       │
  │                        │─────────────────────────>│
  │                        │                          │
  │                        │  Update user.AvatarUrl   │
  │                        │                          │
  │  200 {avatarUrl}       │                          │
  │<───────────────────────│                          │
```

### Request

**Headers:**
```
Authorization: Bearer {accessToken}
Content-Type: multipart/form-data
```

**Form Data:**

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| file | File | ✅ | MIME: image/jpeg, image/png, image/webp. Max 5 MB. |

### Response

**200 OK:**
```json
{
  "data": {
    "avatarUrl": "https://s3.../avatars/550e8400-2026-03-12.webp"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 400 | INVALID_FILE_TYPE | Không phải ảnh (JPEG/PNG/WebP) |
| 400 | FILE_TOO_LARGE | Quá 5 MB |
| 401 | UNAUTHORIZED | Chưa đăng nhập |

---

## 2.4. GET /users/me/tournaments — Lịch sử giải đấu

### Summary
Danh sách giải đấu tôi đã tạo hoặc tham gia, kèm kết quả.

### User Story
```
Là một người chơi,
Tôi muốn xem lại lịch sử các giải đấu tôi đã tham gia,
Để theo dõi tiến bộ và xem lại kết quả.

Acceptance Criteria:
- Lọc theo: đã tạo / đã tham gia / tất cả
- Lọc theo trạng thái: đang diễn ra / đã kết thúc
- Mỗi giải hiển thị: tên, loại, ngày, kết quả (xếp hạng)
- Phân trang
```

### Request

**Query Params:**

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| role | string | null | `"created"` / `"joined"` / null (tất cả) |
| status | string | null | `"open"` / `"in_progress"` / `"completed"` |
| page | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "tournament-uuid",
      "name": "Giải Mùa Xuân 2026",
      "type": "singles",
      "status": "completed",
      "date": "2026-02-15",
      "location": "Sân ABC, Quận 7",
      "role": "player",
      "result": {
        "groupName": "A",
        "rank": 1,
        "wins": 3,
        "losses": 0,
        "isChampion": true
      }
    },
    {
      "id": "tournament-uuid-2",
      "name": "Giải Cộng Đồng Q1",
      "type": "doubles",
      "status": "in_progress",
      "date": "2026-03-20",
      "location": "Sân XYZ",
      "role": "creator",
      "result": null
    }
  ],
  "meta": { "page": 1, "pageSize": 20, "totalCount": 12, "totalPages": 1 }
}
```

### Business Rules

1. `result` = null nếu giải chưa kết thúc hoặc chưa xếp bảng
2. `role` = `"creator"` nếu user tạo giải, `"player"` nếu chỉ tham gia
3. `isChampion` = true nếu xếp hạng 1 trong bảng
4. Sắp xếp mặc định: giải đang diễn ra lên đầu, sau đó theo ngày giảm dần

---

## 2.5. GET /users/me/following — Danh sách đang theo dõi

### User Story
```
Là một người chơi,
Tôi muốn xem danh sách người tôi đang theo dõi,
Để quản lý và dễ tìm lại họ khi muốn mời chơi.
```

### Request

**Query Params:** `page`, `pageSize`, `search` (tìm theo tên)

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "user-uuid",
      "name": "Trần Văn B",
      "avatarUrl": "...",
      "skillLevel": 4.0,
      "isMutual": true,
      "followedAt": "2026-02-10T09:00:00Z"
    }
  ],
  "meta": { "page": 1, "pageSize": 20, "totalCount": 25, "totalPages": 2 }
}
```

### Business Rules

1. `isMutual: true` khi cả 2 follow nhau
2. Sắp xếp mặc định theo `followedAt` giảm dần

---

## 2.6. GET /users/me/followers — Danh sách người theo dõi

Response format giống 2.5. Thêm field `isFollowingBack: boolean` (tôi có follow lại họ không).

---

## 2.7. POST /users/:id/follow — Theo dõi

### Summary
Theo dõi một người chơi khác.

### User Story
```
Là một người chơi,
Tôi muốn theo dõi người chơi khác,
Để nhận thông báo về hoạt động của họ và dễ mời khi tạo game.
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  POST /users/{targetId}/follow│                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  - targetId != currentUserId  │
  │                               │  - target user exists         │
  │                               │  - not already following      │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  ✅ Create Follow record       │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Send notification            │
  │                               │  to target user               │
  │                               │  (type: new_follower)         │
  │                               │                               │
  │  204 No Content               │                               │
  │<──────────────────────────────│                               │
```

### Request

Không có body.

### Response

**204 No Content**

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 400 | CANNOT_FOLLOW_SELF | Không thể follow chính mình |
| 404 | USER_NOT_FOUND | User không tồn tại |
| 409 | ALREADY_FOLLOWING | Đã follow rồi |

### Business Rules

1. Gửi notification `new_follower` cho target user
2. Frontend nên dùng optimistic UI (hiện "Đang theo dõi" ngay, rollback nếu lỗi)

---

## 2.8. DELETE /users/:id/follow — Bỏ theo dõi

### Response

**204 No Content**

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 404 | NOT_FOLLOWING | Chưa follow user này |

### Business Rules

1. Không gửi notification khi bỏ follow
2. Xóa record từ bảng Follows

---

## 2.9. GET /users/:id/profile — Xem profile người khác

### Summary
Xem thông tin công khai của người chơi khác, bao gồm thống kê và thành tích đối đầu.

### User Story
```
Là một người chơi,
Tôi muốn xem profile của đối thủ hoặc bạn chơi,
Để biết trình độ, thống kê thi đấu, và thành tích đối đầu giữa 2 người.

Acceptance Criteria:
- Thấy thông tin công khai: tên, avatar, bio, skill level, thống kê
- Thấy trạng thái follow (tôi follow họ chưa, họ follow tôi chưa)
- Thấy thành tích đối đầu (head-to-head) nếu đã từng đấu nhau
```

### Response

**200 OK:**
```json
{
  "data": {
    "id": "target-user-uuid",
    "name": "Trần Văn B",
    "avatarUrl": "...",
    "bio": "...",
    "skillLevel": 4.0,
    "dominantHand": "right",
    "paddleType": "Selkirk VANGUARD 2.0",
    "stats": {
      "totalTournaments": 20,
      "totalMatches": 80,
      "wins": 55,
      "losses": 25,
      "winRate": 68.75,
      "followingCount": 30,
      "followersCount": 120
    },
    "isFollowing": true,
    "isFollowedBy": false,
    "headToHead": {
      "totalMatches": 3,
      "myWins": 2,
      "theirWins": 1,
      "lastPlayed": "2026-02-15"
    }
  }
}
```

### Business Rules

1. `headToHead` = null nếu chưa từng đấu nhau
2. Không hiển thị email (privacy)
3. Không hiển thị `provider` (internal info)

---

## 2.10. GET /users/:id/matches — Lịch sử trận đấu

### Summary
Xem lịch sử trận đấu của người chơi khác (chỉ trận public trong giải đấu).

### Request

**Query Params:** `page`, `pageSize`

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "match-uuid",
      "tournamentName": "Giải Mùa Xuân 2026",
      "tournamentId": "tournament-uuid",
      "date": "2026-02-15",
      "opponent": {
        "id": "opponent-uuid",
        "name": "Lê Văn C",
        "avatarUrl": "..."
      },
      "scores": {
        "player": [11, 9, 11],
        "opponent": [7, 11, 8]
      },
      "result": "win",
      "groupName": "A",
      "round": 2
    }
  ],
  "meta": { ... }
}
```

### Business Rules

1. Chỉ hiển thị trận đã hoàn thành (`status = completed`)
2. `result` = `"win"` / `"loss"` / `"walkover_win"` / `"walkover_loss"`
3. Sắp xếp theo ngày giảm dần
