# Module 06: Community Game — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | Community Game (Game giao hữu) |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 2 |
| **Số endpoints** | 8 |
| **DB Tables** | CommunityGames, GameParticipants |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 6.1 | GET | `/community/lobby` | ✅ | Danh sách game (lobby) |
| 6.2 | POST | `/community/games` | ✅ | Tạo game |
| 6.3 | GET | `/community/games/:id` | ✅ | Chi tiết game |
| 6.4 | PUT | `/community/games/:id` | GameCreator | Sửa game |
| 6.5 | DELETE | `/community/games/:id` | GameCreator | Xóa/hủy game |
| 6.6 | POST | `/community/games/:id/invite` | GameCreator | Mời người chơi |
| 6.7 | POST | `/community/games/:id/join` | ✅ | Tham gia game |
| 6.8 | DELETE | `/community/games/:id/leave` | ✅ | Rời game |

---

## Luồng tổng quan Community Game

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     COMMUNITY GAME FLOW                                  │
│                                                                          │
│  Creator ──[6.2 Tạo game]──> Game (status: open)                        │
│                                    │                                     │
│                    ┌───────────────┼───────────────┐                     │
│                    │               │               │                     │
│              [6.1 Lobby]    [6.6 Invite]    [6.7 Join]                   │
│              Hiển thị game   Mời người chơi   Tự tham gia               │
│              trên lobby      → invited_pending  │                        │
│                    │               │            ┌┴─────────────┐         │
│                    │               │      Còn slot?   Hết slot?          │
│                    │               │      confirmed    waitlist          │
│                    │               │            └┬─────────────┘         │
│                    │               │             │                        │
│                    └───────────────┼─────────────┘                       │
│                                    │                                     │
│                          Đủ maxPlayers?                                  │
│                          ──Yes──> status: full                           │
│                                    │                                     │
│                          Creator bắt đầu                                 │
│                          ──────> status: in_progress                     │
│                                    │                                     │
│                          Kết thúc                                        │
│                          ──────> status: completed                       │
│                                                                          │
│  [6.8 Leave] Ai đó rời ──> auto-promote waitlist → confirmed            │
│                                                                          │
│  [6.5 Cancel] Creator hủy ──> status: cancelled                         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Enum Reference

| Enum | Values | Mô tả |
|------|--------|-------|
| GameStatus | `open`, `full`, `in_progress`, `completed`, `cancelled` | Trạng thái game |
| GameParticipantStatus | `confirmed`, `waitlist`, `invited_pending`, `cancelled` | Trạng thái người tham gia |
| SkillLevel | `any`, `beginner`, `intermediate`, `advanced` | Trình độ yêu cầu |
| GameType | `singles`, `doubles` | Loại game |

---

## 6.1. GET /community/lobby — Danh sách game (lobby)

### Summary
Danh sách game giao hữu công khai, hỗ trợ tìm kiếm, lọc theo vị trí, trình độ, loại game. Dùng cho trang "Lobby" — nơi người chơi tìm game để tham gia.

### User Story
```
Là một người chơi pickleball,
Tôi muốn xem danh sách các game giao hữu đang mở gần tôi,
Để tìm game phù hợp và tham gia ngay.

Acceptance Criteria:
- Hiển thị danh sách game đang mở (open) mặc định
- Lọc theo: vị trí (gần tôi), trình độ, loại game, trạng thái, khoảng ngày
- Tìm kiếm theo tên game
- Mỗi card hiển thị: tên, địa điểm, thời gian, số người/max, trình độ, loại
- Sắp xếp theo thời gian bắt đầu hoặc khoảng cách
- Phân trang
```

### Luồng xử lý

```
User                            Server                          Database
  │                               │                               │
  │  GET /community/lobby         │                               │
  │  ?lat=10.7&lng=106.6          │                               │
  │  &radius=10&skillLevel=any    │                               │
  │──────────────────────────────>│                               │
  │                               │  Build query:                 │
  │                               │  ✓ Filter by status           │
  │                               │  ✓ Filter by skillLevel       │
  │                               │  ✓ Filter by gameType         │
  │                               │  ✓ Filter by date range       │
  │                               │  ✓ Search by title (ILIKE)    │
  │                               │  ✓ Geo filter (PostGIS)       │
  │                               │  ✓ Sort & paginate            │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  200 {data, meta}             │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Query Params:**

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| search | string | null | Tìm theo tên game (ILIKE) |
| lat | decimal | null | Vĩ độ người dùng (required nếu dùng nearby) |
| lng | decimal | null | Kinh độ người dùng (required nếu dùng nearby) |
| radius | int | 10 | Bán kính tìm kiếm (km), max 50 |
| skillLevel | string | null | `"any"` / `"beginner"` / `"intermediate"` / `"advanced"` |
| gameType | string | null | `"singles"` / `"doubles"` |
| status | string | `"open"` | `"open"` / `"full"` / `"in_progress"` / `"completed"` |
| dateFrom | datetime | null | Lọc game từ ngày (ISO 8601) |
| dateTo | datetime | null | Lọc game đến ngày (ISO 8601) |
| sortBy | string | `scheduledAt` | `"scheduledAt"` / `"distance"` / `"createdAt"` |
| sortOrder | string | `asc` | `"asc"` / `"desc"` |
| page | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang (max 100) |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "game-uuid-1",
      "title": "Giao hữu cuối tuần Q7",
      "description": "Đánh vui cuối tuần, ai rảnh vào nhé!",
      "gameType": "doubles",
      "skillLevel": "intermediate",
      "location": {
        "latitude": 10.7321,
        "longitude": 106.7215,
        "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
      },
      "distance": 2.3,
      "scheduledAt": "2026-03-15T08:00:00Z",
      "maxPlayers": 8,
      "currentPlayers": 5,
      "status": "open",
      "creator": {
        "id": "user-uuid",
        "name": "Nguyễn Văn A",
        "avatarUrl": "https://..."
      },
      "createdAt": "2026-03-12T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 45,
    "totalPages": 3
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |
| title | string | Tên game |
| description | string | Mô tả |
| gameType | string | `singles` / `doubles` |
| skillLevel | string | Trình độ yêu cầu |
| location | object | Thông tin vị trí |
| location.latitude | decimal | Vĩ độ |
| location.longitude | decimal | Kinh độ |
| location.address | string | Địa chỉ text |
| distance | decimal | Khoảng cách (km) — chỉ có khi gửi lat/lng |
| scheduledAt | datetime | Thời gian dự kiến |
| maxPlayers | int | Số người tối đa |
| currentPlayers | int | Số người hiện tại (confirmed) |
| status | string | Trạng thái game |
| creator | object | Thông tin người tạo |
| createdAt | datetime | Ngày tạo |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 400 | INVALID_COORDINATES | lat/lng không hợp lệ |
| 400 | INVALID_RADIUS | radius < 1 hoặc > 50 |
| 400 | INVALID_DATE_RANGE | dateFrom > dateTo |

### Business Rules

1. Mặc định chỉ hiển thị game `open` — client có thể filter status khác
2. Game đã `cancelled` KHÔNG hiển thị trên lobby
3. Nếu gửi `lat`/`lng` → tính khoảng cách bằng PostGIS, trả field `distance`
4. Nếu gửi `lat`/`lng` + `radius` → chỉ trả game trong bán kính
5. Nếu không gửi `lat`/`lng` → sort theo `scheduledAt` (mặc định), không trả `distance`
6. Game đã qua thời gian `scheduledAt` > 24h → không hiển thị trên lobby (auto-hide)

---

## 6.2. POST /community/games — Tạo game

### Summary
Tạo một game giao hữu mới. Người tạo tự động trở thành participant (confirmed) và là GameCreator.

### User Story
```
Là một người chơi pickleball,
Tôi muốn tạo một game giao hữu,
Để mời bạn bè hoặc tìm người chơi cùng.

Acceptance Criteria:
- Nhập: tên, mô tả, địa điểm (chọn trên map), thời gian, số người tối đa, trình độ, loại game
- Sau khi tạo: tôi tự động là participant (confirmed)
- Game xuất hiện trên lobby để người khác tìm thấy
- Số người tối đa: 2-20
- Thời gian phải trong tương lai
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  POST /community/games        │                               │
  │  {title, description,         │                               │
  │   location, scheduledAt,      │                               │
  │   maxPlayers, skillLevel,     │                               │
  │   gameType}                   │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Required fields             │
  │                               │  ✓ scheduledAt > now()         │
  │                               │  ✓ maxPlayers 2-20             │
  │                               │  ✓ Enum values hợp lệ         │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Create CommunityGame          │
  │                               │  (status: open)               │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Create GameParticipant        │
  │                               │  (creator, status: confirmed) │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  201 {game}                   │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Body:**
```json
{
  "title": "Giao hữu cuối tuần Q7",
  "description": "Đánh vui cuối tuần, ai rảnh vào nhé!",
  "gameType": "doubles",
  "skillLevel": "intermediate",
  "location": {
    "latitude": 10.7321,
    "longitude": 106.7215,
    "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
  },
  "scheduledAt": "2026-03-15T08:00:00Z",
  "maxPlayers": 8
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| title | string | ✅ | 3-100 ký tự |
| description | string | ❌ | Max 1000 ký tự |
| gameType | string | ✅ | `"singles"` / `"doubles"` |
| skillLevel | string | ✅ | `"any"` / `"beginner"` / `"intermediate"` / `"advanced"` |
| location | object | ✅ | |
| location.latitude | decimal | ✅ | -90 đến 90 |
| location.longitude | decimal | ✅ | -180 đến 180 |
| location.address | string | ✅ | 5-500 ký tự |
| scheduledAt | datetime | ✅ | Phải trong tương lai (> now + 30 phút) |
| maxPlayers | int | ✅ | 2-20 |

### Response

**201 Created:**
```json
{
  "data": {
    "id": "game-uuid",
    "title": "Giao hữu cuối tuần Q7",
    "description": "Đánh vui cuối tuần, ai rảnh vào nhé!",
    "gameType": "doubles",
    "skillLevel": "intermediate",
    "location": {
      "latitude": 10.7321,
      "longitude": 106.7215,
      "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
    },
    "scheduledAt": "2026-03-15T08:00:00Z",
    "maxPlayers": 8,
    "currentPlayers": 1,
    "status": "open",
    "creator": {
      "id": "user-uuid",
      "name": "Nguyễn Văn A",
      "avatarUrl": "https://..."
    },
    "participants": [
      {
        "id": "participant-uuid",
        "user": {
          "id": "user-uuid",
          "name": "Nguyễn Văn A",
          "avatarUrl": "https://..."
        },
        "status": "confirmed",
        "joinedAt": "2026-03-12T10:00:00Z"
      }
    ],
    "createdAt": "2026-03-12T10:00:00Z",
    "updatedAt": "2026-03-12T10:00:00Z"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 400 | VALIDATION_ERROR | Field không hợp lệ (title quá ngắn, maxPlayers ngoài range...) |
| 400 | SCHEDULED_IN_PAST | scheduledAt không trong tương lai |
| 400 | INVALID_COORDINATES | latitude/longitude không hợp lệ |

### Business Rules

1. Người tạo game tự động là participant đầu tiên (status: `confirmed`)
2. Game mới tạo luôn có status = `open`
3. `scheduledAt` phải cách hiện tại ít nhất 30 phút
4. Mỗi user tối đa tạo 5 game `open` cùng lúc (tránh spam)
5. `currentPlayers` = 1 khi mới tạo (tính cả creator)

---

## 6.3. GET /community/games/:id — Chi tiết game

### Summary
Xem chi tiết một game giao hữu, bao gồm danh sách người tham gia.

### User Story
```
Là một người chơi,
Tôi muốn xem chi tiết một game giao hữu,
Để biết thông tin và quyết định có tham gia hay không.

Acceptance Criteria:
- Hiển thị đầy đủ thông tin game
- Hiển thị danh sách người đã tham gia (confirmed)
- Hiển thị trạng thái của tôi (nếu đã join/waitlist/invited)
- Creator thấy thêm danh sách waitlist và invited_pending
```

### Luồng xử lý

```
User                            Server                          Database
  │                               │                               │
  │  GET /community/games/:id     │                               │
  │──────────────────────────────>│                               │
  │                               │  Fetch game + participants    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  If currentUser == creator:   │
  │                               │  → Include all participants   │
  │                               │  Else:                        │
  │                               │  → Only confirmed + myStatus  │
  │                               │                               │
  │  200 {game}                   │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

### Response

**200 OK:**
```json
{
  "data": {
    "id": "game-uuid",
    "title": "Giao hữu cuối tuần Q7",
    "description": "Đánh vui cuối tuần, ai rảnh vào nhé!",
    "gameType": "doubles",
    "skillLevel": "intermediate",
    "location": {
      "latitude": 10.7321,
      "longitude": 106.7215,
      "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
    },
    "scheduledAt": "2026-03-15T08:00:00Z",
    "maxPlayers": 8,
    "currentPlayers": 5,
    "status": "open",
    "creator": {
      "id": "user-uuid",
      "name": "Nguyễn Văn A",
      "avatarUrl": "https://..."
    },
    "myStatus": "confirmed",
    "participants": [
      {
        "id": "participant-uuid",
        "user": {
          "id": "user-uuid",
          "name": "Nguyễn Văn A",
          "avatarUrl": "https://...",
          "skillLevel": 3.5
        },
        "status": "confirmed",
        "joinedAt": "2026-03-12T10:00:00Z"
      }
    ],
    "waitlist": [
      {
        "id": "participant-uuid-2",
        "user": {
          "id": "user-uuid-2",
          "name": "Trần Văn B",
          "avatarUrl": "https://..."
        },
        "status": "waitlist",
        "joinedAt": "2026-03-12T12:00:00Z"
      }
    ],
    "createdAt": "2026-03-12T10:00:00Z",
    "updatedAt": "2026-03-12T10:30:00Z"
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| myStatus | string / null | Trạng thái của user hiện tại: `confirmed`, `waitlist`, `invited_pending`, hoặc `null` (chưa tham gia) |
| participants | array | Danh sách confirmed — mọi user đều thấy |
| waitlist | array | Danh sách waitlist — chỉ creator thấy |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 404 | GAME_NOT_FOUND | Game không tồn tại |

### Business Rules

1. Mọi user đều thấy danh sách `confirmed`
2. Chỉ creator thấy `waitlist` và `invited_pending`
3. Field `myStatus` cho biết trạng thái user hiện tại trong game (null = chưa tham gia)
4. Game `cancelled` vẫn xem được nhưng hiển thị trạng thái đã hủy

---

## 6.4. PUT /community/games/:id — Sửa game

### Summary
GameCreator cập nhật thông tin game giao hữu. Chỉ sửa được khi game chưa bắt đầu.

### User Story
```
Là người tạo game,
Tôi muốn sửa thông tin game (địa điểm, giờ, số người...),
Để cập nhật khi có thay đổi.

Acceptance Criteria:
- Chỉ creator mới sửa được
- Chỉ sửa khi status là open hoặc full
- Nếu giảm maxPlayers < currentPlayers → báo lỗi
- Nếu sửa scheduledAt → phải vẫn trong tương lai
- Notify tất cả participants khi có thay đổi quan trọng (thời gian, địa điểm)
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  PUT /community/games/:id     │                               │
  │  {title, scheduledAt, ...}    │                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ Is creator?                │
  │                               │  ✓ Status = open or full?     │
  │                               │  ✓ Validate fields             │
  │                               │  ✓ maxPlayers >= currentPlayers│
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Update game                  │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  If scheduledAt or location   │
  │                               │  changed → notify all         │
  │                               │  participants                 │
  │                               │                               │
  │  200 {updated game}           │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | GameCreator (người tạo game) |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

**Body (partial update):**
```json
{
  "title": "Giao hữu cuối tuần Q7 — ĐỔI GIỜ",
  "description": "Đánh vui cuối tuần, đổi sang 9h sáng!",
  "gameType": "doubles",
  "skillLevel": "intermediate",
  "location": {
    "latitude": 10.7321,
    "longitude": 106.7215,
    "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
  },
  "scheduledAt": "2026-03-15T09:00:00Z",
  "maxPlayers": 10
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| title | string | ❌ | 3-100 ký tự |
| description | string | ❌ | Max 1000 ký tự |
| gameType | string | ❌ | `"singles"` / `"doubles"` |
| skillLevel | string | ❌ | `"any"` / `"beginner"` / `"intermediate"` / `"advanced"` |
| location | object | ❌ | |
| location.latitude | decimal | ✅* | -90 đến 90 (*bắt buộc nếu gửi location) |
| location.longitude | decimal | ✅* | -180 đến 180 (*bắt buộc nếu gửi location) |
| location.address | string | ✅* | 5-500 ký tự (*bắt buộc nếu gửi location) |
| scheduledAt | datetime | ❌ | Phải trong tương lai |
| maxPlayers | int | ❌ | 2-20, >= currentPlayers |

### Response

**200 OK:**
```json
{
  "data": {
    "id": "game-uuid",
    "title": "Giao hữu cuối tuần Q7 — ĐỔI GIỜ",
    "description": "Đánh vui cuối tuần, đổi sang 9h sáng!",
    "gameType": "doubles",
    "skillLevel": "intermediate",
    "location": {
      "latitude": 10.7321,
      "longitude": 106.7215,
      "address": "Sân Pickleball Q7, 123 Nguyễn Thị Thập, Q7, TP.HCM"
    },
    "scheduledAt": "2026-03-15T09:00:00Z",
    "maxPlayers": 10,
    "currentPlayers": 5,
    "status": "open",
    "creator": {
      "id": "user-uuid",
      "name": "Nguyễn Văn A",
      "avatarUrl": "https://..."
    },
    "createdAt": "2026-03-12T10:00:00Z",
    "updatedAt": "2026-03-12T14:00:00Z"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 404 | GAME_NOT_FOUND | Game không tồn tại |
| 400 | VALIDATION_ERROR | Field không hợp lệ |
| 400 | SCHEDULED_IN_PAST | scheduledAt không trong tương lai |
| 422 | GAME_NOT_EDITABLE | Game status không phải open hoặc full |
| 422 | MAX_PLAYERS_TOO_LOW | maxPlayers < currentPlayers |

### Business Rules

1. Chỉ sửa được khi status = `open` hoặc `full`
2. Nếu giảm `maxPlayers` → phải >= `currentPlayers` (không tự kick người)
3. Nếu tăng `maxPlayers` khi status = `full` → status tự chuyển về `open`
4. Nếu thay đổi `scheduledAt` hoặc `location` → notify tất cả participants (push + in-app)
5. Partial update: chỉ cần gửi field muốn sửa

---

## 6.5. DELETE /community/games/:id — Xóa / Hủy game

### Summary
GameCreator hủy game giao hữu. Tất cả participants nhận notification.

### User Story
```
Là người tạo game,
Tôi muốn hủy game nếu không thể tổ chức được,
Để thông báo cho mọi người biết.

Acceptance Criteria:
- Chỉ creator mới hủy được
- Không hủy được game đang in_progress hoặc đã completed
- Tất cả participants nhận notification "Game đã bị hủy"
- Game chuyển status = cancelled (soft delete)
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  DELETE /community/games/:id  │                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ Is creator?                │
  │                               │  ✓ Status != in_progress      │
  │                               │  ✓ Status != completed        │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Update status = cancelled    │
  │                               │  Update all participants      │
  │                               │  → status = cancelled         │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Notify all participants      │
  │                               │  "Game X đã bị hủy"          │
  │                               │                               │
  │  204 No Content               │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | GameCreator (người tạo game) |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

### Response

**204 No Content** — không có body.

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 404 | GAME_NOT_FOUND | Game không tồn tại |
| 422 | GAME_IN_PROGRESS | Game đang diễn ra, không hủy được |
| 422 | GAME_ALREADY_COMPLETED | Game đã hoàn thành |
| 422 | GAME_ALREADY_CANCELLED | Game đã bị hủy trước đó |

### Business Rules

1. Soft delete: chuyển status = `cancelled`, không xóa record khỏi DB
2. Tất cả participants chuyển status = `cancelled`
3. Notify tất cả participants (push + in-app)
4. Game đã `cancelled` không hiển thị trên lobby
5. Chỉ hủy được khi status = `open` hoặc `full`

---

## 6.6. POST /community/games/:id/invite — Mời người chơi

### Summary
GameCreator mời một hoặc nhiều người chơi vào game. Người được mời nhận notification và status = `invited_pending` cho đến khi chấp nhận.

### User Story
```
Là người tạo game,
Tôi muốn mời trực tiếp những người chơi cụ thể vào game,
Để chơi cùng bạn bè hoặc người quen.

Acceptance Criteria:
- Tìm user theo tên, gửi lời mời
- Mời nhiều người cùng lúc (batch)
- Không mời được user đã ở trong game
- Không mời quá maxPlayers
- User nhận push notification
- User nhận lời mời → status = invited_pending
- User chấp nhận → status = confirmed (nếu còn slot) hoặc waitlist (nếu hết slot)
- User từ chối → xóa record
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  POST /community/games/       │                               │
  │       :id/invite              │                               │
  │  {userIds: [id1, id2]}        │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate per user:           │
  │                               │  ✓ User exists?               │
  │                               │  ✓ Not already in game?       │
  │                               │  ✓ Game status = open/full?   │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  For each valid user:         │
  │                               │  Create GameParticipant        │
  │                               │  (status: invited_pending)    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Send notifications           │
  │                               │  (push + in-app)              │
  │                               │  "User X mời bạn vào game Y" │
  │                               │                               │
  │  200 {invited, skipped,       │                               │
  │       errors}                 │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | GameCreator (người tạo game) |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

**Body:**
```json
{
  "userIds": [
    "user-uuid-1",
    "user-uuid-2",
    "user-uuid-3"
  ]
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| userIds | UUID[] | ✅ | 1-10 UUIDs, tất cả phải tồn tại |

### Response

**200 OK:**
```json
{
  "data": {
    "invited": 2,
    "skipped": 1,
    "errors": [
      { "userId": "user-uuid-3", "reason": "ALREADY_IN_GAME" }
    ]
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| invited | int | Số user đã mời thành công |
| skipped | int | Số user bị bỏ qua (đã ở trong game, không tồn tại...) |
| errors | array | Chi tiết lỗi từng user bị skip |
| errors[].userId | UUID | ID user bị lỗi |
| errors[].reason | string | `ALREADY_IN_GAME`, `USER_NOT_FOUND` |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 404 | GAME_NOT_FOUND | Game không tồn tại |
| 422 | GAME_NOT_OPEN | Game status không phải open hoặc full |

### Business Rules

1. Mỗi user tối đa nhận 1 lời mời / game
2. User nhận lời mời status = `invited_pending`
3. `invited_pending` KHÔNG tính vào `currentPlayers` — chỉ tính khi chấp nhận
4. User chấp nhận:
   - Còn slot → status = `confirmed`, `currentPlayers++`
   - Hết slot → status = `waitlist`
5. User từ chối → xóa GameParticipant record
6. Giới hạn batch: tối đa 10 users / lần gọi
7. Notification bao gồm: tên game, tên creator, thời gian, địa điểm
8. Có thể mời khi game `full` — user sẽ vào waitlist khi chấp nhận

---

## 6.7. POST /community/games/:id/join — Tham gia game

### Summary
User tham gia game giao hữu. Nếu còn slot → `confirmed`, nếu hết slot → `waitlist`. Khi ai đó rời game, người đầu waitlist tự động được promote lên `confirmed`.

### User Story
```
Là một người chơi,
Tôi muốn tham gia một game giao hữu đang mở trên lobby,
Để chơi cùng mọi người.

Acceptance Criteria:
- Chỉ join được game status = open hoặc full (waitlist)
- Nếu còn slot (currentPlayers < maxPlayers) → confirmed ngay
- Nếu hết slot → vào waitlist
- Không join lại nếu đã ở trong game
- Khi ai đó rời → người đầu waitlist tự động lên confirmed
- Nhận notification khi được promote từ waitlist
```

### Luồng xử lý

```
User                            Server                          Database
  │                               │                               │
  │  POST /community/games/       │                               │
  │       :id/join                │                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ Game exists?               │
  │                               │  ✓ Status = open or full?     │
  │                               │  ✓ User not already in game?  │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Count confirmed participants │
  │                               │                               │
  │                               │  ┌─ confirmed < maxPlayers ─┐ │
  │                               │  │ Create GameParticipant    │ │
  │                               │  │ status: confirmed         │ │
  │                               │  │ currentPlayers++          │ │
  │                               │  │                           │ │
  │                               │  │ If currentPlayers ==      │ │
  │                               │  │ maxPlayers → game status  │ │
  │                               │  │ = full                    │ │
  │                               │  └───────────────────────────┘ │
  │                               │                               │
  │                               │  ┌─ confirmed >= maxPlayers ─┐│
  │                               │  │ Create GameParticipant    ││
  │                               │  │ status: waitlist          ││
  │                               │  │ waitlistOrder = next      ││
  │                               │  └───────────────────────────┘│
  │                               │──────────────────────────────>│
  │                               │                               │
  │  201 {participant}            │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

**Body:** Không có body.

### Response

**201 Created (Confirmed):**
```json
{
  "data": {
    "id": "participant-uuid",
    "gameId": "game-uuid",
    "userId": "user-uuid",
    "status": "confirmed",
    "waitlistOrder": null,
    "joinedAt": "2026-03-12T15:00:00Z",
    "createdAt": "2026-03-12T15:00:00Z"
  }
}
```

**201 Created (Waitlist):**
```json
{
  "data": {
    "id": "participant-uuid",
    "gameId": "game-uuid",
    "userId": "user-uuid",
    "status": "waitlist",
    "waitlistOrder": 1,
    "joinedAt": null,
    "createdAt": "2026-03-12T15:00:00Z"
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID participant record |
| gameId | UUID | ID game |
| userId | UUID | ID user |
| status | string | `confirmed` hoặc `waitlist` |
| waitlistOrder | int / null | Thứ tự trong waitlist (null nếu confirmed) |
| joinedAt | datetime / null | Thời gian chính thức tham gia (null nếu waitlist) |
| createdAt | datetime | Thời gian tạo record |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 404 | GAME_NOT_FOUND | Game không tồn tại |
| 409 | ALREADY_IN_GAME | User đã ở trong game (confirmed/waitlist) |
| 422 | GAME_NOT_JOINABLE | Game status không phải open hoặc full |
| 422 | GAME_CANCELLED | Game đã bị hủy |
| 422 | GAME_COMPLETED | Game đã hoàn thành |

### Business Rules

1. Nếu `currentPlayers < maxPlayers` → status = `confirmed`, set `joinedAt = now()`
2. Nếu `currentPlayers >= maxPlayers` → status = `waitlist`, set `waitlistOrder` theo thứ tự FIFO
3. Khi `currentPlayers == maxPlayers` → game status tự chuyển thành `full`
4. **Auto-promote từ waitlist:**
   - Khi ai đó rời (6.8 Leave) → `currentPlayers--`
   - Nếu có người trong waitlist → promote người có `waitlistOrder` nhỏ nhất
   - Promote: status `waitlist` → `confirmed`, set `joinedAt = now()`, clear `waitlistOrder`
   - Gửi notification: "Bạn đã được xác nhận vào game X"
   - Nếu sau promote `currentPlayers < maxPlayers` → game status chuyển về `open`
5. User có `invited_pending` gọi join → chuyển status theo logic trên (confirmed/waitlist)
6. Không cho join game `in_progress`, `completed`, `cancelled`

---

## 6.8. DELETE /community/games/:id/leave — Rời game

### Summary
User rời khỏi game giao hữu. Nếu có waitlist, người đầu hàng đợi tự động được promote lên.

### User Story
```
Là một người chơi đã tham gia game,
Tôi muốn rời game nếu không thể tham gia được nữa,
Để nhường chỗ cho người khác.

Acceptance Criteria:
- Rời được khi status = confirmed hoặc waitlist
- Không rời được nếu game đang in_progress
- Creator không thể rời (phải hủy game thay vì rời)
- Sau khi rời: auto-promote waitlist (nếu có)
- Notify creator khi có người rời
```

### Luồng xử lý

```
User                            Server                          Database
  │                               │                               │
  │  DELETE /community/games/     │                               │
  │         :id/leave             │                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ User is participant?       │
  │                               │  ✓ User is NOT creator?       │
  │                               │  ✓ Game not in_progress?      │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Delete GameParticipant       │
  │                               │  record                       │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  If user was confirmed:       │
  │                               │  → currentPlayers--           │
  │                               │  → Check waitlist             │
  │                               │                               │
  │                               │  ┌─ Has waitlist? ───────────┐│
  │                               │  │ Promote first in waitlist ││
  │                               │  │ waitlist → confirmed      ││
  │                               │  │ Set joinedAt = now()      ││
  │                               │  │ Reorder remaining waitlist││
  │                               │  │ Notify promoted user      ││
  │                               │  └───────────────────────────┘│
  │                               │                               │
  │                               │  If currentPlayers <          │
  │                               │  maxPlayers && status == full │
  │                               │  → status = open              │
  │                               │                               │
  │                               │  Notify creator               │
  │                               │  "User X đã rời game Y"      │
  │                               │                               │
  │  204 No Content               │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ participant (trừ creator) |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID game |

**Body:** Không có body.

### Response

**204 No Content** — không có body.

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | CREATOR_CANNOT_LEAVE | Creator không thể rời game (phải hủy) |
| 404 | GAME_NOT_FOUND | Game không tồn tại |
| 404 | NOT_A_PARTICIPANT | User không phải participant của game |
| 422 | GAME_IN_PROGRESS | Game đang diễn ra, không rời được |

### Business Rules

1. Creator KHÔNG thể rời game — phải dùng 6.5 (Hủy game) thay vì rời
2. User rời khi status = `confirmed`:
   - `currentPlayers--`
   - Nếu có người trong waitlist → auto-promote (FIFO)
   - Người được promote nhận notification
   - Reorder `waitlistOrder` cho các waitlist còn lại
3. User rời khi status = `waitlist`:
   - Xóa record, reorder `waitlistOrder`
   - Không ảnh hưởng `currentPlayers`
4. Nếu sau khi rời `currentPlayers < maxPlayers` và game status = `full` → chuyển về `open`
5. Notify creator khi có người rời (push + in-app)
6. Không rời được khi game `in_progress` — phải chờ game kết thúc
