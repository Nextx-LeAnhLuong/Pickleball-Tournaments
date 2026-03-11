# Module 05: Match & Scoring — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | Match & Scoring (Lịch thi đấu, Nhập điểm, BXH, Kết quả) |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 1 |
| **Số endpoints** | 6 |
| **DB Tables** | Matches, MatchScoreHistories, Groups, GroupMembers, Tournaments, Participants, Teams |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 5.1 | GET | `/tournaments/:id/matches` | ✅ | Lịch thi đấu |
| 5.2 | GET | `/tournaments/:id/draw` | ✅ | Bracket/draw data |
| 5.3 | POST | `/matches/:id/score` | Creator | Nhập điểm |
| 5.4 | PUT | `/matches/:id/score` | Creator | Sửa điểm |
| 5.5 | GET | `/tournaments/:id/groups/:gid/standings` | ✅ | BXH bảng |
| 5.6 | GET | `/tournaments/:id/results` | ✅ | Kết quả tổng |

---

## Luồng tổng quan: Match & Scoring

```
┌──────────────────────────────────────────────────────────────────────────┐
│ LUỒNG THI ĐẤU & CHẤM ĐIỂM                                              │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────┐ │
│  │  Lịch thi đấu │───>│  Nhập điểm   │───>│  Tính BXH    │───>│Kết quả │ │
│  │  (5.1, 5.2)  │    │  (5.3, 5.4)  │    │   (5.5)      │    │ (5.6)  │ │
│  └──────────────┘    └──────────────┘    └──────────────┘    └────────┘ │
│                                                                          │
│  Chi tiết:                                                               │
│                                                                          │
│  Module 04 tạo lịch RR ──> Matches (status: scheduled)                  │
│          │                                                               │
│          ▼                                                               │
│  Creator xem lịch (5.1) ──> Chọn trận ──> Nhập điểm (5.3)             │
│          │                                                               │
│          ▼                                                               │
│  Server validate điểm pickleball (11 điểm, dẫn 2)                       │
│  → Match status = completed                                              │
│  → Log vào MatchScoreHistories                                           │
│  → SignalR notify TournamentHub                                          │
│          │                                                               │
│          ▼                                                               │
│  Sai điểm? ──> Creator sửa (5.4) ──> Log history mới                   │
│          │                                                               │
│          ▼                                                               │
│  Xem BXH bảng (5.5) ──> Tính từ match results                          │
│  → Wins, Losses, Point diff, Sets won/lost                              │
│  → Tiebreaker: Wins → Point diff → Head-to-head → Mini RR              │
│          │                                                               │
│          ▼                                                               │
│  Tất cả trận xong ──> Kết quả tổng (5.6)                               │
│  → Xếp hạng tổng, Nhất/Nhì mỗi bảng, Thống kê                         │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Enums tham chiếu

| Enum | Giá trị | Mô tả |
|------|---------|-------|
| MatchStatus | `scheduled`, `in_progress`, `completed`, `walkover` | Trạng thái trận đấu |
| ScoringFormat | `best_of_1`, `best_of_3` | Thể thức tính điểm |
| TournamentType | `singles`, `doubles` | Loại giải |

---

## 5.1. GET /tournaments/:id/matches — Lịch thi đấu

### Summary
Lấy danh sách tất cả trận đấu của giải. Hỗ trợ lọc theo bảng, vòng, trạng thái.

### User Story
```
Là người tham gia giải / người xem,
Tôi muốn xem lịch thi đấu của giải,
Để biết trận nào sắp diễn ra, đang đấu, hoặc đã xong.

Acceptance Criteria:
- Hiển thị tất cả trận, nhóm theo vòng (round)
- Lọc theo bảng (group), vòng (round), trạng thái (status)
- Mỗi trận hiển thị: 2 bên, bảng, vòng, trạng thái, điểm (nếu đã đấu)
- Giải doubles: hiển thị tên đội thay vì tên cá nhân
- Trận đang đấu (in_progress) ưu tiên lên đầu
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /tournaments/:id/matches │                               │
  │  ?groupId=xxx&round=1&        │                               │
  │   status=scheduled            │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Tournament exists?          │
  │                               │  ✓ User authenticated?        │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Query Matches                │
  │                               │  JOIN Groups, Participants/   │
  │                               │  Teams                        │
  │                               │  Apply filters                │
  │                               │<──────────────────────────────│
  │                               │                               │
  │  200 {matches}                │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Authenticated user | Xem lịch thi đấu |
| Creator | Xem lịch thi đấu |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Tournament ID |

**Query Params:**

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| groupId | UUID | null | Lọc theo bảng |
| round | int | null | Lọc theo vòng (1, 2, 3) |
| status | string | null | `"scheduled"` / `"in_progress"` / `"completed"` / `"walkover"` |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "match-uuid-1",
      "groupId": "group-uuid-a",
      "groupName": "A",
      "round": 1,
      "matchOrder": 1,
      "status": "completed",
      "scoringFormat": "best_of_3",
      "player1": {
        "id": "participant-uuid-1",
        "name": "Nguyễn Văn A",
        "avatarUrl": "https://s3.../avatar1.webp"
      },
      "player2": {
        "id": "participant-uuid-2",
        "name": "Trần Văn B",
        "avatarUrl": "https://s3.../avatar2.webp"
      },
      "scores": [
        { "set": 1, "player1Score": 11, "player2Score": 7 },
        { "set": 2, "player1Score": 9, "player2Score": 11 },
        { "set": 3, "player1Score": 11, "player2Score": 5 }
      ],
      "winnerId": "participant-uuid-1",
      "createdAt": "2026-03-12T08:00:00Z",
      "updatedAt": "2026-03-12T10:30:00Z"
    },
    {
      "id": "match-uuid-2",
      "groupId": "group-uuid-a",
      "groupName": "A",
      "round": 1,
      "matchOrder": 2,
      "status": "scheduled",
      "scoringFormat": "best_of_3",
      "player1": {
        "id": "participant-uuid-3",
        "name": "Lê Văn C",
        "avatarUrl": "https://s3.../avatar3.webp"
      },
      "player2": {
        "id": "participant-uuid-4",
        "name": "Phạm Văn D",
        "avatarUrl": "https://s3.../avatar4.webp"
      },
      "scores": [],
      "winnerId": null,
      "createdAt": "2026-03-12T08:00:00Z",
      "updatedAt": null
    }
  ],
  "meta": {
    "totalMatches": 12,
    "completed": 4,
    "inProgress": 1,
    "scheduled": 6,
    "walkover": 1
  }
}
```

**Mô tả fields:**

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | Match ID |
| groupId | UUID | Bảng đấu |
| groupName | string | Tên bảng (A, B, ...) |
| round | int | Vòng đấu (1-3) |
| matchOrder | int | Thứ tự trận trong vòng (1-2) |
| status | string | MatchStatus enum |
| scoringFormat | string | `best_of_1` / `best_of_3` |
| player1 / player2 | object | Thông tin người/đội tham gia |
| scores | array | Điểm từng set (rỗng nếu chưa đấu) |
| winnerId | UUID / null | ID người/đội thắng |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 404 | TOURNAMENT_NOT_FOUND | Giải không tồn tại |

### Business Rules

1. Trận đấu được tạo tự động khi xếp bảng (Module 04, endpoint 4.7)
2. Round Robin 4 người: 3 vòng × 2 trận = 6 trận / bảng
3. Giải doubles: `player1`, `player2` chứa thông tin đội (team) thay vì cá nhân
4. Trận `in_progress` và `scheduled` sắp xếp lên đầu

---

## 5.2. GET /tournaments/:id/draw — Bracket / Draw data

### Summary
Lấy toàn bộ cấu trúc bảng đấu (draw) bao gồm bảng, thành viên, và lịch thi đấu theo dạng cây. Dùng cho UI hiển thị bracket view.

### User Story
```
Là người xem giải,
Tôi muốn xem sơ đồ bảng đấu tổng quan,
Để biết ai ở bảng nào, đã đấu với ai, kết quả ra sao.

Acceptance Criteria:
- Hiển thị tất cả bảng với thành viên
- Mỗi bảng hiển thị 6 trận theo vòng
- Điểm số hiển thị inline nếu trận đã xong
- Highlight trận đang đấu (in_progress)
- Hiển thị seed order trong bảng
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /tournaments/:id/draw    │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Tournament exists?          │
  │                               │  ✓ Groups assigned?           │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Query Groups + GroupMembers  │
  │                               │  + Matches (all)              │
  │                               │  Organize by group → round    │
  │                               │<──────────────────────────────│
  │                               │                               │
  │  200 {draw}                   │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Authenticated user | Xem draw |
| Creator | Xem draw |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Tournament ID |

### Response

**200 OK:**
```json
{
  "data": {
    "tournamentId": "tournament-uuid",
    "tournamentName": "Giải Mùa Xuân 2026",
    "type": "singles",
    "scoringFormat": "best_of_3",
    "groups": [
      {
        "id": "group-uuid-a",
        "name": "A",
        "members": [
          {
            "id": "participant-uuid-1",
            "name": "Nguyễn Văn A",
            "avatarUrl": "...",
            "seedOrder": 1
          },
          {
            "id": "participant-uuid-2",
            "name": "Trần Văn B",
            "avatarUrl": "...",
            "seedOrder": 2
          },
          {
            "id": "participant-uuid-3",
            "name": "Lê Văn C",
            "avatarUrl": "...",
            "seedOrder": 3
          },
          {
            "id": "participant-uuid-4",
            "name": "Phạm Văn D",
            "avatarUrl": "...",
            "seedOrder": 4
          }
        ],
        "rounds": [
          {
            "round": 1,
            "matches": [
              {
                "id": "match-uuid-1",
                "matchOrder": 1,
                "player1": { "id": "...", "name": "Nguyễn Văn A", "seedOrder": 1 },
                "player2": { "id": "...", "name": "Trần Văn B", "seedOrder": 2 },
                "status": "completed",
                "scores": [
                  { "set": 1, "player1Score": 11, "player2Score": 7 },
                  { "set": 2, "player1Score": 11, "player2Score": 9 }
                ],
                "winnerId": "participant-uuid-1"
              },
              {
                "id": "match-uuid-2",
                "matchOrder": 2,
                "player1": { "id": "...", "name": "Lê Văn C", "seedOrder": 3 },
                "player2": { "id": "...", "name": "Phạm Văn D", "seedOrder": 4 },
                "status": "scheduled",
                "scores": [],
                "winnerId": null
              }
            ]
          },
          {
            "round": 2,
            "matches": [
              {
                "id": "match-uuid-3",
                "matchOrder": 1,
                "player1": { "id": "...", "name": "Nguyễn Văn A", "seedOrder": 1 },
                "player2": { "id": "...", "name": "Lê Văn C", "seedOrder": 3 },
                "status": "scheduled",
                "scores": [],
                "winnerId": null
              },
              {
                "id": "match-uuid-4",
                "matchOrder": 2,
                "player1": { "id": "...", "name": "Trần Văn B", "seedOrder": 2 },
                "player2": { "id": "...", "name": "Phạm Văn D", "seedOrder": 4 },
                "status": "scheduled",
                "scores": [],
                "winnerId": null
              }
            ]
          },
          {
            "round": 3,
            "matches": [
              {
                "id": "match-uuid-5",
                "matchOrder": 1,
                "player1": { "id": "...", "name": "Nguyễn Văn A", "seedOrder": 1 },
                "player2": { "id": "...", "name": "Phạm Văn D", "seedOrder": 4 },
                "status": "scheduled",
                "scores": [],
                "winnerId": null
              },
              {
                "id": "match-uuid-6",
                "matchOrder": 2,
                "player1": { "id": "...", "name": "Trần Văn B", "seedOrder": 2 },
                "player2": { "id": "...", "name": "Lê Văn C", "seedOrder": 3 },
                "status": "scheduled",
                "scores": [],
                "winnerId": null
              }
            ]
          }
        ]
      }
    ]
  }
}
```

**Mô tả fields:**

| Field | Type | Mô tả |
|-------|------|-------|
| tournamentId | UUID | ID giải |
| type | string | `singles` / `doubles` |
| scoringFormat | string | `best_of_1` / `best_of_3` |
| groups[] | array | Danh sách bảng đấu |
| groups[].members[] | array | Thành viên bảng, có seedOrder |
| groups[].rounds[] | array | 3 vòng đấu |
| rounds[].matches[] | array | 2 trận / vòng |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 404 | TOURNAMENT_NOT_FOUND | Giải không tồn tại |
| 422 | GROUPS_NOT_ASSIGNED | Chưa xếp bảng |

### Business Rules

1. Draw data chỉ có khi đã xếp bảng (endpoint 4.7)
2. Cấu trúc cố định: 4 người / bảng, 3 vòng, 2 trận / vòng
3. Giải doubles: members chứa thông tin team (id, name) thay vì cá nhân
4. Data được tính toán realtime từ Matches table

---

## 5.3. POST /matches/:id/score — Nhập điểm

### Summary
Creator nhập điểm cho một trận đấu. Validate theo luật pickleball (11 điểm, dẫn 2). Tự động cập nhật status trận, gửi realtime notification qua SignalR, và log lịch sử điểm.

### User Story
```
Là người tạo giải (trọng tài),
Sau mỗi trận đấu, tôi muốn nhập điểm từng set,
Để hệ thống tự động cập nhật kết quả và bảng xếp hạng.

Acceptance Criteria:
- Chỉ creator mới được nhập điểm
- Trận phải ở trạng thái scheduled hoặc in_progress
- Validate điểm theo luật pickleball:
  + Set thắng khi đạt 11 điểm VÀ dẫn ít nhất 2 điểm
  + Ví dụ hợp lệ: 11-7, 11-9, 12-10, 15-13
  + Ví dụ KHÔNG hợp lệ: 11-10, 10-8, 7-5
- best_of_1: nhập đúng 1 set
- best_of_3: nhập 2 hoặc 3 set (thắng 2 set = kết thúc)
- Sau khi nhập: match status → completed
- Hệ thống gửi SignalR notification realtime
- Log vào MatchScoreHistories (action: "create")
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  POST /matches/:id/score     │                               │
  │  {scores: [{set:1,           │                               │
  │    p1:11, p2:7}, ...]}       │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Creator of tournament?     │
  │                               │  ✓ Match status = scheduled   │
  │                               │    or in_progress?            │
  │                               │  ✓ Match not already scored?  │
  │                               │                               │
  │                               │  Validate scores:             │
  │                               │  ✓ Number of sets correct?    │
  │                               │    (best_of_1: 1 set,         │
  │                               │     best_of_3: 2-3 sets)      │
  │                               │  ✓ Each set: winner >= 11?    │
  │                               │  ✓ Each set: diff >= 2?       │
  │                               │  ✓ Loser score = winner - 2   │
  │                               │    khi winner > 11?           │
  │                               │  ✓ best_of_3: đúng 1 người   │
  │                               │    thắng majority?            │
  │                               │                               │
  │                               │  All valid:                   │
  │                               │──────────────────────────────>│
  │                               │  UPDATE Match:                │
  │                               │  - scores = [...]             │
  │                               │  - winnerId = computed        │
  │                               │  - status = completed         │
  │                               │                               │
  │                               │  INSERT MatchScoreHistories:  │
  │                               │  - matchId, scores, action:   │
  │                               │    "create", changedBy,       │
  │                               │    createdAt                  │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  SignalR → TournamentHub:     │
  │                               │  "match_score_updated"        │
  │                               │  {matchId, scores, winnerId}  │
  │                               │                               │
  │                               │  Check: All matches in        │
  │                               │  tournament completed?        │
  │                               │  → Yes: Tournament status     │
  │                               │    = completed (auto)         │
  │                               │                               │
  │  201 {match with scores}     │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Creator (tournament owner) | Nhập điểm |
| Others | ❌ Không có quyền |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Match ID |

**Body:**
```json
{
  "scores": [
    { "set": 1, "player1Score": 11, "player2Score": 7 },
    { "set": 2, "player1Score": 9, "player2Score": 11 },
    { "set": 3, "player1Score": 11, "player2Score": 5 }
  ]
}
```

**Validation chi tiết:**

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| scores | array | ✅ | Mảng set scores |
| scores[].set | int | ✅ | Số thứ tự set (1, 2, hoặc 3) |
| scores[].player1Score | int | ✅ | Điểm player 1, >= 0 |
| scores[].player2Score | int | ✅ | Điểm player 2, >= 0 |

**Quy tắc validate điểm pickleball:**

| Quy tắc | Mô tả | Ví dụ hợp lệ | Ví dụ sai |
|----------|-------|---------------|-----------|
| Điểm thắng | Người thắng set phải đạt >= 11 | 11-7 | 10-8 |
| Chênh lệch 2 | Phải dẫn ít nhất 2 điểm | 11-9, 12-10 | 11-10 |
| Deuce rule | Khi cả hai >= 10, thắng = thua + 2 | 13-11, 15-13 | 13-12 |
| Số set (best_of_1) | Đúng 1 set | 1 set | 2+ sets |
| Số set (best_of_3) | 2 sets (2-0) hoặc 3 sets (2-1) | 2 hoặc 3 sets | 1 set, hoặc 3 sets khi đã 2-0 |
| Majority winner | best_of_3: chỉ 1 người thắng >= 2 sets | A thắng 2 sets | A thắng 1, B thắng 1 (chỉ 2 sets) |

### Response

**201 Created:**
```json
{
  "data": {
    "id": "match-uuid",
    "groupId": "group-uuid-a",
    "groupName": "A",
    "round": 1,
    "matchOrder": 1,
    "status": "completed",
    "scoringFormat": "best_of_3",
    "player1": {
      "id": "participant-uuid-1",
      "name": "Nguyễn Văn A",
      "avatarUrl": "..."
    },
    "player2": {
      "id": "participant-uuid-2",
      "name": "Trần Văn B",
      "avatarUrl": "..."
    },
    "scores": [
      { "set": 1, "player1Score": 11, "player2Score": 7 },
      { "set": 2, "player1Score": 9, "player2Score": 11 },
      { "set": 3, "player1Score": 11, "player2Score": 5 }
    ],
    "winnerId": "participant-uuid-1",
    "setsWon": { "player1": 2, "player2": 1 },
    "updatedAt": "2026-03-12T10:30:00Z"
  }
}
```

**Mô tả fields:**

| Field | Type | Mô tả |
|-------|------|-------|
| status | string | Luôn là `completed` sau khi nhập điểm |
| scores | array | Điểm từng set |
| winnerId | UUID | Người/đội thắng (tự tính) |
| setsWon | object | Số set thắng mỗi bên |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 403 | FORBIDDEN | Không phải creator của giải |
| 404 | MATCH_NOT_FOUND | Match không tồn tại |
| 409 | MATCH_ALREADY_SCORED | Trận đã có điểm (dùng PUT để sửa) |
| 422 | MATCH_NOT_SCOREABLE | Match status không phải `scheduled` hoặc `in_progress` |
| 422 | INVALID_SET_COUNT | Số set không đúng với scoring format |
| 422 | INVALID_SCORE | Điểm không hợp lệ theo luật pickleball |
| 422 | INVALID_SET_WINNER | Không xác định được người thắng set (cả hai < 11 hoặc chênh < 2) |
| 422 | INVALID_MATCH_WINNER | best_of_3 nhưng không có người thắng majority |

### Business Rules

1. **Chỉ creator** (người tạo giải = trọng tài) mới được nhập điểm
2. **Validate pickleball scoring:**
   - Set thắng: >= 11 điểm VÀ dẫn >= 2 điểm
   - Nếu cả hai >= 10: phải chơi tiếp đến khi dẫn 2 (deuce)
   - `best_of_1`: đúng 1 set, người thắng set = người thắng trận
   - `best_of_3`: thắng 2/3 sets, KHÔNG chơi set 3 nếu đã 2-0
3. **Auto-update match status**: `scheduled` / `in_progress` → `completed`
4. **Winner computation**: server tự tính `winnerId` từ scores, client không gửi
5. **MatchScoreHistories logging**: mỗi lần nhập/sửa điểm đều log:
   ```json
   {
     "id": "history-uuid",
     "matchId": "match-uuid",
     "scores": [...],
     "action": "create",
     "changedBy": "creator-uuid",
     "createdAt": "2026-03-12T10:30:00Z"
   }
   ```
6. **SignalR realtime notification**: sau khi lưu điểm, broadcast tới `TournamentHub`:
   - Event: `match_score_updated`
   - Payload: `{ matchId, tournamentId, groupId, scores, winnerId, status }`
   - Tất cả client đang xem giải nhận được update ngay lập tức
7. **Auto-complete tournament**: nếu tất cả trận trong giải đều `completed` hoặc `walkover`, tự động chuyển tournament status → `completed`

---

## 5.4. PUT /matches/:id/score — Sửa điểm

### Summary
Creator sửa điểm trận đã nhập. Dùng khi phát hiện nhập sai. Validate tương tự endpoint 5.3. Log lịch sử sửa điểm.

### User Story
```
Là người tạo giải,
Tôi phát hiện đã nhập sai điểm cho một trận,
Tôi muốn sửa lại điểm chính xác,
Và hệ thống ghi lại lịch sử thay đổi.

Acceptance Criteria:
- Chỉ creator mới được sửa
- Trận phải đã có điểm (status = completed)
- Validate điểm giống endpoint 5.3
- Ghi log sửa đổi vào MatchScoreHistories (action: "update")
- Cập nhật winnerId nếu thay đổi
- Gửi SignalR notification
```

### Luồng xử lý

```
Creator                         Server                          Database
  │                               │                               │
  │  PUT /matches/:id/score      │                               │
  │  {scores: [{set:1,           │                               │
  │    p1:11, p2:9}, ...]}       │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Creator?                   │
  │                               │  ✓ Match status = completed?  │
  │                               │  ✓ Scores valid (same rules   │
  │                               │    as 5.3)?                   │
  │                               │                               │
  │                               │  UPDATE Match:                │
  │                               │  - scores = new [...]         │
  │                               │  - winnerId = recomputed      │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  INSERT MatchScoreHistories:  │
  │                               │  action: "update"             │
  │                               │  previousScores: old [...]    │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  SignalR → TournamentHub:     │
  │                               │  "match_score_updated"        │
  │                               │                               │
  │  200 {updated match}         │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Creator (tournament owner) | Sửa điểm |
| Others | ❌ Không có quyền |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Match ID |

**Body:**
```json
{
  "scores": [
    { "set": 1, "player1Score": 11, "player2Score": 9 },
    { "set": 2, "player1Score": 11, "player2Score": 6 }
  ],
  "reason": "Nhập nhầm điểm set 1"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| scores | array | ✅ | Tương tự 5.3 |
| reason | string | ❌ | Max 500 ký tự, lý do sửa điểm |

### Response

**200 OK:**
```json
{
  "data": {
    "id": "match-uuid",
    "groupId": "group-uuid-a",
    "groupName": "A",
    "round": 1,
    "matchOrder": 1,
    "status": "completed",
    "scoringFormat": "best_of_3",
    "player1": {
      "id": "participant-uuid-1",
      "name": "Nguyễn Văn A",
      "avatarUrl": "..."
    },
    "player2": {
      "id": "participant-uuid-2",
      "name": "Trần Văn B",
      "avatarUrl": "..."
    },
    "scores": [
      { "set": 1, "player1Score": 11, "player2Score": 9 },
      { "set": 2, "player1Score": 11, "player2Score": 6 }
    ],
    "winnerId": "participant-uuid-1",
    "setsWon": { "player1": 2, "player2": 0 },
    "updatedAt": "2026-03-12T11:00:00Z"
  }
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 403 | FORBIDDEN | Không phải creator |
| 404 | MATCH_NOT_FOUND | Match không tồn tại |
| 422 | MATCH_NOT_SCORED | Trận chưa có điểm (dùng POST để nhập) |
| 422 | INVALID_SET_COUNT | Số set không đúng |
| 422 | INVALID_SCORE | Điểm không hợp lệ theo luật pickleball |
| 422 | INVALID_SET_WINNER | Không xác định được người thắng set |
| 422 | INVALID_MATCH_WINNER | Không có người thắng majority |

### Business Rules

1. Chỉ sửa được trận đã `completed` — trận `walkover` KHÔNG sửa được
2. Validate điểm giống hệt endpoint 5.3
3. **MatchScoreHistories logging** với action = `"update"`:
   ```json
   {
     "id": "history-uuid",
     "matchId": "match-uuid",
     "scores": [/* new scores */],
     "previousScores": [/* old scores */],
     "action": "update",
     "reason": "Nhập nhầm điểm set 1",
     "changedBy": "creator-uuid",
     "createdAt": "2026-03-12T11:00:00Z"
   }
   ```
4. Nếu sửa điểm làm thay đổi `winnerId` → cập nhật lại
5. SignalR broadcast giống 5.3

---

## 5.5. GET /tournaments/:id/groups/:gid/standings — BXH bảng

### Summary
Tính và trả về bảng xếp hạng (standings) của một bảng đấu. BXH được tính realtime từ kết quả các trận đã hoàn thành trong bảng.

### User Story
```
Là người tham gia giải / người xem,
Tôi muốn xem bảng xếp hạng của mỗi bảng đấu,
Để biết ai đang dẫn đầu và cơ hội đi tiếp.

Acceptance Criteria:
- Hiển thị BXH theo thứ tự: hạng 1 → 4
- Mỗi dòng: tên, số trận thắng/thua, sets thắng/thua, điểm ghi/mất, hiệu số
- Cập nhật tự động sau mỗi trận
- Hiển thị rõ tiebreaker nếu có (2 người cùng số trận thắng)
- Highlight Nhất và Nhì bảng
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /tournaments/:id/        │                               │
  │      groups/:gid/standings    │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Tournament exists?          │
  │                               │  ✓ Group exists in tournament?│
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Query all completed matches  │
  │                               │  in this group                │
  │                               │<──────────────────────────────│
  │                               │                               │
  │                               │  === TÍNH BXH ===             │
  │                               │  For each member:             │
  │                               │  1. Đếm wins, losses          │
  │                               │  2. Tính sets won/lost        │
  │                               │  3. Tính points for/against   │
  │                               │  4. Tính point differential   │
  │                               │                               │
  │                               │  === XẾP HẠNG ===             │
  │                               │  Sort by:                     │
  │                               │  1. Wins (DESC)               │
  │                               │  2. Point differential (DESC) │
  │                               │  3. Head-to-head              │
  │                               │  4. Mini round-robin          │
  │                               │                               │
  │  200 {standings}              │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Authenticated user | Xem BXH |
| Creator | Xem BXH |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Tournament ID |
| gid | UUID | Group ID |

### Response

**200 OK:**
```json
{
  "data": {
    "groupId": "group-uuid-a",
    "groupName": "A",
    "matchesCompleted": 5,
    "totalMatches": 6,
    "standings": [
      {
        "rank": 1,
        "participant": {
          "id": "participant-uuid-1",
          "name": "Nguyễn Văn A",
          "avatarUrl": "..."
        },
        "played": 3,
        "wins": 3,
        "losses": 0,
        "setsWon": 6,
        "setsLost": 1,
        "pointsFor": 78,
        "pointsAgainst": 52,
        "pointDifferential": 26,
        "tiebreakerApplied": null,
        "isGroupWinner": true,
        "isGroupRunnerUp": false
      },
      {
        "rank": 2,
        "participant": {
          "id": "participant-uuid-2",
          "name": "Trần Văn B",
          "avatarUrl": "..."
        },
        "played": 3,
        "wins": 2,
        "losses": 1,
        "setsWon": 4,
        "setsLost": 3,
        "pointsFor": 68,
        "pointsAgainst": 60,
        "pointDifferential": 8,
        "tiebreakerApplied": null,
        "isGroupWinner": false,
        "isGroupRunnerUp": true
      },
      {
        "rank": 3,
        "participant": {
          "id": "participant-uuid-3",
          "name": "Lê Văn C",
          "avatarUrl": "..."
        },
        "played": 2,
        "wins": 1,
        "losses": 1,
        "setsWon": 2,
        "setsLost": 3,
        "pointsFor": 48,
        "pointsAgainst": 55,
        "pointDifferential": -7,
        "tiebreakerApplied": null,
        "isGroupWinner": false,
        "isGroupRunnerUp": false
      },
      {
        "rank": 4,
        "participant": {
          "id": "participant-uuid-4",
          "name": "Phạm Văn D",
          "avatarUrl": "..."
        },
        "played": 2,
        "wins": 0,
        "losses": 2,
        "setsWon": 0,
        "setsLost": 4,
        "pointsFor": 30,
        "pointsAgainst": 57,
        "pointDifferential": -27,
        "tiebreakerApplied": null,
        "isGroupWinner": false,
        "isGroupRunnerUp": false
      }
    ]
  }
}
```

**Mô tả fields:**

| Field | Type | Mô tả |
|-------|------|-------|
| rank | int | Thứ hạng trong bảng (1-4) |
| played | int | Số trận đã đấu |
| wins | int | Số trận thắng |
| losses | int | Số trận thua |
| setsWon | int | Tổng sets thắng |
| setsLost | int | Tổng sets thua |
| pointsFor | int | Tổng điểm ghi được |
| pointsAgainst | int | Tổng điểm bị ghi |
| pointDifferential | int | Hiệu số điểm (pointsFor - pointsAgainst) |
| tiebreakerApplied | string / null | Loại tiebreaker đã áp dụng (nếu có) |
| isGroupWinner | bool | Nhất bảng (chỉ khi đủ 6 trận) |
| isGroupRunnerUp | bool | Nhì bảng (chỉ khi đủ 6 trận) |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 404 | TOURNAMENT_NOT_FOUND | Giải không tồn tại |
| 404 | GROUP_NOT_FOUND | Bảng không tồn tại trong giải |

### Business Rules

1. **BXH tính realtime** từ kết quả các trận `completed` và `walkover` trong bảng
2. **Công thức tính:**
   - `wins` = số trận thắng (bao gồm walkover win)
   - `losses` = số trận thua
   - `setsWon/setsLost` = tổng hợp từ scores tất cả trận đã đấu
   - `pointsFor` = tổng điểm ghi được (tổng player score qua tất cả sets)
   - `pointsAgainst` = tổng điểm đối thủ ghi được
   - `pointDifferential` = pointsFor - pointsAgainst
3. **Thứ tự xếp hạng (Tiebreaker rules):**

   | Ưu tiên | Tiêu chí | Mô tả |
   |:-------:|----------|-------|
   | 1 | **Wins** (DESC) | Người thắng nhiều trận hơn xếp trên |
   | 2 | **Point differential** (DESC) | Nếu cùng wins → so hiệu số điểm |
   | 3 | **Head-to-head** | Nếu vẫn hòa → xét kết quả trực tiếp giữa 2 người |
   | 4 | **Mini round-robin** | Nếu >= 3 người cùng điểm → tính BXH riêng giữa họ |

4. **Tiebreaker detail:**
   - Head-to-head: xét trận đấu trực tiếp giữa 2 người cùng hạng, ai thắng xếp trên
   - Mini round-robin: khi 3+ người cùng wins VÀ cùng point diff → tạo bảng nhỏ chỉ từ các trận giữa họ, tính lại wins → point diff
   - `tiebreakerApplied` trả về `"point_differential"`, `"head_to_head"`, `"mini_round_robin"`, hoặc `null`
5. **isGroupWinner / isGroupRunnerUp** chỉ set `true` khi tất cả 6 trận trong bảng đã `completed` hoặc `walkover`
6. Walkover: người thắng walkover được tính 1 win, KHÔNG tính điểm (points = 0 cho cả hai)

---

## 5.6. GET /tournaments/:id/results — Kết quả tổng

### Summary
Lấy kết quả tổng hợp của toàn giải sau khi tất cả trận đã hoàn thành. Bao gồm xếp hạng tổng, nhất/nhì mỗi bảng, và thống kê giải.

### User Story
```
Là người tham gia giải / người xem,
Sau khi giải kết thúc, tôi muốn xem kết quả tổng hợp,
Bao gồm xếp hạng chung, thống kê, và thành tích cá nhân.

Acceptance Criteria:
- Hiển thị nhất/nhì mỗi bảng
- Xếp hạng tổng dựa trên thành tích trong bảng
- Thống kê giải: tổng trận, tổng điểm, trận hay nhất, v.v.
- Có thể xem khi giải đang in_progress (partial results)
- Kết quả cuối cùng khi tournament status = completed
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /tournaments/:id/results │                               │
  │──────────────────────────────>│                               │
  │                               │  Validate:                    │
  │                               │  ✓ Tournament exists?          │
  │                               │  ✓ Has groups?                │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  For each group:              │
  │                               │  → Compute standings (5.5)    │
  │                               │  → Identify winner, runner-up │
  │                               │<──────────────────────────────│
  │                               │                               │
  │                               │  Compute overall rankings:    │
  │                               │  1. All group winners          │
  │                               │  2. All group runners-up       │
  │                               │  3. 3rd place per group       │
  │                               │  4. 4th place per group       │
  │                               │  Within same rank: sort by    │
  │                               │  wins → point diff            │
  │                               │                               │
  │                               │  Compute tournament stats     │
  │                               │                               │
  │  200 {results}                │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Role | Quyền |
|------|-------|
| Authenticated user | Xem kết quả |
| Creator | Xem kết quả |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | Tournament ID |

### Response

**200 OK:**
```json
{
  "data": {
    "tournamentId": "tournament-uuid",
    "tournamentName": "Giải Mùa Xuân 2026",
    "status": "completed",
    "type": "singles",
    "scoringFormat": "best_of_3",
    "isFinalized": true,
    "groupResults": [
      {
        "groupId": "group-uuid-a",
        "groupName": "A",
        "matchesCompleted": 6,
        "totalMatches": 6,
        "winner": {
          "id": "participant-uuid-1",
          "name": "Nguyễn Văn A",
          "avatarUrl": "...",
          "wins": 3,
          "losses": 0,
          "pointDifferential": 26
        },
        "runnerUp": {
          "id": "participant-uuid-2",
          "name": "Trần Văn B",
          "avatarUrl": "...",
          "wins": 2,
          "losses": 1,
          "pointDifferential": 8
        },
        "standings": [
          {
            "rank": 1,
            "participant": { "id": "...", "name": "Nguyễn Văn A" },
            "wins": 3, "losses": 0, "pointDifferential": 26
          },
          {
            "rank": 2,
            "participant": { "id": "...", "name": "Trần Văn B" },
            "wins": 2, "losses": 1, "pointDifferential": 8
          },
          {
            "rank": 3,
            "participant": { "id": "...", "name": "Lê Văn C" },
            "wins": 1, "losses": 2, "pointDifferential": -7
          },
          {
            "rank": 4,
            "participant": { "id": "...", "name": "Phạm Văn D" },
            "wins": 0, "losses": 3, "pointDifferential": -27
          }
        ]
      },
      {
        "groupId": "group-uuid-b",
        "groupName": "B",
        "matchesCompleted": 6,
        "totalMatches": 6,
        "winner": {
          "id": "participant-uuid-5",
          "name": "Hoàng Văn E",
          "avatarUrl": "...",
          "wins": 3,
          "losses": 0,
          "pointDifferential": 30
        },
        "runnerUp": {
          "id": "participant-uuid-6",
          "name": "Đỗ Văn F",
          "avatarUrl": "...",
          "wins": 2,
          "losses": 1,
          "pointDifferential": 12
        },
        "standings": [
          { "rank": 1, "participant": { "id": "...", "name": "Hoàng Văn E" }, "wins": 3, "losses": 0, "pointDifferential": 30 },
          { "rank": 2, "participant": { "id": "...", "name": "Đỗ Văn F" }, "wins": 2, "losses": 1, "pointDifferential": 12 },
          { "rank": 3, "participant": { "id": "...", "name": "Vũ Văn G" }, "wins": 1, "losses": 2, "pointDifferential": -10 },
          { "rank": 4, "participant": { "id": "...", "name": "Bùi Văn H" }, "wins": 0, "losses": 3, "pointDifferential": -32 }
        ]
      }
    ],
    "overallRankings": [
      {
        "overallRank": 1,
        "participant": { "id": "participant-uuid-5", "name": "Hoàng Văn E", "avatarUrl": "..." },
        "groupName": "B",
        "groupRank": 1,
        "wins": 3,
        "losses": 0,
        "pointDifferential": 30
      },
      {
        "overallRank": 2,
        "participant": { "id": "participant-uuid-1", "name": "Nguyễn Văn A", "avatarUrl": "..." },
        "groupName": "A",
        "groupRank": 1,
        "wins": 3,
        "losses": 0,
        "pointDifferential": 26
      },
      {
        "overallRank": 3,
        "participant": { "id": "participant-uuid-6", "name": "Đỗ Văn F", "avatarUrl": "..." },
        "groupName": "B",
        "groupRank": 2,
        "wins": 2,
        "losses": 1,
        "pointDifferential": 12
      },
      {
        "overallRank": 4,
        "participant": { "id": "participant-uuid-2", "name": "Trần Văn B", "avatarUrl": "..." },
        "groupName": "A",
        "groupRank": 2,
        "wins": 2,
        "losses": 1,
        "pointDifferential": 8
      },
      {
        "overallRank": 5,
        "participant": { "id": "participant-uuid-3", "name": "Lê Văn C", "avatarUrl": "..." },
        "groupName": "A",
        "groupRank": 3,
        "wins": 1,
        "losses": 2,
        "pointDifferential": -7
      },
      {
        "overallRank": 6,
        "participant": { "id": "participant-uuid-7", "name": "Vũ Văn G", "avatarUrl": "..." },
        "groupName": "B",
        "groupRank": 3,
        "wins": 1,
        "losses": 2,
        "pointDifferential": -10
      },
      {
        "overallRank": 7,
        "participant": { "id": "participant-uuid-4", "name": "Phạm Văn D", "avatarUrl": "..." },
        "groupName": "A",
        "groupRank": 4,
        "wins": 0,
        "losses": 3,
        "pointDifferential": -27
      },
      {
        "overallRank": 8,
        "participant": { "id": "participant-uuid-8", "name": "Bùi Văn H", "avatarUrl": "..." },
        "groupName": "B",
        "groupRank": 4,
        "wins": 0,
        "losses": 3,
        "pointDifferential": -32
      }
    ],
    "statistics": {
      "totalMatches": 12,
      "completedMatches": 12,
      "walkovers": 0,
      "totalSetsPlayed": 30,
      "totalPointsScored": 612,
      "averagePointsPerSet": 20.4,
      "closestMatch": {
        "matchId": "match-uuid-x",
        "player1": { "id": "...", "name": "Trần Văn B" },
        "player2": { "id": "...", "name": "Lê Văn C" },
        "scores": [
          { "set": 1, "player1Score": 13, "player2Score": 11 },
          { "set": 2, "player1Score": 10, "player2Score": 12 },
          { "set": 3, "player1Score": 14, "player2Score": 12 }
        ]
      },
      "highestScore": {
        "matchId": "match-uuid-y",
        "set": 3,
        "score": "15-13",
        "player1": { "id": "...", "name": "..." },
        "player2": { "id": "...", "name": "..." }
      }
    }
  }
}
```

**Mô tả fields:**

| Field | Type | Mô tả |
|-------|------|-------|
| isFinalized | bool | `true` khi tournament status = `completed` |
| groupResults[] | array | Kết quả từng bảng |
| groupResults[].winner | object | Nhất bảng |
| groupResults[].runnerUp | object | Nhì bảng |
| groupResults[].standings[] | array | BXH đầy đủ của bảng |
| overallRankings[] | array | Xếp hạng tổng toàn giải |
| overallRankings[].overallRank | int | Hạng tổng |
| overallRankings[].groupRank | int | Hạng trong bảng |
| statistics | object | Thống kê giải |
| statistics.closestMatch | object | Trận sát nút nhất (tổng điểm chênh lệch thấp nhất) |
| statistics.highestScore | object | Set có tổng điểm cao nhất |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 404 | TOURNAMENT_NOT_FOUND | Giải không tồn tại |
| 422 | GROUPS_NOT_ASSIGNED | Chưa xếp bảng |

### Business Rules

1. **Có thể xem khi giải đang `in_progress`**: trả partial results, `isFinalized = false`
2. **isFinalized = true** chỉ khi tournament status = `completed` (tất cả trận xong)
3. **Overall rankings — Thuật toán xếp hạng tổng:**
   - Nhóm theo group rank: tất cả nhất bảng → nhì bảng → ba bảng → tư bảng
   - Trong cùng group rank, sắp xếp theo:
     1. Wins (DESC)
     2. Point differential (DESC)
     3. Sets won ratio (DESC)
   - Nhất bảng A vs Nhất bảng B: ai có thành tích tốt hơn xếp trên
4. **winner / runnerUp** chỉ set khi bảng đã hoàn thành đủ 6 trận
5. **statistics** tính từ tất cả trận `completed` (không tính `walkover`)
6. **closestMatch**: trận có tổng chênh lệch điểm giữa 2 bên thấp nhất qua tất cả sets
7. **highestScore**: set có tổng điểm (player1Score + player2Score) cao nhất
8. Giải doubles: participant chứa thông tin team thay vì cá nhân
