# Module 03: Tournament Management — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | Tournament Management |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 1 |
| **Số endpoints** | 7 |
| **DB Tables** | Tournaments, Users |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 3.1 | GET | `/tournaments` | ✅ | Danh sách giải đấu (browse & search) |
| 3.2 | POST | `/tournaments` | ✅ | Tạo giải đấu mới |
| 3.3 | GET | `/tournaments/:id` | ✅ | Xem chi tiết giải đấu |
| 3.4 | PUT | `/tournaments/:id` | Creator | Cập nhật thông tin giải |
| 3.5 | DELETE | `/tournaments/:id` | Creator | Hủy giải đấu |
| 3.6 | PUT | `/tournaments/:id/status` | Creator | Chuyển trạng thái giải |
| 3.7 | POST | `/tournaments/:id/banner` | Creator | Upload ảnh bìa giải |

---

## Sơ đồ trạng thái giải đấu (Tournament Status Flow)

```
                    ┌─────────────────────────────────────────────┐
                    │              cancelled                       │
                    │  (có thể hủy từ draft, open, ready)         │
                    └─────────────────────────────────────────────┘
                              ▲         ▲         ▲
                              │         │         │
    ┌────────┐  Xuất bản  ┌───┴──┐  Đóng ĐK  ┌───┴──┐  Bắt đầu  ┌─────────────┐  Auto  ┌───────────┐
    │  draft │───────────>│ open │───────────>│ready │───────────>│ in_progress │──────>│ completed │
    └────────┘            └──────┘            └──────┘            └─────────────┘       └───────────┘
                              │                   │
                          Điều kiện:           Điều kiện:
                          - Thông tin OK       - Đủ người
                                               - Đã xếp bảng
                                               - Đã tạo lịch RR
```

---

## 3.1. GET /tournaments — Danh sách giải đấu

### Summary
Danh sách giải đấu công khai, hỗ trợ tìm kiếm và lọc. Dùng cho trang "Khám phá giải đấu".

### User Story
```
Là một người chơi pickleball,
Tôi muốn duyệt danh sách các giải đấu đang mở đăng ký,
Để tìm giải phù hợp với trình độ và lịch của tôi.

Acceptance Criteria:
- Tìm kiếm theo tên giải
- Lọc theo: loại (đơn/đôi), trạng thái (đang mở, đang đấu, đã xong)
- Mỗi card hiển thị: tên, loại, ngày, địa điểm, số người/max, trạng thái
- Giải đang mở đăng ký ưu tiên lên đầu
- Giải đã đầy: ẩn nút "Xin tham gia"
- Phân trang
```

### Request

**Query Params:**

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| search | string | null | Tìm theo tên giải (ILIKE) |
| type | string | null | `"singles"` / `"doubles"` |
| status | string | null | `"open"` / `"in_progress"` / `"completed"` |
| page | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang (max 100) |
| sortBy | string | `createdAt` | `"date"` / `"createdAt"` / `"name"` |
| sortOrder | string | `desc` | `"asc"` / `"desc"` |

### Response

**200 OK:**
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
        "id": "creator-uuid",
        "name": "Nguyễn Văn A",
        "avatarUrl": "..."
      },
      "participantCount": 5,
      "maxParticipants": 8,
      "isFull": false,
      "createdAt": "2026-03-01T10:00:00Z"
    }
  ],
  "meta": { "page": 1, "pageSize": 20, "totalCount": 15, "totalPages": 1 }
}
```

### Business Rules

1. Chỉ hiển thị giải có status != `draft` và != `cancelled`
2. Sắp xếp mặc định: `open` lên đầu, rồi `in_progress`, rồi `completed`
3. `isFull = (participantCount >= maxParticipants)`
4. Cache danh sách 5 phút, invalidate khi tạo/sửa/hủy giải

---

## 3.2. POST /tournaments — Tạo giải đấu

### Summary
Tạo giải đấu mới. Giải được tạo ở trạng thái `draft`, chưa hiển thị công khai.

### User Story
```
Là một người tổ chức (organizer),
Tôi muốn tạo một giải đấu pickleball mới,
Để mời người chơi tham gia và tổ chức thi đấu.

Acceptance Criteria:
- Chọn loại: đấu đơn hoặc đấu đôi
- Chọn số bảng: 1-4 (đơn) hoặc 1-2 (đôi)
- Nhập tên giải (bắt buộc), mô tả, ngày, địa điểm
- Chọn format ghi điểm: best of 1 hoặc best of 3
- Hệ thống hiển thị rõ: "Cần tối thiểu X người/đội"
- Giải tạo xong ở trạng thái nháp (draft), chưa public
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  POST /tournaments            │                               │
  │  {name, type, numGroups,      │                               │
  │   scoringFormat, date,        │                               │
  │   location, description}      │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  - name: 3-200 ký tự          │
  │                               │  - type: singles|doubles      │
  │                               │  - numGroups:                 │
  │                               │    singles → 1-4              │
  │                               │    doubles → 1-2              │
  │                               │  - date: tương lai (nếu có)   │
  │                               │                               │
  │                               │  Create Tournament            │
  │                               │  status = 'draft'             │
  │                               │  creatorId = currentUser      │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Tính maxParticipants:        │
  │                               │  singles: numGroups × 4       │
  │                               │  doubles: numGroups × 4 × 2   │
  │                               │                               │
  │  201 {tournament}             │                               │
  │<──────────────────────────────│                               │
```

### Request

**Body:**
```json
{
  "name": "Giải Mùa Xuân 2026",
  "description": "Giải đấu pickleball đầu năm tại TP.HCM",
  "type": "singles",
  "numGroups": 2,
  "scoringFormat": "best_of_3",
  "date": "2026-04-15",
  "location": "Sân XYZ, Quận 1, TP.HCM"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| name | string | ✅ | 3-200 ký tự |
| description | string | ❌ | Max 2000 ký tự |
| type | string | ✅ | `"singles"` / `"doubles"` |
| numGroups | int | ✅ | Singles: 1-4, Doubles: 1-2 |
| scoringFormat | string | ❌ | `"best_of_1"` / `"best_of_3"` (default: best_of_3) |
| date | string | ❌ | ISO 8601 date, phải trong tương lai |
| location | string | ❌ | Max 500 ký tự |

### Response

**201 Created:**
```json
{
  "data": {
    "id": "a1b2c3d4-...",
    "name": "Giải Mùa Xuân 2026",
    "description": "Giải đấu pickleball đầu năm tại TP.HCM",
    "type": "singles",
    "numGroups": 2,
    "scoringFormat": "best_of_3",
    "status": "draft",
    "date": "2026-04-15",
    "location": "Sân XYZ, Quận 1, TP.HCM",
    "bannerUrl": null,
    "creator": { "id": "...", "name": "Nguyễn Văn A", "avatarUrl": "..." },
    "participantCount": 0,
    "maxParticipants": 8,
    "createdAt": "2026-03-12T14:30:00Z"
  }
}
```

### Preconditions

| Điều kiện | Mô tả |
|-----------|-------|
| ✅ Authentication | Bearer Token bắt buộc |
| ✅ Email Verified | User phải xác thực email trước khi tạo giải (`emailVerified == true`) |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------| 
| 403 | EMAIL_NOT_VERIFIED | User chưa xác thực email. Trả kèm message hướng dẫn verify |
| 400 | VALIDATION_ERROR | name rỗng, type sai, numGroups ngoài khoảng |
| 400 | INVALID_DATE | Ngày trong quá khứ |

### Business Rules

1. **Email Verified bắt buộc** — chỉ user đã xác thực email mới được tạo giải đấu
2. Giải tạo ở status `draft` — chưa hiển thị trên danh sách public
3. Creator tự động là chủ giải, có toàn quyền quản lý
4. `maxParticipants` được tính: singles = numGroups × 4, doubles = numGroups × 4 × 2

---

---

## 3.3. GET /tournaments/:id — Chi tiết giải đấu

### Summary
Toàn bộ thông tin giải đấu, bao gồm bảng đấu, lịch thi đấu, kết quả (nếu có).

### User Story
```
Là một người chơi,
Tôi muốn xem chi tiết một giải đấu,
Để biết thông tin tổ chức, danh sách người tham gia, lịch đấu và kết quả.

Acceptance Criteria:
- Thấy thông tin cơ bản: tên, loại, ngày, địa điểm, organizer
- Thấy trạng thái hiện tại và các bảng đấu (nếu đã xếp)
- Nút action tùy vai trò:
  - User chưa tham gia: "Xin tham gia" (nếu giải open + chưa đầy)
  - Player: "Xem lịch đấu"
  - Creator: "Quản lý giải"
```

### Response

**200 OK:**
```json
{
  "data": {
    "id": "a1b2c3d4-...",
    "name": "Giải Mùa Xuân 2026",
    "description": "...",
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
    "currentUser": {
      "role": "player",
      "participantStatus": "confirmed",
      "groupId": "group-a-uuid",
      "groupName": "A"
    },
    "groups": [
      {
        "id": "group-a-uuid",
        "name": "A",
        "members": [
          { "id": "...", "name": "Nguyễn A", "avatarUrl": "...", "skillLevel": 3.5, "seedOrder": 1 },
          { "id": "...", "name": "Trần B", "avatarUrl": "...", "skillLevel": 4.0, "seedOrder": 2 },
          { "id": "...", "name": "Lê C", "avatarUrl": "...", "skillLevel": 3.0, "seedOrder": 3 },
          { "id": "...", "name": "Phạm D", "avatarUrl": "...", "skillLevel": 3.5, "seedOrder": 4 }
        ]
      }
    ],
    "createdAt": "2026-03-01T10:00:00Z",
    "updatedAt": "2026-04-14T08:00:00Z"
  }
}
```

### Business Rules

1. `currentUser` = null nếu user chưa đăng nhập hoặc chưa liên quan đến giải
2. `groups` chỉ trả về khi status >= `ready`
3. `currentUser.role` = `"creator"` / `"player"` / null
4. Giải `draft` chỉ creator mới xem được

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 404 | TOURNAMENT_NOT_FOUND | ID không tồn tại |
| 403 | FORBIDDEN | Giải draft, user không phải creator |

---

## 3.4. PUT /tournaments/:id — Cập nhật giải

### Summary
Chỉnh sửa thông tin giải đấu. Một số field bị khóa sau khi có người tham gia.

### User Story
```
Là người tạo giải,
Tôi muốn sửa thông tin giải (ngày, địa điểm, mô tả),
Nhưng không được sửa loại giải và số bảng nếu đã có người đăng ký.

Acceptance Criteria:
- Sửa được: tên, mô tả, ngày, địa điểm, scoring format
- KHÔNG sửa được (nếu đã có >= 1 participant):
  - type (singles/doubles)
  - numGroups
- Khi sửa ngày/địa điểm: thông báo cho tất cả participants
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  PUT /tournaments/:id         │                               │
  │  {date, location}             │                               │
  │──────────────────────────────>│                               │
  │                               │  Check: creator?              │
  │                               │  → No: 403                    │
  │                               │                               │
  │                               │  Check locked fields:         │
  │                               │  Has participants?            │
  │                               │──────────────────────────────>│
  │                               │  → Yes + trying to change     │
  │                               │    type/numGroups: 422        │
  │                               │                               │
  │                               │  Update allowed fields        │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  date/location changed?       │
  │                               │  → Notify all participants    │
  │                               │                               │
  │  200 {updated tournament}     │                               │
  │<──────────────────────────────│                               │
```

### Request

**Body:** (partial update — chỉ gửi fields cần sửa)
```json
{
  "name": "Giải Mùa Xuân 2026 — Cập nhật",
  "date": "2026-04-20",
  "location": "Sân ABC mới"
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 422 | FIELD_LOCKED | Cố sửa type/numGroups khi đã có participants |
| 422 | TOURNAMENT_COMPLETED | Giải đã kết thúc, không thể sửa |

---

## 3.5. DELETE /tournaments/:id — Hủy giải

### Summary
Hủy giải đấu (soft delete → status = cancelled). Thông báo cho tất cả participants.

### User Story
```
Là người tạo giải,
Tôi muốn hủy giải nếu không đủ người hoặc có lý do bất khả kháng,
Và tất cả người đã đăng ký phải được thông báo.

Acceptance Criteria:
- Giải draft/open/ready → hủy được (lý do tùy chọn)
- Giải in_progress → cảnh báo mạnh + bắt buộc nhập lý do
- Giải completed → KHÔNG hủy được
- Tất cả participants nhận notification
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  DELETE /tournaments/:id      │                               │
  │  {reason: "..."}              │                               │
  │──────────────────────────────>│                               │
  │                               │  Check: creator?              │
  │                               │  Check: status != completed?  │
  │                               │                               │
  │                               │  status = in_progress?        │
  │                               │  → reason required!           │
  │                               │                               │
  │                               │  Update status → cancelled    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Notify ALL participants:     │
  │                               │  type: tournament_cancelled   │
  │                               │  data: {reason}               │
  │                               │                               │
  │  204 No Content               │                               │
  │<──────────────────────────────│                               │
```

### Request

**Body:**
```json
{
  "reason": "Không đủ người tham gia"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| reason | string | Bắt buộc nếu `in_progress` | Max 500 ký tự |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 422 | CANNOT_CANCEL_COMPLETED | Giải đã completed |
| 400 | REASON_REQUIRED | Giải in_progress nhưng không nhập lý do |

---

## 3.6. PUT /tournaments/:id/status — Chuyển trạng thái

### Summary
Chuyển giải đấu sang trạng thái tiếp theo. Mỗi bước có điều kiện tiên quyết riêng.

### User Story
```
Là người tạo giải,
Tôi muốn chuyển giải qua các giai đoạn:
  draft → open (mở đăng ký)
  open → ready (xếp bảng xong, sẵn sàng)
  ready → in_progress (bắt đầu thi đấu)

Với mỗi bước, hệ thống kiểm tra đã đủ điều kiện chưa.
```

### Luồng xử lý (chi tiết cho từng transition)

```
┌──────────────────────────────────────────────────────────────────┐
│ TRANSITION: draft → open                                         │
│                                                                  │
│ Preconditions:                                                   │
│   ✅ Không có điều kiện đặc biệt                                 │
│                                                                  │
│ Side effects:                                                    │
│   - Giải xuất hiện trên trang khám phá                           │
│   - Người chơi có thể xin tham gia                               │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ TRANSITION: open → ready                                         │
│                                                                  │
│ Preconditions (TẤT CẢ phải đáp ứng):                            │
│   ✅ Số participant confirmed >= numGroups × 4                    │
│   ✅ Đã xếp bảng (Groups created + GroupMembers assigned)        │
│   ✅ Đã tạo lịch Round Robin (Matches created)                   │
│   ✅ [Doubles] Đã ghép đội (Teams created)                       │
│                                                                  │
│ Side effects:                                                    │
│   - Đóng đăng ký (không nhận thêm)                               │
│   - Notify participants: "Giải sẵn sàng, xem lịch đấu"          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ TRANSITION: ready → in_progress                                  │
│                                                                  │
│ Preconditions:                                                   │
│   ✅ Có ít nhất 1 trận chưa đấu (status = scheduled)             │
│                                                                  │
│ Side effects:                                                    │
│   - Notify participants: "Giải bắt đầu!"                         │
│   - Creator có thể bắt đầu nhập điểm                             │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ TRANSITION: in_progress → completed (TỰ ĐỘNG)                   │
│                                                                  │
│ Trigger: Khi trận cuối cùng có điểm                              │
│                                                                  │
│ Side effects:                                                    │
│   - Notify participants: "Giải kết thúc! Xem kết quả"            │
│   - Generate kết quả tổng                                        │
└──────────────────────────────────────────────────────────────────┘
```

### Request

**Body:**
```json
{
  "status": "open"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| status | string | ✅ | Trạng thái đích hợp lệ (xem flow ở trên) |

### Response

**204 No Content**

### Error Codes

| HTTP | Error Type | Điều kiện | Chi tiết |
|:----:|-----------|-----------|---------|
| 403 | FORBIDDEN | Không phải creator | |
| 422 | INVALID_STATUS_TRANSITION | draft → ready (skip open) | "Không thể nhảy cóc trạng thái" |
| 422 | NOT_ENOUGH_PARTICIPANTS | open → ready | "Cần thêm X người nữa (hiện có Y/Z)" |
| 422 | GROUPS_NOT_ASSIGNED | open → ready | "Chưa xếp bảng" |
| 422 | TEAMS_NOT_ASSIGNED | open → ready (doubles) | "Chưa ghép đội" |
| 422 | MATCHES_NOT_CREATED | open → ready | "Chưa tạo lịch thi đấu" |

---

## 3.7. POST /tournaments/:id/banner — Upload ảnh bìa

### Summary
Upload ảnh bìa cho giải đấu. Server resize xuống 1200x630 (tỉ lệ OG image).

### Request

**Headers:**
```
Authorization: Bearer {accessToken}
Content-Type: multipart/form-data
```

**Form Data:**

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| file | File | ✅ | MIME: image/jpeg, image/png, image/webp. Max 10 MB. |

### Response

**200 OK:**
```json
{
  "data": {
    "bannerUrl": "https://s3.../banners/tournament-uuid.webp"
  }
}
```

### Business Rules

1. Resize xuống 1200x630 px, convert WebP, quality 80%
2. Ảnh cũ trên S3 bị xóa
3. Chỉ creator mới upload được

---

## Capacity Reference

| Loại | Số bảng | Đơn vị/bảng | Tổng tối đa | Số trận tối đa |
|------|:-------:|:-----------:|:-----------:|:--------------:|
| **Singles** | 1 | 4 người | 4 người | 6 trận |
| | 2 | 4 người | 8 người | 12 trận |
| | 3 | 4 người | 12 người | 18 trận |
| | 4 | 4 người | 16 người | 24 trận |
| **Doubles** | 1 | 4 đội (8 người) | 8 người | 6 trận |
| | 2 | 4 đội (16 người) | 16 người | 12 trận |
