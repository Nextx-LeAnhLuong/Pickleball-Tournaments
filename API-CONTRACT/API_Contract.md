# PICKLEBALL APP — API CONTRACT
## Tài Liệu Giao Diện Lập Trình Ứng Dụng (API)

**Phiên bản:** 1.0
**Ngày:** Tháng 3, 2026
**Base URL:** `https://api.pickleball-app.com/api`
**Xác thực:** Bearer Token (JWT)

---

## MỤC LỤC

1. [Quy ước chung](#1-quy-ước-chung)
2. [Auth APIs](#2-auth-apis)
3. [User APIs](#3-user-apis)
4. [Tournament APIs](#4-tournament-apis)
5. [Participant APIs](#5-participant-apis)
6. [Team APIs (Doubles)](#6-team-apis)
7. [Group APIs](#7-group-apis)
8. [Match & Scoring APIs](#8-match--scoring-apis)
9. [Community Game APIs](#9-community-game-apis)
10. [Chat APIs](#10-chat-apis)
11. [Notification APIs](#11-notification-apis)
12. [Error Codes](#12-error-codes)

---

## 1. Quy Ước Chung

### 1.1. Headers

```
Authorization: Bearer <access_token>     (bắt buộc cho các API Auth)
Content-Type: application/json
Accept: application/json
```

### 1.2. Response Format — Thành công

```json
// Trả về 1 object
{
  "data": { ... }
}

// Trả về danh sách có phân trang
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 45,
    "totalPages": 3
  }
}

// Không có body (204 No Content)
```

### 1.3. Response Format — Lỗi (RFC 7807)

```json
{
  "type": "https://tools.ietf.org/html/rfc7807",
  "title": "Validation Error",
  "status": 400,
  "detail": "Một hoặc nhiều lỗi validation xảy ra",
  "errors": {
    "Name": ["Tên giải đấu không được để trống"],
    "NumGroups": ["Đấu đơn: 1-4 bảng"]
  }
}
```

### 1.4. Phân trang

Query params chung cho danh sách:

| Param | Type | Default | Mô tả |
|-------|------|---------|--------|
| `page` | int | 1 | Trang hiện tại |
| `pageSize` | int | 20 | Số item / trang (max 100) |
| `sortBy` | string | `createdAt` | Trường sắp xếp |
| `sortOrder` | string | `desc` | `asc` hoặc `desc` |

### 1.5. Enum Values Reference

```
TournamentType:    "singles" | "doubles"
TournamentStatus:  "draft" | "open" | "ready" | "in_progress" | "completed" | "cancelled"
ScoringFormat:     "best_of_1" | "best_of_3"
ParticipantStatus: "confirmed" | "invited_pending" | "request_pending" | "rejected"
MatchStatus:       "scheduled" | "in_progress" | "completed" | "walkover"
```

---

## 2. Auth APIs

### 2.1. POST /auth/register — Đăng ký tài khoản

**Quyền:** Public

**Request Body:**
```json
{
  "email": "player@example.com",
  "password": "SecureP@ss123",
  "name": "Nguyễn Văn A",
  "avatarUrl": null
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| email | string | ✅ | Email hợp lệ, unique |
| password | string | ✅ | Tối thiểu 8 ký tự, có chữ hoa, số, ký tự đặc biệt |
| name | string | ✅ | 2-100 ký tự |
| avatarUrl | string | ❌ | URL hợp lệ |

**Response: 201 Created**
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1...",
    "refreshToken": "dGhpcyBpcyBhIHJl...",
    "expiresIn": 900,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "player@example.com",
      "name": "Nguyễn Văn A",
      "avatarUrl": null,
      "skillLevel": 3.0
    }
  }
}
```

**Errors:**
- `400` — Validation lỗi (email đã tồn tại, password yếu)

---

### 2.2. POST /auth/login — Đăng nhập

**Quyền:** Public | **Rate Limit:** 5 req / 15 phút / IP

**Request Body:**
```json
{
  "email": "player@example.com",
  "password": "SecureP@ss123"
}
```

**Response: 200 OK**
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1...",
    "refreshToken": "dGhpcyBpcyBhIHJl...",
    "expiresIn": 900,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "player@example.com",
      "name": "Nguyễn Văn A",
      "avatarUrl": "https://s3.../avatar.webp",
      "skillLevel": 3.5
    }
  }
}
```

**Errors:**
- `401` — Email hoặc mật khẩu không đúng
- `429` — Quá nhiều lần đăng nhập thất bại

---

### 2.3. POST /auth/refresh — Làm mới Access Token

**Quyền:** Public

**Request Body:**
```json
{
  "refreshToken": "dGhpcyBpcyBhIHJl..."
}
```

**Response: 200 OK**
```json
{
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1...",
    "refreshToken": "bmV3IHJlZnJlc2g...",
    "expiresIn": 900
  }
}
```

**Errors:**
- `401` — Refresh token không hợp lệ hoặc đã hết hạn

---

### 2.4. POST /auth/social — Đăng nhập bằng mạng xã hội

**Quyền:** Public

**Request Body:**
```json
{
  "provider": "google",
  "idToken": "eyJhbGciOiJSUzI1..."
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| provider | string | ✅ | `"google"` hoặc `"apple"` |
| idToken | string | ✅ | Token từ OAuth2 provider |

**Response: 200 OK** — Giống response login

---

### 2.5. PUT /auth/password — Đổi mật khẩu

**Quyền:** Auth

**Request Body:**
```json
{
  "currentPassword": "OldP@ss123",
  "newPassword": "NewSecureP@ss456"
}
```

**Response: 204 No Content**

**Errors:**
- `400` — Mật khẩu cũ không đúng / mật khẩu mới không đạt yêu cầu

---

## 3. User APIs

### 3.1. GET /users/me — Xem profile cá nhân

**Quyền:** Auth

**Response: 200 OK**
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

---

### 3.2. PUT /users/me — Cập nhật profile

**Quyền:** Auth

**Request Body:**
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
|-------|------|----------|------------|
| name | string | ❌ | 2-100 ký tự |
| bio | string | ❌ | Max 500 ký tự |
| skillLevel | decimal | ❌ | 1.0 - 5.0, bước 0.5 |
| dominantHand | string | ❌ | `"left"` hoặc `"right"` |
| paddleType | string | ❌ | Max 100 ký tự |

**Response: 200 OK** — Trả về profile đã cập nhật

---

### 3.3. POST /users/me/avatar — Upload ảnh đại diện

**Quyền:** Auth | **Content-Type:** `multipart/form-data`

**Request:** Form data với field `file` (image/jpeg, image/png, image/webp, max 5MB)

**Response: 200 OK**
```json
{
  "data": {
    "avatarUrl": "https://s3.../avatar-550e8400.webp"
  }
}
```

---

### 3.4. GET /users/me/tournaments — Lịch sử giải đấu

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| role | string | `"created"` / `"joined"` / `null` (tất cả) |
| status | string | Filter theo trạng thái giải |
| page, pageSize | int | Phân trang |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "...",
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
        "losses": 0
      }
    }
  ],
  "meta": { "page": 1, "pageSize": 20, "totalCount": 12, "totalPages": 1 }
}
```

---

### 3.5. GET /users/me/following — Danh sách đang theo dõi

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "...",
      "name": "Trần Văn B",
      "avatarUrl": "...",
      "skillLevel": 4.0,
      "isMutual": true
    }
  ],
  "meta": { ... }
}
```

---

### 3.6. GET /users/me/followers — Danh sách người theo dõi

**Quyền:** Auth — Response giống 3.5

---

### 3.7. POST /users/:id/follow — Theo dõi

**Quyền:** Auth

**Response: 204 No Content**

**Errors:**
- `404` — User không tồn tại
- `409` — Đã follow rồi

---

### 3.8. DELETE /users/:id/follow — Bỏ theo dõi

**Quyền:** Auth

**Response: 204 No Content**

---

### 3.9. GET /users/:id/profile — Xem profile người khác

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": {
    "id": "...",
    "name": "Trần Văn B",
    "avatarUrl": "...",
    "bio": "...",
    "skillLevel": 4.0,
    "dominantHand": "right",
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
      "theirWins": 1
    }
  }
}
```

---

### 3.10. GET /users/:id/matches — Lịch sử trận đấu của người khác

**Quyền:** Auth

**Query Params:** `page`, `pageSize`

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "...",
      "tournamentName": "Giải Mùa Xuân 2026",
      "date": "2026-02-15",
      "opponent": {
        "id": "...",
        "name": "Lê Văn C",
        "avatarUrl": "..."
      },
      "scores": {
        "player": [11, 9, 11],
        "opponent": [7, 11, 8]
      },
      "result": "win"
    }
  ],
  "meta": { ... }
}
```

---

## 4. Tournament APIs

### 4.1. GET /tournaments — Danh sách giải đấu

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| search | string | Tìm theo tên giải |
| type | string | `"singles"` / `"doubles"` |
| status | string | `"open"` / `"in_progress"` / `"completed"` / ... |
| page, pageSize | int | Phân trang |
| sortBy | string | `"date"` / `"createdAt"` / `"name"` |
| sortOrder | string | `"asc"` / `"desc"` |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "a1b2c3d4-...",
      "name": "Giải Mùa Xuân 2026",
      "type": "singles",
      "numGroups": 2,
      "scoringFormat": "best_of_3",
      "status": "open",
      "date": "2026-04-15",
      "location": "Sân XYZ, Quận 1, TP.HCM",
      "bannerUrl": "https://s3.../banner.webp",
      "creator": {
        "id": "...",
        "name": "Nguyễn Văn A",
        "avatarUrl": "..."
      },
      "participantCount": 5,
      "maxParticipants": 8,
      "createdAt": "2026-03-01T10:00:00Z"
    }
  ],
  "meta": { "page": 1, "pageSize": 20, "totalCount": 15, "totalPages": 1 }
}
```

---

### 4.2. POST /tournaments — Tạo giải đấu

**Quyền:** Auth

**Request Body:**
```json
{
  "name": "Giải Mùa Xuân 2026",
  "description": "Giải đấu pickleball đầu năm tại TP.HCM",
  "type": "singles",
  "numGroups": 2,
  "scoringFormat": "best_of_3",
  "date": "2026-04-15",
  "location": "Sân XYZ, Quận 1, TP.HCM",
  "bannerUrl": null
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| name | string | ✅ | 3-200 ký tự |
| description | string | ❌ | Max 2000 ký tự |
| type | string | ✅ | `"singles"` / `"doubles"` |
| numGroups | int | ✅ | Singles: 1-4, Doubles: 1-2 |
| scoringFormat | string | ❌ | `"best_of_1"` / `"best_of_3"` (default) |
| date | string | ❌ | ISO 8601 date, phải trong tương lai |
| location | string | ❌ | Max 500 ký tự |
| bannerUrl | string | ❌ | URL hợp lệ |

**Response: 201 Created**
```json
{
  "data": {
    "id": "a1b2c3d4-...",
    "name": "Giải Mùa Xuân 2026",
    "type": "singles",
    "numGroups": 2,
    "scoringFormat": "best_of_3",
    "status": "draft",
    "date": "2026-04-15",
    "location": "Sân XYZ, Quận 1, TP.HCM",
    "bannerUrl": null,
    "creator": { "id": "...", "name": "...", "avatarUrl": "..." },
    "participantCount": 0,
    "maxParticipants": 8,
    "createdAt": "2026-03-12T14:30:00Z"
  }
}
```

---

### 4.3. GET /tournaments/:id — Chi tiết giải đấu

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": {
    "id": "a1b2c3d4-...",
    "name": "Giải Mùa Xuân 2026",
    "description": "Giải đấu pickleball đầu năm tại TP.HCM",
    "type": "singles",
    "numGroups": 2,
    "scoringFormat": "best_of_3",
    "status": "in_progress",
    "date": "2026-04-15",
    "location": "Sân XYZ, Quận 1, TP.HCM",
    "bannerUrl": "...",
    "creator": { "id": "...", "name": "...", "avatarUrl": "..." },
    "participantCount": 8,
    "maxParticipants": 8,
    "currentUserRole": "creator",
    "currentUserParticipantStatus": null,
    "groups": [
      {
        "id": "...",
        "name": "A",
        "members": [
          { "id": "...", "name": "Nguyễn A", "avatarUrl": "...", "skillLevel": 3.5 },
          { "id": "...", "name": "Trần B", "avatarUrl": "...", "skillLevel": 4.0 },
          { "id": "...", "name": "Lê C", "avatarUrl": "...", "skillLevel": 3.0 },
          { "id": "...", "name": "Phạm D", "avatarUrl": "...", "skillLevel": 3.5 }
        ]
      },
      {
        "id": "...",
        "name": "B",
        "members": [ ... ]
      }
    ],
    "createdAt": "2026-03-01T10:00:00Z",
    "updatedAt": "2026-04-14T08:00:00Z"
  }
}
```

**Lưu ý:**
- `currentUserRole`: `"creator"` / `"player"` / `null` (chưa tham gia)
- `currentUserParticipantStatus`: trạng thái nếu user có đăng ký/được mời
- `groups` chỉ trả về khi status >= `ready`

---

### 4.4. PUT /tournaments/:id — Cập nhật giải đấu

**Quyền:** Creator

**Request Body:** (chỉ gửi fields cần cập nhật)
```json
{
  "name": "Giải Mùa Xuân 2026 — Updated",
  "description": "Mô tả mới",
  "date": "2026-04-20",
  "location": "Sân ABC mới"
}
```

**Lưu ý:**
- Không cho sửa `type` và `numGroups` sau khi đã có >= 1 người tham gia
- Trả về `422` nếu cố sửa field bị khóa

**Response: 200 OK** — Trả về tournament đã cập nhật

---

### 4.5. DELETE /tournaments/:id — Hủy giải đấu

**Quyền:** Creator

**Request Body:**
```json
{
  "reason": "Không đủ người tham gia"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| reason | string | Bắt buộc nếu giải đang `in_progress` | Max 500 ký tự |

**Response: 204 No Content**

**Side effects:** Thông báo cho tất cả participants, chuyển status → `cancelled`

**Errors:**
- `422` — Không thể hủy giải đã `completed`

---

### 4.6. PUT /tournaments/:id/status — Chuyển trạng thái

**Quyền:** Creator

**Request Body:**
```json
{
  "status": "open"
}
```

**Điều kiện chuyển trạng thái:**

| Từ → Đến | Điều kiện |
|-----------|----------|
| `draft` → `open` | Không |
| `open` → `ready` | Đủ số người (numGroups x 4), đã xếp bảng |
| `ready` → `in_progress` | Đã tạo lịch thi đấu |
| `in_progress` → `completed` | Tự động khi tất cả trận hoàn thành |

**Response: 204 No Content**

**Errors:**
- `422` — Không đáp ứng điều kiện chuyển trạng thái (detail message giải thích lý do)

---

## 5. Participant APIs

### 5.1. POST /tournaments/:id/invite — Mời người chơi

**Quyền:** Creator

**Request Body:**
```json
{
  "userIds": [
    "user-uuid-1",
    "user-uuid-2"
  ]
}
```

**Response: 200 OK**
```json
{
  "data": {
    "invited": 2,
    "skipped": 0,
    "errors": []
  }
}
```

**Errors:**
- `422` — Giải đã đầy, hoặc user đã trong giải

---

### 5.2. POST /tournaments/:id/request — Xin tham gia

**Quyền:** Auth (user chưa ở trong giải)

**Request Body:** (không cần body)

**Response: 201 Created**
```json
{
  "data": {
    "id": "participant-uuid",
    "tournamentId": "...",
    "userId": "...",
    "status": "request_pending",
    "joinedAt": null
  }
}
```

**Errors:**
- `409` — Đã có yêu cầu pending
- `422` — Giải không ở trạng thái `open` hoặc đã đầy

---

### 5.3. PUT /tournaments/:id/requests/:requestId — Duyệt / Từ chối

**Quyền:** Creator

**Request Body:**
```json
{
  "action": "approve",
  "reason": null
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| action | string | ✅ | `"approve"` / `"reject"` |
| reason | string | ❌ | Lý do từ chối (max 500 ký tự) |

**Response: 200 OK**
```json
{
  "data": {
    "id": "participant-uuid",
    "status": "confirmed",
    "joinedAt": "2026-03-12T15:00:00Z"
  }
}
```

**Side effects:**
- `approve`: chuyển status → `confirmed`, thông báo user
- `reject`: chuyển status → `rejected`, thông báo user kèm lý do

---

### 5.4. GET /tournaments/:id/participants — Danh sách người tham gia

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| status | string | Filter: `"confirmed"` / `"invited_pending"` / `"request_pending"` |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "participant-uuid",
      "user": {
        "id": "user-uuid",
        "name": "Nguyễn Văn A",
        "avatarUrl": "...",
        "skillLevel": 3.5
      },
      "status": "confirmed",
      "joinedAt": "2026-03-10T09:00:00Z"
    }
  ],
  "meta": {
    "totalConfirmed": 6,
    "totalPending": 2,
    "maxParticipants": 8
  }
}
```

---

### 5.5. DELETE /tournaments/:id/participants/:userId — Rời / Xóa người chơi

**Quyền:** Auth (tự rời) hoặc Creator (xóa người khác)

**Request Body:** (chỉ cần khi Creator xóa)
```json
{
  "reason": "Không đáp ứng yêu cầu trình độ"
}
```

**Response: 204 No Content**

**Errors:**
- `422` — Giải đang `in_progress`, không thể rời/xóa

---

## 6. Team APIs (Doubles)

### 6.1. POST /tournaments/:id/teams — Ghép đội thủ công

**Quyền:** Creator (giải phải là `doubles`)

**Request Body:**
```json
{
  "teams": [
    {
      "name": "Đội Sấm Sét",
      "player1Id": "user-uuid-1",
      "player2Id": "user-uuid-2"
    },
    {
      "name": "Đội Bão Táp",
      "player1Id": "user-uuid-3",
      "player2Id": "user-uuid-4"
    }
  ]
}
```

**Validation:**
- Mỗi player chỉ thuộc 1 đội
- Tất cả player phải là participant `confirmed`
- Phải ghép hết tất cả participant, không thừa

**Response: 201 Created**
```json
{
  "data": [
    {
      "id": "team-uuid-1",
      "name": "Đội Sấm Sét",
      "player1": { "id": "...", "name": "...", "avatarUrl": "..." },
      "player2": { "id": "...", "name": "...", "avatarUrl": "..." }
    },
    ...
  ]
}
```

---

### 6.2. POST /tournaments/:id/teams/random — Ghép đội ngẫu nhiên

**Quyền:** Creator

**Request Body:** (không cần body)

**Response: 200 OK** — Trả về kết quả ghép **preview** (chưa lưu)
```json
{
  "data": {
    "preview": true,
    "teams": [
      {
        "name": "Đội 1",
        "player1": { "id": "...", "name": "..." },
        "player2": { "id": "...", "name": "..." }
      },
      ...
    ]
  }
}
```

**Lưu ý:** Kết quả chỉ là preview. Creator phải gọi `POST /tournaments/:id/teams` để xác nhận lưu.

---

### 6.3. PUT /tournaments/:id/teams — Cập nhật đội

**Quyền:** Creator (chỉ khi chưa `in_progress`)

**Request Body:** Giống 6.1

**Response: 200 OK**

**Errors:**
- `422` — Giải đã `in_progress`, không thể sửa đội
- `422` — Nếu đã xếp bảng, warning kèm: "Xếp bảng sẽ bị hủy, cần xếp lại"

---

## 7. Group APIs

### 7.1. POST /tournaments/:id/groups — Xếp bảng thủ công

**Quyền:** Creator

**Request Body:**
```json
{
  "groups": [
    {
      "name": "A",
      "memberIds": ["id-1", "id-2", "id-3", "id-4"]
    },
    {
      "name": "B",
      "memberIds": ["id-5", "id-6", "id-7", "id-8"]
    }
  ]
}
```

**Lưu ý:**
- `memberIds` chứa **user_id** (Singles) hoặc **team_id** (Doubles)
- Mỗi bảng phải đúng 4 đơn vị
- Phải xếp hết, không thừa
- Số bảng phải bằng `numGroups` của giải

**Response: 201 Created**
```json
{
  "data": {
    "groups": [
      {
        "id": "group-uuid-1",
        "name": "A",
        "members": [ ... ]
      },
      ...
    ],
    "matches": [
      {
        "id": "match-uuid",
        "groupName": "A",
        "round": 1,
        "matchOrder": 1,
        "player1": { "id": "...", "name": "..." },
        "player2": { "id": "...", "name": "..." },
        "status": "scheduled"
      },
      ...
    ]
  }
}
```

**Side effects:** Tự động tạo lịch Round Robin (6 trận / bảng)

---

### 7.2. POST /tournaments/:id/groups/random — Xếp bảng ngẫu nhiên

**Quyền:** Creator

**Response: 200 OK** — Preview (chưa lưu)
```json
{
  "data": {
    "preview": true,
    "groups": [
      {
        "name": "A",
        "members": [
          { "id": "...", "name": "...", "skillLevel": 3.5 },
          ...
        ]
      },
      ...
    ]
  }
}
```

---

## 8. Match & Scoring APIs

### 8.1. GET /tournaments/:id/matches — Lịch thi đấu

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| groupId | uuid | Lọc theo bảng |
| round | int | Lọc theo vòng (1, 2, 3) |
| status | string | `"scheduled"` / `"in_progress"` / `"completed"` |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "match-uuid",
      "tournamentId": "...",
      "group": { "id": "...", "name": "A" },
      "round": 1,
      "matchOrder": 1,
      "player1": {
        "id": "user-or-team-uuid",
        "name": "Nguyễn A",
        "avatarUrl": "..."
      },
      "player2": {
        "id": "user-or-team-uuid",
        "name": "Trần B",
        "avatarUrl": "..."
      },
      "player1Scores": null,
      "player2Scores": null,
      "winnerId": null,
      "status": "scheduled",
      "updatedAt": null
    },
    {
      "id": "match-uuid-2",
      "group": { "id": "...", "name": "A" },
      "round": 1,
      "matchOrder": 2,
      "player1": { "id": "...", "name": "Lê C" },
      "player2": { "id": "...", "name": "Phạm D" },
      "player1Scores": [11, 11],
      "player2Scores": [7, 9],
      "winnerId": "...",
      "status": "completed",
      "updatedAt": "2026-04-15T10:30:00Z"
    }
  ]
}
```

---

### 8.2. POST /matches/:id/score — Nhập điểm

**Quyền:** Creator

**Request Body:**
```json
{
  "player1Scores": [11, 9, 11],
  "player2Scores": [7, 11, 8]
}
```

**Validation:**
- Số set phải phù hợp với `scoringFormat`:
  - `best_of_1`: đúng 1 set
  - `best_of_3`: 2 hoặc 3 set (kết thúc khi 1 bên thắng 2 set)
- Mỗi set: điểm >= 0, người thắng >= 11, cách biệt >= 2
- Ví dụ hợp lệ: [11-7], [11-9], [12-10], [15-13]
- Ví dụ KHÔNG hợp lệ: [10-8], [11-10], [5-3]

**Response: 200 OK**
```json
{
  "data": {
    "id": "match-uuid",
    "player1Scores": [11, 9, 11],
    "player2Scores": [7, 11, 8],
    "winnerId": "player1-uuid",
    "status": "completed",
    "updatedAt": "2026-04-15T10:30:00Z"
  }
}
```

**Side effects:**
- Match status → `completed`
- BXH bảng được tính lại (async)
- SignalR broadcast: `ScoreUpdated` + `StandingsUpdated`
- Nếu đây là trận cuối → Tournament status → `completed`

**Errors:**
- `400` — Điểm không hợp lệ (chi tiết validation errors)
- `422` — Trận đã có điểm (dùng PUT để sửa)

---

### 8.3. PUT /matches/:id/score — Sửa điểm

**Quyền:** Creator

**Request Body:** Giống 8.2

**Response: 200 OK** — Giống 8.2

**Side effects:** Tính lại BXH, SignalR broadcast, log lịch sử sửa

---

### 8.4. GET /tournaments/:id/groups/:groupId/standings — BXH bảng

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": {
    "groupId": "...",
    "groupName": "A",
    "standings": [
      {
        "rank": 1,
        "player": { "id": "...", "name": "Nguyễn A", "avatarUrl": "..." },
        "matchesPlayed": 3,
        "wins": 3,
        "losses": 0,
        "pointsFor": 66,
        "pointsAgainst": 42,
        "pointDiff": 24
      },
      {
        "rank": 2,
        "player": { "id": "...", "name": "Trần B", "avatarUrl": "..." },
        "matchesPlayed": 3,
        "wins": 2,
        "losses": 1,
        "pointsFor": 58,
        "pointsAgainst": 49,
        "pointDiff": 9
      },
      {
        "rank": 3,
        "player": { "id": "...", "name": "Lê C" },
        "matchesPlayed": 3,
        "wins": 1,
        "losses": 2,
        "pointsFor": 50,
        "pointsAgainst": 55,
        "pointDiff": -5
      },
      {
        "rank": 4,
        "player": { "id": "...", "name": "Phạm D" },
        "matchesPlayed": 3,
        "wins": 0,
        "losses": 3,
        "pointsFor": 38,
        "pointsAgainst": 66,
        "pointDiff": -28
      }
    ],
    "tiebreaker": "Xếp hạng: Số thắng → Hiệu số điểm → Đối đầu trực tiếp"
  }
}
```

---

### 8.5. GET /tournaments/:id/results — Kết quả tổng giải

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": {
    "tournamentId": "...",
    "tournamentName": "Giải Mùa Xuân 2026",
    "status": "completed",
    "groupResults": [
      {
        "groupName": "A",
        "champion": { "id": "...", "name": "Nguyễn A", "avatarUrl": "..." },
        "runnerUp": { "id": "...", "name": "Trần B", "avatarUrl": "..." },
        "standings": [ ... ]
      },
      {
        "groupName": "B",
        "champion": { "id": "...", "name": "..." },
        "runnerUp": { "id": "...", "name": "..." },
        "standings": [ ... ]
      }
    ],
    "stats": {
      "totalMatches": 12,
      "totalSetsPlayed": 30,
      "totalPointsScored": 648,
      "closestMatch": {
        "id": "...",
        "player1": "Nguyễn A",
        "player2": "Trần B",
        "scores": "11-9, 9-11, 12-10"
      }
    }
  }
}
```

---

## 9. Community Game APIs (Phase 2)

### 9.1. GET /community/lobby — Danh sách game

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| search | string | Tìm theo tiêu đề |
| skillLevel | string | `"beginner"` / `"intermediate"` / `"advanced"` / `"all"` |
| dateFrom | string | ISO 8601 date |
| dateTo | string | ISO 8601 date |
| lat | decimal | Vĩ độ (để sắp xếp theo khoảng cách) |
| lng | decimal | Kinh độ |
| radius | int | Bán kính tìm kiếm (km) |
| status | string | `"open"` / `"full"` |
| page, pageSize | int | Phân trang |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "game-uuid",
      "title": "Chơi chiều thứ 7 ở Quận 7",
      "date": "2026-03-15T15:00:00Z",
      "location": "Sân XYZ, Quận 7",
      "latitude": 10.7321,
      "longitude": 106.7215,
      "maxPlayers": 8,
      "currentPlayers": 5,
      "skillLevel": "intermediate",
      "status": "open",
      "creator": { "id": "...", "name": "...", "avatarUrl": "..." },
      "distance": 2.5
    }
  ],
  "meta": { ... }
}
```

---

### 9.2. POST /community/games — Tạo game

**Quyền:** Auth

**Request Body:**
```json
{
  "title": "Chơi chiều thứ 7 ở Quận 7",
  "description": "Chơi giao lưu vui vẻ, mọi trình độ đều welcome",
  "date": "2026-03-15T15:00:00Z",
  "location": "Sân XYZ, Quận 7, TP.HCM",
  "latitude": 10.7321,
  "longitude": 106.7215,
  "maxPlayers": 8,
  "skillLevel": "all"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| title | string | ✅ | 5-200 ký tự |
| description | string | ❌ | Max 2000 ký tự |
| date | string | ✅ | ISO 8601, phải trong tương lai |
| location | string | ✅ | Max 500 ký tự |
| latitude | decimal | ❌ | -90 đến 90 |
| longitude | decimal | ❌ | -180 đến 180 |
| maxPlayers | int | ✅ | 2-50 |
| skillLevel | string | ❌ | `"beginner"` / `"intermediate"` / `"advanced"` / `"all"` (default) |

**Response: 201 Created**

---

### 9.3. PUT /community/games/:id — Sửa game

**Quyền:** GameCreator

**Request Body:** Giống 9.2 (partial update)

**Response: 200 OK**

---

### 9.4. DELETE /community/games/:id — Xóa game

**Quyền:** GameCreator

**Response: 204 No Content**

---

### 9.5. POST /community/games/:id/invite — Mời người chơi

**Quyền:** GameCreator

**Request Body:**
```json
{
  "userIds": ["uuid-1", "uuid-2"],
  "message": "Chiều thứ 7 ra sân đánh nhé!"
}
```

**Response: 200 OK**

---

### 9.6. POST /community/games/:id/join — Tham gia game

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": {
    "status": "confirmed",
    "position": 6
  }
}
```

Nếu game đã đầy:
```json
{
  "data": {
    "status": "waitlist",
    "waitlistPosition": 2
  }
}
```

---

### 9.7. DELETE /community/games/:id/leave — Rời game

**Quyền:** Auth

**Response: 204 No Content**

**Side effects:** Nếu có người trong waitlist → tự động promote lên `confirmed`

---

## 10. Chat APIs (Phase 2)

### 10.1. GET /chats — Danh sách phòng chat

**Quyền:** Auth

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "room-uuid",
      "type": "direct",
      "name": null,
      "otherUser": { "id": "...", "name": "Trần B", "avatarUrl": "..." },
      "lastMessage": {
        "content": "OK, hẹn 3h nhé!",
        "senderId": "...",
        "createdAt": "2026-03-12T14:30:00Z"
      },
      "unreadCount": 2
    },
    {
      "id": "room-uuid-2",
      "type": "group",
      "name": "Giải Mùa Xuân 2026",
      "memberCount": 8,
      "lastMessage": { ... },
      "unreadCount": 0
    }
  ]
}
```

---

### 10.2. POST /chats — Tạo phòng chat

**Quyền:** Auth

**Request Body:**
```json
{
  "type": "direct",
  "userId": "other-user-uuid"
}
```

Hoặc group chat:
```json
{
  "type": "group",
  "name": "Nhóm chơi Quận 7",
  "userIds": ["uuid-1", "uuid-2", "uuid-3"]
}
```

**Response: 201 Created**

---

### 10.3. GET /chats/:id/messages — Tin nhắn

**Quyền:** ChatMember

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| before | string | Cursor: lấy tin trước messageId này (load tin cũ) |
| limit | int | Số tin nhắn (default 50, max 100) |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "msg-uuid",
      "senderId": "user-uuid",
      "senderName": "Nguyễn A",
      "senderAvatar": "...",
      "content": "Chiều nay đánh không?",
      "type": "text",
      "readBy": ["user-uuid-2"],
      "createdAt": "2026-03-12T14:28:00Z"
    },
    {
      "id": "msg-uuid-2",
      "senderId": "user-uuid-2",
      "senderName": "Trần B",
      "content": "OK, hẹn 3h nhé!",
      "type": "text",
      "readBy": [],
      "createdAt": "2026-03-12T14:30:00Z"
    }
  ],
  "meta": {
    "hasMore": true,
    "oldestMessageId": "msg-uuid"
  }
}
```

---

### 10.4. POST /chats/:id/messages — Gửi tin nhắn

**Quyền:** ChatMember

**Request Body:**
```json
{
  "content": "Chiều nay 3h nhé!",
  "type": "text"
}
```

**Response: 201 Created**

**Side effects:** SignalR broadcast `MessageReceived` to room members

---

## 11. Notification APIs

### 11.1. GET /notifications — Danh sách thông báo

**Quyền:** Auth

**Query Params:**

| Param | Type | Mô tả |
|-------|------|--------|
| isRead | bool | `true` / `false` / null (tất cả) |
| type | string | `"tournament_invite"` / `"request_approved"` / `"match_result"` / ... |
| page, pageSize | int | Phân trang |

**Response: 200 OK**
```json
{
  "data": [
    {
      "id": "notif-uuid",
      "type": "tournament_invite",
      "title": "Lời mời tham gia giải đấu",
      "body": "Nguyễn A mời bạn tham gia Giải Mùa Xuân 2026",
      "data": {
        "tournamentId": "tournament-uuid",
        "inviterId": "user-uuid"
      },
      "isRead": false,
      "createdAt": "2026-03-12T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 15,
    "totalPages": 1,
    "unreadCount": 5
  }
}
```

---

### 11.2. PUT /notifications/:id/read — Đánh dấu đã đọc

**Quyền:** Auth

**Response: 204 No Content**

---

### 11.3. PUT /notifications/read-all — Đọc tất cả

**Quyền:** Auth

**Response: 204 No Content**

---

## 12. Error Codes

### 12.1. HTTP Status Codes sử dụng

| Code | Ý nghĩa | Khi nào |
|------|---------|---------|
| 200 | OK | Thành công (GET, PUT) |
| 201 | Created | Tạo mới thành công (POST) |
| 204 | No Content | Thành công, không có body (DELETE, PUT status) |
| 400 | Bad Request | Input validation lỗi |
| 401 | Unauthorized | Chưa đăng nhập / token hết hạn |
| 403 | Forbidden | Không có quyền |
| 404 | Not Found | Resource không tồn tại |
| 409 | Conflict | Trùng lặp (đã follow, đã request) |
| 422 | Unprocessable Entity | Vi phạm quy tắc nghiệp vụ |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Lỗi hệ thống |

### 12.2. Business Error Types

| Error Type | HTTP Code | Mô tả |
|-----------|----------|--------|
| `TOURNAMENT_FULL` | 422 | Giải đã đủ người tham gia |
| `INVALID_STATUS_TRANSITION` | 422 | Không thể chuyển trạng thái (ví dụ: draft → in_progress) |
| `INVALID_SCORE` | 400 | Điểm không hợp lệ (chưa đạt 11, chưa cách 2) |
| `GROUPS_NOT_ASSIGNED` | 422 | Chưa xếp bảng (khi cố chuyển sang ready) |
| `NOT_ENOUGH_PARTICIPANTS` | 422 | Chưa đủ người (khi cố xếp bảng) |
| `TOURNAMENT_LOCKED` | 422 | Không thể sửa field bị khóa (type, numGroups) |
| `ALREADY_JOINED` | 409 | Đã tham gia giải |
| `ALREADY_REQUESTED` | 409 | Đã gửi yêu cầu tham gia |
| `MATCH_ALREADY_SCORED` | 422 | Trận đã có điểm (dùng PUT để sửa) |
| `GAME_FULL` | 422 | Game cộng đồng đã đầy |
