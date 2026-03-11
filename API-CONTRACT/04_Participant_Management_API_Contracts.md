# Module 04: Participant Management — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | Participant Management (Mời, Đăng ký, Ghép đội, Xếp bảng) |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 1 |
| **Số endpoints** | 7 |
| **DB Tables** | Participants, Teams, Groups, GroupMembers, Matches |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 4.1 | POST | `/tournaments/:id/invite` | Creator | Mời người chơi tham gia |
| 4.2 | POST | `/tournaments/:id/request` | ✅ | Xin tham gia giải đấu |
| 4.3 | PUT | `/tournaments/:id/requests/:rid` | Creator | Duyệt hoặc từ chối yêu cầu |
| 4.4 | GET | `/tournaments/:id/participants` | ✅ | Danh sách người tham gia |
| 4.5 | DELETE | `/tournaments/:id/participants/:uid` | ✅/Creator | Rời giải hoặc xóa người chơi |
| 4.6 | POST | `/tournaments/:id/teams` | Creator | Ghép đội (Doubles only) |
| 4.7 | POST | `/tournaments/:id/groups` | Creator | Xếp bảng + tự động tạo lịch RR |

---

## Luồng tham gia giải đấu (tổng quan)

```
┌──────────────────────────────────────────────────────────────────────┐
│ CÁCH 1: Creator mời                                                  │
│                                                                      │
│ Creator ──[4.1 Invite]──> Notification đến User                      │
│                               │                                      │
│                     User chấp nhận? ──Yes──> Status: confirmed       │
│                               │                                      │
│                              No ──────────> Status: rejected         │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ CÁCH 2: User xin vào                                                 │
│                                                                      │
│ User ──[4.2 Request]──> Notification đến Creator                     │
│                               │                                      │
│                    Creator duyệt? ──[4.3 Approve]──> confirmed       │
│                               │                                      │
│                          [4.3 Reject] ──────────────> rejected       │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│ SAU KHI ĐỦ NGƯỜI:                                                    │
│                                                                      │
│ [Doubles only] Creator ──[4.6 Ghép đội]──> Teams                     │
│                                                │                     │
│ Creator ──[4.7 Xếp bảng]──> Groups + GroupMembers + Matches (6/bảng)│
│                                                                      │
│ Creator ──[3.6 Status → ready]──> Sẵn sàng thi đấu                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 4.1. POST /tournaments/:id/invite — Mời người chơi

### Summary
Creator mời một hoặc nhiều người chơi vào giải. Người được mời nhận notification và có thể chấp nhận/từ chối.

### User Story
```
Là người tạo giải,
Tôi muốn mời trực tiếp những người chơi cụ thể,
Để đảm bảo giải có đủ người và đúng trình độ mong muốn.

Acceptance Criteria:
- Tìm user theo tên, gửi lời mời
- Mời nhiều người cùng lúc (batch)
- Không mời được user đã ở trong giải
- Không mời quá max capacity
- User nhận push notification
- User nhận lời mời → status = invited_pending
- User chấp nhận → status = confirmed (không cần duyệt thêm)
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  POST /tournaments/:id/invite │                               │
  │  {userIds: [id1, id2]}        │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate per user:           │
  │                               │  ✓ User exists?               │
  │                               │  ✓ Not already in tournament? │
  │                               │  ✓ Tournament not full?       │
  │                               │  ✓ Tournament status = open?  │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  For each valid user:         │
  │                               │  Create Participant            │
  │                               │  (status: invited_pending)    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Send notifications           │
  │                               │  (push + in-app)              │
  │                               │                               │
  │  200 {invited: 2,             │                               │
  │       skipped: 0, errors: []} │                               │
  │<──────────────────────────────│                               │
```

### Request

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
| userIds | UUID[] | ✅ | 1-20 UUIDs, tất cả phải tồn tại |

### Response

**200 OK:**
```json
{
  "data": {
    "invited": 2,
    "skipped": 1,
    "errors": [
      { "userId": "user-uuid-3", "reason": "ALREADY_IN_TOURNAMENT" }
    ]
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 422 | TOURNAMENT_NOT_OPEN | Giải không ở trạng thái `open` |
| 422 | TOURNAMENT_FULL | Giải đã đủ người |

### Business Rules

1. Mỗi user tối đa nhận 1 lời mời / giải
2. User nhận lời mời status = `invited_pending`
3. User chấp nhận (qua notification action) → status = `confirmed` (KHÔNG cần creator duyệt)
4. User từ chối → status = `rejected`
5. Giới hạn batch: tối đa 20 users / lần gọi

---

## 4.2. POST /tournaments/:id/request — Xin tham gia

### Summary
User gửi yêu cầu tham gia giải đấu. Creator nhận notification và quyết định duyệt/từ chối.

### User Story
```
Là một người chơi,
Tôi muốn xin tham gia một giải đấu đang mở đăng ký,
Để có cơ hội thi đấu.

Acceptance Criteria:
- Giải phải đang ở trạng thái "open" và chưa đầy
- Tôi chưa có yêu cầu pending hoặc đã ở trong giải
- Sau khi gửi: hiển thị "Đang chờ duyệt"
- Creator nhận notification để duyệt
- Tôi có thể hủy yêu cầu khi chưa được duyệt
```

### Luồng xử lý

```
User                            Server                          Database
  │                               │                               │
  │  POST /tournaments/:id/request│                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ Tournament open?           │
  │                               │  ✓ Not full?                  │
  │                               │  ✓ User not already in?       │
  │                               │  ✓ No pending request?        │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Create Participant            │
  │                               │  (status: request_pending)    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Notify creator               │
  │                               │  "User X xin vào giải Y"     │
  │                               │                               │
  │  201 {participant}            │                               │
  │<──────────────────────────────│                               │
```

### Response

**201 Created:**
```json
{
  "data": {
    "id": "participant-uuid",
    "tournamentId": "...",
    "userId": "...",
    "status": "request_pending",
    "joinedAt": null,
    "createdAt": "2026-03-12T15:00:00Z"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 409 | ALREADY_IN_TOURNAMENT | User đã ở trong giải (confirmed) |
| 409 | REQUEST_ALREADY_PENDING | Đã có yêu cầu đang chờ duyệt |
| 422 | TOURNAMENT_NOT_OPEN | Giải không ở trạng thái `open` |
| 422 | TOURNAMENT_FULL | Giải đã đủ người |

---

## 4.3. PUT /tournaments/:id/requests/:rid — Duyệt / Từ chối

### Summary
Creator duyệt hoặc từ chối yêu cầu tham gia.

### User Story
```
Là người tạo giải,
Tôi muốn duyệt hoặc từ chối các yêu cầu tham gia,
Để kiểm soát ai được tham gia giải.
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  PUT /tournaments/:id/        │                               │
  │      requests/:rid            │                               │
  │  {action: "approve"}          │                               │
  │──────────────────────────────>│                               │
  │                               │  Check:                       │
  │                               │  ✓ Creator?                   │
  │                               │  ✓ Request exists & pending?  │
  │                               │  ✓ [approve] Tournament       │
  │                               │    not full?                  │
  │                               │                               │
  │                               │  approve:                     │
  │                               │  → status = confirmed          │
  │                               │  → set joinedAt = now()       │
  │                               │  → notify user: "Đã được duyệt"
  │                               │                               │
  │                               │  reject:                      │
  │                               │  → status = rejected           │
  │                               │  → notify user: "Bị từ chối"  │
  │                               │    + reason (nếu có)          │
  │                               │                               │
  │  200 {updated participant}    │                               │
  │<──────────────────────────────│                               │
```

### Request

**Body:**
```json
{
  "action": "approve",
  "reason": null
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| action | string | ✅ | `"approve"` / `"reject"` |
| reason | string | ❌ | Max 500 ký tự (lý do từ chối) |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 404 | REQUEST_NOT_FOUND | Request không tồn tại |
| 422 | REQUEST_NOT_PENDING | Request đã được xử lý rồi |
| 422 | TOURNAMENT_FULL | Duyệt nhưng giải đã đủ người |

---

## 4.4. GET /tournaments/:id/participants — Danh sách người tham gia

### Request

**Query Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| status | string | `"confirmed"` / `"invited_pending"` / `"request_pending"` |

### Response

**200 OK:**
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
    "totalInvitedPending": 1,
    "totalRequestPending": 2,
    "maxParticipants": 8
  }
}
```

### Business Rules

1. Tất cả users thấy danh sách confirmed
2. Chỉ creator thấy danh sách pending (invited_pending, request_pending)
3. Chỉ creator thấy nút xóa người chơi

---

## 4.5. DELETE /tournaments/:id/participants/:uid — Rời / Xóa

### User Story
```
Trường hợp 1 — Player tự rời:
  Tôi muốn rời giải nếu không thể tham gia được nữa.
  Chỉ được rời khi giải chưa bắt đầu thi đấu.

Trường hợp 2 — Creator xóa người:
  Tôi (creator) muốn xóa người chơi khỏi giải.
  Nếu đã xếp bảng → cảnh báo phải xếp lại.
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  DELETE /tournaments/:id/     │                               │
  │         participants/:uid     │                               │
  │──────────────────────────────>│                               │
  │                               │  Who is requesting?           │
  │                               │                               │
  │                               │  Case 1: uid == currentUser   │
  │                               │  → Self leave                 │
  │                               │  → Check: status != in_progress│
  │                               │                               │
  │                               │  Case 2: currentUser = creator│
  │                               │  → Creator removing player    │
  │                               │  → Check: status != in_progress│
  │                               │  → {reason} bắt buộc          │
  │                               │                               │
  │                               │  Delete participant record    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Has groups been assigned?    │
  │                               │  → Yes: Delete groups +       │
  │                               │    matches + warn creator     │
  │                               │    "Cần xếp bảng lại"        │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Notify removed user          │
  │                               │                               │
  │  204 No Content               │                               │
  │<──────────────────────────────│                               │
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải self hoặc creator |
| 422 | TOURNAMENT_IN_PROGRESS | Giải đang thi đấu, không thể rời/xóa |

### Business Rules

1. Nếu đã xếp bảng → xóa groups + groupMembers + matches → phải xếp lại
2. Nếu giải `in_progress`: KHÔNG cho rời/xóa → dùng walkover cho trận còn lại
3. Creator xóa → notify user bị xóa kèm lý do

---

## 4.6. POST /tournaments/:id/teams — Ghép đội (Doubles only)

### Summary
Creator ghép cặp người chơi thành các đội cho giải đấu đôi. Hỗ trợ ghép thủ công hoặc ngẫu nhiên.

### User Story
```
Là người tạo giải đấu đôi,
Sau khi đã đủ người tham gia (bội số của 2),
Tôi muốn ghép cặp thành các đội 2 người,
Có thể tự chọn hoặc để hệ thống xáo trộn ngẫu nhiên.

Acceptance Criteria:
- Chỉ áp dụng cho giải doubles
- Mỗi đội 2 người, phải ghép hết không thừa
- Hỗ trợ 2 mode: manual (chỉ định) và random (preview trước)
- Sau khi ghép xong mới được xếp bảng
```

### Request

**Mode 1: Thủ công**
```json
{
  "mode": "manual",
  "teams": [
    { "name": "Đội Sấm Sét", "player1Id": "uuid-1", "player2Id": "uuid-2" },
    { "name": "Đội Bão Táp", "player1Id": "uuid-3", "player2Id": "uuid-4" }
  ]
}
```

**Mode 2: Ngẫu nhiên (preview)**
```json
{
  "mode": "random"
}
```

### Response

**Mode manual — 201 Created:**
```json
{
  "data": {
    "saved": true,
    "teams": [
      {
        "id": "team-uuid-1",
        "name": "Đội Sấm Sét",
        "player1": { "id": "...", "name": "Nguyễn A", "avatarUrl": "..." },
        "player2": { "id": "...", "name": "Trần B", "avatarUrl": "..." }
      }
    ]
  }
}
```

**Mode random — 200 OK (preview, chưa lưu):**
```json
{
  "data": {
    "saved": false,
    "teams": [
      {
        "name": "Đội 1",
        "player1": { "id": "...", "name": "..." },
        "player2": { "id": "...", "name": "..." }
      }
    ]
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 422 | NOT_DOUBLES | Giải không phải doubles |
| 422 | ODD_PLAYER_COUNT | Số người lẻ, không ghép được |
| 422 | PLAYER_NOT_CONFIRMED | Có player chưa confirmed |
| 422 | DUPLICATE_PLAYER | Một player thuộc 2 đội |

### Business Rules

1. Random dùng Fisher-Yates shuffle
2. Random trả preview → creator gọi lại manual với data đã chấp nhận để lưu
3. Nếu đã có teams trước đó → xóa cũ, tạo mới (replace all)
4. Nếu đã xếp bảng → xóa groups + matches → phải xếp lại

---

## 4.7. POST /tournaments/:id/groups — Xếp bảng

### Summary
Creator xếp người/đội vào các bảng. Sau khi xếp, hệ thống TỰ ĐỘNG tạo lịch Round Robin. Hỗ trợ manual và random.

### User Story
```
Là người tạo giải,
Khi đã đủ người (và ghép đội xong nếu doubles),
Tôi muốn xếp người/đội vào các bảng (mỗi bảng 4),
Và hệ thống tự tạo lịch thi đấu vòng tròn.

Acceptance Criteria:
- Mỗi bảng đúng 4 đơn vị (4 người hoặc 4 đội)
- Phải xếp hết, không thừa
- Hỗ trợ thủ công (kéo thả) và ngẫu nhiên (preview)
- Sau khi xác nhận: hệ thống tạo 6 trận/bảng (3 vòng × 2 trận)
```

### Luồng xử lý (Manual mode)

```
Creator                         Server                          Database
  │                               │                               │
  │  POST /tournaments/:id/groups │                               │
  │  {mode: "manual",             │                               │
  │   groups: [{name:"A",         │                               │
  │     memberIds:[1,2,3,4]},     │                               │
  │     {name:"B",...}]}          │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Creator?                   │
  │                               │  ✓ Each group = 4 members     │
  │                               │  ✓ All members confirmed      │
  │                               │  ✓ No duplicates              │
  │                               │  ✓ numGroups matches          │
  │                               │                               │
  │                               │  Delete old groups/matches    │
  │                               │  (nếu đã có)                 │
  │                               │                               │
  │                               │  Create Groups                │
  │                               │  Create GroupMembers          │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  === AUTO GENERATE ===        │
  │                               │  For each group (4 members):  │
  │                               │  Vòng 1: A-B, C-D             │
  │                               │  Vòng 2: A-C, B-D             │
  │                               │  Vòng 3: A-D, B-C             │
  │                               │  → 6 Match records / group    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  201 {groups, matches}        │                               │
  │<──────────────────────────────│                               │
```

### Request

**Mode 1: Thủ công**
```json
{
  "mode": "manual",
  "groups": [
    { "name": "A", "memberIds": ["id-1", "id-2", "id-3", "id-4"] },
    { "name": "B", "memberIds": ["id-5", "id-6", "id-7", "id-8"] }
  ]
}
```

**Mode 2: Ngẫu nhiên**
```json
{
  "mode": "random"
}
```

**Lưu ý:** `memberIds` chứa **user_id** (Singles) hoặc **team_id** (Doubles)

### Response

**Manual — 201 Created:**
```json
{
  "data": {
    "saved": true,
    "groups": [
      {
        "id": "group-uuid-a",
        "name": "A",
        "members": [
          { "id": "...", "name": "Nguyễn A", "skillLevel": 3.5, "seedOrder": 1 },
          { "id": "...", "name": "Trần B", "skillLevel": 4.0, "seedOrder": 2 },
          { "id": "...", "name": "Lê C", "skillLevel": 3.0, "seedOrder": 3 },
          { "id": "...", "name": "Phạm D", "skillLevel": 3.5, "seedOrder": 4 }
        ]
      }
    ],
    "matches": [
      {
        "id": "match-uuid",
        "groupName": "A",
        "round": 1,
        "matchOrder": 1,
        "player1": { "id": "...", "name": "Nguyễn A" },
        "player2": { "id": "...", "name": "Trần B" },
        "status": "scheduled"
      },
      {
        "id": "match-uuid-2",
        "groupName": "A",
        "round": 1,
        "matchOrder": 2,
        "player1": { "id": "...", "name": "Lê C" },
        "player2": { "id": "...", "name": "Phạm D" },
        "status": "scheduled"
      }
    ],
    "totalMatches": 12
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 403 | FORBIDDEN | Không phải creator |
| 422 | INVALID_GROUP_SIZE | Bảng không đúng 4 members |
| 422 | WRONG_GROUP_COUNT | Số bảng không khớp numGroups |
| 422 | MEMBER_NOT_FOUND | memberIds không tồn tại trong participants |
| 422 | DUPLICATE_MEMBER | Một member thuộc 2 bảng |
| 422 | LEFTOVER_MEMBERS | Có member chưa được xếp |
| 422 | TEAMS_NOT_ASSIGNED | Giải doubles nhưng chưa ghép đội |

### Business Rules

1. Xếp bảng sẽ **replace** nếu đã có (xóa groups + matches cũ)
2. Lịch Round Robin được tạo tự động — pattern cố định cho 4 đơn vị
3. `seedOrder` = thứ tự trong memberIds (1-4)
4. Random mode → preview, gọi lại manual với data chấp nhận để lưu
5. Sau khi xếp bảng thành công → creator có thể chuyển status → `ready`
