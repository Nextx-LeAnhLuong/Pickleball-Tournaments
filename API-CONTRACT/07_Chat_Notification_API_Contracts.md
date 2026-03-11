# Module 07: Chat & Notification — API Contracts

| Thông tin | Chi tiết |
|-----------|----------|
| **Module** | Chat & Notification (Chat 1-1, Group chat, Thông báo in-app, Push) |
| **Base URL** | `/api` |
| **Version** | 1.0 |
| **Ngày cập nhật** | 2026-03-12 |
| **Phase** | 1-2 |
| **Số endpoints** | 7 |
| **DB Tables** | ChatRooms, ChatMembers, Messages, Notifications, DeviceTokens |

---

## Endpoints Overview

| # | Method | Endpoint | Auth | Mô tả |
|---|--------|----------|:----:|-------|
| 7.1 | GET | `/chats` | ✅ Auth | Danh sách phòng chat |
| 7.2 | POST | `/chats` | ✅ Auth | Tạo phòng chat |
| 7.3 | GET | `/chats/:id/messages` | Member | Xem tin nhắn (paginated) |
| 7.4 | POST | `/chats/:id/messages` | Member | Gửi tin nhắn |
| 7.5 | GET | `/notifications` | ✅ Auth | Danh sách thông báo |
| 7.6 | PUT | `/notifications/:id/read` | ✅ Auth | Đánh dấu đã đọc |
| 7.7 | PUT | `/notifications/read-all` | ✅ Auth | Đọc tất cả thông báo |

---

## Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ CHAT FLOW                                                                   │
│                                                                             │
│ Client ──[REST API]──> Server ──┬──> PostgreSQL (lưu Messages, ChatRooms)  │
│                                 │                                           │
│                                 ├──> SignalR ChatHub ──> Real-time delivery │
│                                 │    (broadcast tới tất cả members online)  │
│                                 │                                           │
│                                 └──> FCM Push ──> Offline members           │
│                                      (qua DeviceTokens)                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ NOTIFICATION FLOW                                                           │
│                                                                             │
│ Event triggered ──> Server ──┬──> PostgreSQL (lưu Notifications)           │
│ (tournament_invite,          │                                              │
│  match_scheduled,            ├──> SignalR NotificationHub ──> Real-time     │
│  new_message, ...)           │    (badge count update, toast notification)  │
│                              │                                              │
│                              └──> FCM Push ──> Mobile push notification     │
│                                   (title + body + data payload)             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ IMAGE UPLOAD FLOW                                                           │
│                                                                             │
│ Client ──[Upload image]──> S3/MinIO ──> Nhận imageUrl                      │
│ Client ──[POST message với imageUrl]──> Server lưu + broadcast             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Enum Reference (Module 07)

| Enum | Values |
|------|--------|
| ChatRoomType | `direct`, `group` |
| MessageType | `text`, `image`, `system` |
| NotificationType | `tournament_invite`, `request_approved`, `request_rejected`, `tournament_started`, `match_scheduled`, `match_result`, `tournament_completed`, `tournament_cancelled`, `game_invite`, `new_message`, `new_follower` |

---

## 7.1. GET /chats — Danh sách phòng chat

### Summary
Lấy danh sách phòng chat của user hiện tại, sắp xếp theo tin nhắn mới nhất. Mỗi phòng kèm tin nhắn cuối và số tin chưa đọc.

### User Story
```
Là một người dùng đã đăng nhập,
Tôi muốn xem danh sách các phòng chat của mình,
Để biết ai đang nhắn tin và có tin nhắn nào chưa đọc.

Acceptance Criteria:
- Hiển thị tất cả phòng chat mà tôi là thành viên
- Sắp xếp theo lastMessageAt giảm dần
- Mỗi phòng hiển thị tin nhắn cuối cùng (preview)
- Hiển thị số tin nhắn chưa đọc (unreadCount) cho mỗi phòng
- Phòng direct: hiển thị tên + avatar đối phương
- Phòng group: hiển thị tên nhóm + số thành viên
- Hỗ trợ phân trang
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /chats?page=1&pageSize=20│                               │
  │──────────────────────────────>│                               │
  │                               │  Get current user from JWT    │
  │                               │                               │
  │                               │  SELECT ChatRooms             │
  │                               │  JOIN ChatMembers             │
  │                               │  WHERE userId = currentUser   │
  │                               │  ORDER BY lastMessageAt DESC  │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  For each room:               │
  │                               │  - Get last message           │
  │                               │  - Count unread messages      │
  │                               │  - Get other member info      │
  │                               │    (direct) or group info     │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  200 {chatRooms[]}            │                               │
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
| page | int | 1 | Trang hiện tại |
| pageSize | int | 20 | Số item/trang (max 50) |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "chatroom-uuid-1",
      "type": "direct",
      "name": null,
      "otherUser": {
        "id": "user-uuid-2",
        "name": "Nguyễn Văn B",
        "avatarUrl": "https://s3.example.com/avatars/user-2.jpg",
        "isOnline": true
      },
      "lastMessage": {
        "id": "msg-uuid",
        "content": "Hẹn gặp lúc 5h nhé!",
        "type": "text",
        "senderName": "Nguyễn Văn B",
        "createdAt": "2026-03-12T10:30:00Z"
      },
      "unreadCount": 3,
      "lastMessageAt": "2026-03-12T10:30:00Z",
      "createdAt": "2026-03-10T08:00:00Z"
    },
    {
      "id": "chatroom-uuid-2",
      "type": "group",
      "name": "Giải Pickleball Mùa Xuân",
      "avatarUrl": null,
      "memberCount": 8,
      "lastMessage": {
        "id": "msg-uuid-2",
        "content": "Lịch thi đấu đã được cập nhật",
        "type": "system",
        "senderName": "Hệ thống",
        "createdAt": "2026-03-12T09:00:00Z"
      },
      "unreadCount": 0,
      "lastMessageAt": "2026-03-12T09:00:00Z",
      "createdAt": "2026-03-08T14:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 5,
    "totalPages": 1
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID phòng chat |
| type | string | `direct` / `group` |
| name | string? | Tên nhóm (null nếu direct) |
| otherUser | object? | Thông tin đối phương (chỉ có ở direct) |
| memberCount | int? | Số thành viên (chỉ có ở group) |
| lastMessage | object? | Tin nhắn cuối cùng (null nếu chưa có tin) |
| unreadCount | int | Số tin nhắn chưa đọc |
| lastMessageAt | datetime? | Thời điểm tin nhắn cuối |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |

### Business Rules

1. Chỉ trả về phòng chat mà user là thành viên (ChatMembers)
2. Phòng direct: `otherUser` chứa thông tin người kia, `name` = null
3. Phòng group: `name` là tên nhóm, `memberCount` = số thành viên
4. `unreadCount` = số tin nhắn có `createdAt > ChatMembers.lastReadAt`
5. Sắp xếp mặc định theo `lastMessageAt DESC` (phòng có tin mới nhất lên đầu)
6. Phòng chưa có tin nhắn nào → `lastMessage = null`, xếp theo `createdAt`

---

## 7.2. POST /chats — Tạo phòng chat

### Summary
Tạo phòng chat mới. Với chat direct (1-1): nếu đã tồn tại phòng giữa 2 user thì trả về phòng cũ. Với group: creator tự động là admin.

### User Story
```
Là một người dùng,
Tôi muốn tạo cuộc trò chuyện với người khác hoặc tạo nhóm chat,
Để trao đổi thông tin về giải đấu, lịch thi đấu, v.v.

Acceptance Criteria:
- Direct chat: chỉ cần truyền userId của đối phương
- Direct chat: nếu đã tồn tại phòng giữa 2 người → trả về phòng cũ (không tạo mới)
- Group chat: truyền tên nhóm + danh sách memberIds
- Group chat: creator tự động trở thành admin
- Group chat: tối thiểu 2 thành viên (không tính creator)
- Tất cả members phải là user hợp lệ
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  POST /chats                  │                               │
  │  {type: "direct",             │                               │
  │   userId: "user-uuid-2"}      │                               │
  │──────────────────────────────>│                               │
  │                               │  Case: DIRECT                 │
  │                               │  Check existing room between  │
  │                               │  currentUser & userId         │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Found? → Return existing     │
  │                               │  Not found? → Create new:     │
  │                               │  1. ChatRoom (type: direct)   │
  │                               │  2. ChatMembers × 2           │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  200/201 {chatRoom}           │                               │
  │<──────────────────────────────│                               │

─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─

  │  POST /chats                  │                               │
  │  {type: "group",              │                               │
  │   name: "Nhóm A",            │                               │
  │   memberIds: [id1, id2, id3]}│                               │
  │──────────────────────────────>│                               │
  │                               │  Case: GROUP                  │
  │                               │  Validate all memberIds exist │
  │                               │  Create:                      │
  │                               │  1. ChatRoom (type: group)    │
  │                               │  2. ChatMember (creator,      │
  │                               │     role: admin)              │
  │                               │  3. ChatMembers × N           │
  │                               │     (role: member)            │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Send system message:         │
  │                               │  "X đã tạo nhóm"             │
  │                               │                               │
  │  201 {chatRoom}               │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Body — Direct chat:**
```json
{
  "type": "direct",
  "userId": "user-uuid-2"
}
```

**Body — Group chat:**
```json
{
  "type": "group",
  "name": "Giải Pickleball Mùa Xuân",
  "memberIds": [
    "user-uuid-2",
    "user-uuid-3",
    "user-uuid-4"
  ]
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| type | string | ✅ | `"direct"` / `"group"` |
| userId | UUID | ✅ (direct) | User đối phương (chỉ dùng cho direct) |
| name | string | ✅ (group) | 1-100 ký tự, tên nhóm chat |
| memberIds | UUID[] | ✅ (group) | 2-50 UUIDs, không bao gồm creator |

### Response

**200 OK (direct — phòng đã tồn tại):**
```json
{
  "data": {
    "id": "chatroom-uuid-1",
    "type": "direct",
    "name": null,
    "isExisting": true,
    "members": [
      {
        "id": "user-uuid-1",
        "name": "Nguyễn Văn A",
        "avatarUrl": "...",
        "role": "member"
      },
      {
        "id": "user-uuid-2",
        "name": "Trần Thị B",
        "avatarUrl": "...",
        "role": "member"
      }
    ],
    "createdAt": "2026-03-10T08:00:00Z"
  }
}
```

**201 Created (tạo mới):**
```json
{
  "data": {
    "id": "chatroom-uuid-new",
    "type": "group",
    "name": "Giải Pickleball Mùa Xuân",
    "isExisting": false,
    "members": [
      {
        "id": "user-uuid-1",
        "name": "Nguyễn Văn A",
        "avatarUrl": "...",
        "role": "admin"
      },
      {
        "id": "user-uuid-2",
        "name": "Trần Thị B",
        "avatarUrl": "...",
        "role": "member"
      },
      {
        "id": "user-uuid-3",
        "name": "Lê Văn C",
        "avatarUrl": "...",
        "role": "member"
      }
    ],
    "createdAt": "2026-03-12T11:00:00Z"
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID phòng chat |
| type | string | `direct` / `group` |
| name | string? | Tên nhóm (null nếu direct) |
| isExisting | boolean | `true` nếu trả về phòng đã tồn tại |
| members | array | Danh sách thành viên với role |
| members[].role | string | `admin` (creator của group) / `member` |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 404 | USER_NOT_FOUND | userId không tồn tại |
| 422 | INVALID_CHAT_TYPE | type không hợp lệ |
| 422 | CANNOT_CHAT_SELF | userId trùng với currentUser |
| 422 | MEMBER_NOT_FOUND | Một hoặc nhiều memberIds không tồn tại |
| 422 | TOO_FEW_MEMBERS | Group chat cần ít nhất 2 thành viên |
| 422 | TOO_MANY_MEMBERS | Vượt quá 50 thành viên |
| 422 | MISSING_GROUP_NAME | Group chat thiếu tên nhóm |

### Business Rules

1. **Direct chat**: Mỗi cặp user chỉ có tối đa 1 phòng direct. Nếu đã tồn tại → trả 200 + `isExisting: true`
2. **Direct chat**: Không tự chat với chính mình
3. **Group chat**: Creator tự động thêm vào danh sách members với `role: admin`
4. **Group chat**: Tối thiểu 2 members (không tính creator), tối đa 50 members
5. **Group chat**: Hệ thống gửi system message `"{creator.name} đã tạo nhóm"` khi tạo xong
6. `lastMessageAt` = null khi mới tạo (chưa có tin nhắn)

---

## 7.3. GET /chats/:id/messages — Xem tin nhắn

### Summary
Lấy danh sách tin nhắn trong phòng chat, phân trang theo cursor (dựa trên thời gian). Chỉ thành viên phòng mới xem được.

### User Story
```
Là thành viên của một phòng chat,
Tôi muốn xem lịch sử tin nhắn,
Để đọc lại nội dung cuộc trò chuyện.

Acceptance Criteria:
- Chỉ member của phòng mới xem được
- Tin nhắn mới nhất hiển thị trước (load từ dưới lên)
- Kéo lên (scroll up) → load thêm tin cũ hơn (cursor-based)
- Hiển thị tên, avatar người gửi
- Phân biệt tin text, image, system
- Tự động cập nhật lastReadAt khi gọi API này
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /chats/:id/messages      │                               │
  │  ?limit=30&before=cursor-id   │                               │
  │──────────────────────────────>│                               │
  │                               │  Check: currentUser is        │
  │                               │  member of chatRoom?          │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  SELECT Messages              │
  │                               │  WHERE chatRoomId = :id       │
  │                               │  AND createdAt < cursor       │
  │                               │  ORDER BY createdAt DESC      │
  │                               │  LIMIT 30                     │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Update ChatMembers           │
  │                               │  SET lastReadAt = NOW()       │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  200 {messages[], hasMore}    │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Member — phải là thành viên của phòng chat |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID phòng chat |

**Query Params:**

| Param | Type | Default | Mô tả |
|-------|------|---------|-------|
| limit | int | 30 | Số tin nhắn mỗi lần load (max 50) |
| before | UUID? | null | Lấy tin nhắn trước message ID này (cursor) |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "msg-uuid-5",
      "chatRoomId": "chatroom-uuid-1",
      "sender": {
        "id": "user-uuid-2",
        "name": "Trần Thị B",
        "avatarUrl": "https://s3.example.com/avatars/user-2.jpg"
      },
      "type": "text",
      "content": "Hẹn gặp lúc 5h nhé!",
      "imageUrl": null,
      "createdAt": "2026-03-12T10:30:00Z"
    },
    {
      "id": "msg-uuid-4",
      "chatRoomId": "chatroom-uuid-1",
      "sender": {
        "id": "user-uuid-1",
        "name": "Nguyễn Văn A",
        "avatarUrl": "https://s3.example.com/avatars/user-1.jpg"
      },
      "type": "image",
      "content": null,
      "imageUrl": "https://s3.example.com/chat/img-uuid.jpg",
      "createdAt": "2026-03-12T10:28:00Z"
    },
    {
      "id": "msg-uuid-3",
      "chatRoomId": "chatroom-uuid-1",
      "sender": null,
      "type": "system",
      "content": "Nguyễn Văn A đã tạo nhóm",
      "imageUrl": null,
      "createdAt": "2026-03-12T10:00:00Z"
    }
  ],
  "meta": {
    "limit": 30,
    "hasMore": true,
    "oldestMessageId": "msg-uuid-3"
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID tin nhắn |
| chatRoomId | UUID | ID phòng chat |
| sender | object? | Người gửi (null nếu system message) |
| type | string | `text` / `image` / `system` |
| content | string? | Nội dung text (null nếu image) |
| imageUrl | string? | URL ảnh (null nếu text/system) |
| createdAt | datetime | Thời điểm gửi |
| meta.hasMore | boolean | Còn tin nhắn cũ hơn không |
| meta.oldestMessageId | UUID? | ID tin nhắn cũ nhất trong page (dùng làm cursor tiếp theo) |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 403 | NOT_A_MEMBER | Không phải thành viên phòng chat |
| 404 | CHAT_ROOM_NOT_FOUND | Phòng chat không tồn tại |

### Business Rules

1. Chỉ member của phòng chat mới truy cập được
2. Phân trang dạng cursor: client gửi `before` = ID tin nhắn cũ nhất đã có → server trả tin cũ hơn
3. Lần đầu không truyền `before` → lấy tin mới nhất
4. `hasMore = true` khi còn tin nhắn cũ hơn để load
5. Gọi API này sẽ tự động update `ChatMembers.lastReadAt = NOW()` → giảm unreadCount
6. System message có `sender = null`
7. Tin nhắn sắp xếp `createdAt DESC` (mới nhất trước)

---

## 7.4. POST /chats/:id/messages — Gửi tin nhắn

### Summary
Gửi tin nhắn (text hoặc image) vào phòng chat. Tin nhắn được broadcast real-time qua SignalR ChatHub tới tất cả members online, đồng thời push notification qua FCM tới members offline.

### User Story
```
Là thành viên của một phòng chat,
Tôi muốn gửi tin nhắn text hoặc hình ảnh,
Để trao đổi thông tin với các thành viên khác.

Acceptance Criteria:
- Gửi được tin nhắn text (tối đa 2000 ký tự)
- Gửi được tin nhắn hình ảnh (upload trước lên S3, truyền imageUrl)
- Tin nhắn hiển thị real-time cho tất cả members online (SignalR)
- Members offline nhận push notification (FCM)
- lastMessageAt của ChatRoom được cập nhật
- Phòng chat xuất hiện lên đầu danh sách chat của tất cả members
```

### Luồng xử lý

```
Client                          Server                          Database/Services
  │                               │                               │
  │  POST /chats/:id/messages     │                               │
  │  {type:"text",                │                               │
  │   content:"Xin chào!"}       │                               │
  │──────────────────────────────>│                               │
  │                               │  Check: currentUser is        │
  │                               │  member of chatRoom?          │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Create Message record        │
  │                               │──────────────────────────────>│ PostgreSQL
  │                               │                               │
  │                               │  Update ChatRoom              │
  │                               │  SET lastMessageAt = NOW()    │
  │                               │──────────────────────────────>│ PostgreSQL
  │                               │                               │
  │                               │  Broadcast via SignalR        │
  │                               │  ChatHub.SendMessage()        │
  │                               │──────────────────────────────>│ SignalR
  │                               │  (tới tất cả members online) │
  │                               │                               │
  │                               │  Push notification via FCM    │
  │                               │  tới members OFFLINE          │
  │                               │  (query DeviceTokens)         │
  │                               │──────────────────────────────>│ FCM
  │                               │                               │
  │  201 {message}                │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Member — phải là thành viên của phòng chat |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID phòng chat |

**Body — Text message:**
```json
{
  "type": "text",
  "content": "Hẹn gặp lúc 5h chiều nhé!"
}
```

**Body — Image message:**
```json
{
  "type": "image",
  "imageUrl": "https://s3.example.com/chat/img-uuid.jpg"
}
```

| Field | Type | Required | Validation |
|-------|------|:--------:|------------|
| type | string | ✅ | `"text"` / `"image"` |
| content | string | ✅ (text) | 1-2000 ký tự, không được rỗng |
| imageUrl | string | ✅ (image) | URL hợp lệ, phải là domain S3/MinIO |

### Response

**201 Created:**
```json
{
  "data": {
    "id": "msg-uuid-new",
    "chatRoomId": "chatroom-uuid-1",
    "sender": {
      "id": "user-uuid-1",
      "name": "Nguyễn Văn A",
      "avatarUrl": "https://s3.example.com/avatars/user-1.jpg"
    },
    "type": "text",
    "content": "Hẹn gặp lúc 5h chiều nhé!",
    "imageUrl": null,
    "createdAt": "2026-03-12T11:00:00Z"
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID tin nhắn mới |
| chatRoomId | UUID | ID phòng chat |
| sender | object | Thông tin người gửi |
| type | string | `text` / `image` |
| content | string? | Nội dung text |
| imageUrl | string? | URL hình ảnh |
| createdAt | datetime | Thời điểm gửi |

### SignalR Event (ChatHub)

Khi tin nhắn được gửi thành công, server broadcast event tới tất cả members online trong phòng:

```
Hub: ChatHub
Method: ReceiveMessage
Group: chatroom-{chatRoomId}

Payload:
{
  "chatRoomId": "chatroom-uuid-1",
  "message": {
    "id": "msg-uuid-new",
    "sender": { "id": "...", "name": "...", "avatarUrl": "..." },
    "type": "text",
    "content": "Hẹn gặp lúc 5h chiều nhé!",
    "imageUrl": null,
    "createdAt": "2026-03-12T11:00:00Z"
  }
}
```

### FCM Push Notification (Offline members)

```json
{
  "notification": {
    "title": "Nguyễn Văn A",
    "body": "Hẹn gặp lúc 5h chiều nhé!"
  },
  "data": {
    "type": "new_message",
    "chatRoomId": "chatroom-uuid-1",
    "messageId": "msg-uuid-new"
  }
}
```

- Image message: `body = "📷 Đã gửi một hình ảnh"`

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 403 | NOT_A_MEMBER | Không phải thành viên phòng chat |
| 404 | CHAT_ROOM_NOT_FOUND | Phòng chat không tồn tại |
| 422 | INVALID_MESSAGE_TYPE | type không hợp lệ |
| 422 | CONTENT_REQUIRED | type=text nhưng content rỗng |
| 422 | IMAGE_URL_REQUIRED | type=image nhưng thiếu imageUrl |
| 422 | INVALID_IMAGE_URL | imageUrl không hợp lệ hoặc không phải domain cho phép |
| 422 | CONTENT_TOO_LONG | content vượt quá 2000 ký tự |

### Business Rules

1. Chỉ member gửi được tin nhắn
2. User KHÔNG tự gửi system message (type=system chỉ do server tạo)
3. Sau khi lưu message → update `ChatRoom.lastMessageAt = NOW()`
4. **SignalR broadcast**: Gửi tới tất cả members đang online trong phòng (bao gồm cả sender — client tự filter)
5. **FCM push**: Chỉ gửi tới members OFFLINE (không có active SignalR connection) — query `DeviceTokens` table
6. FCM push cho image message: body hiển thị `"📷 Đã gửi một hình ảnh"` thay vì URL
7. Image phải upload lên S3/MinIO trước, API này chỉ nhận URL
8. Rate limit: tối đa 30 tin nhắn / phút / user (chống spam)

---

## 7.5. GET /notifications — Danh sách thông báo

### Summary
Lấy danh sách thông báo của user hiện tại, hỗ trợ filter theo type và trạng thái đã đọc/chưa đọc. Response bao gồm tổng số thông báo chưa đọc.

### User Story
```
Là một người dùng,
Tôi muốn xem danh sách thông báo,
Để biết các sự kiện liên quan đến mình (mời giải, kết quả trận, tin nhắn mới, ...).

Acceptance Criteria:
- Hiển thị tất cả thông báo theo thứ tự mới nhất
- Filter theo loại thông báo (tournament_invite, match_result, ...)
- Filter theo trạng thái: đã đọc / chưa đọc
- Hiển thị tổng số thông báo chưa đọc (unreadCount)
- Hỗ trợ phân trang
- Mỗi thông báo có title, body, type, và data context (link tới resource)
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  GET /notifications           │                               │
  │  ?page=1&isRead=false         │                               │
  │──────────────────────────────>│                               │
  │                               │  Get current user from JWT    │
  │                               │                               │
  │                               │  SELECT Notifications         │
  │                               │  WHERE userId = currentUser   │
  │                               │  AND isRead = false (nếu có)  │
  │                               │  ORDER BY createdAt DESC      │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  COUNT(*) WHERE isRead=false  │
  │                               │  → unreadCount                │
  │                               │──────────────────────────────>│
  │                               │                               │
  │  200 {notifications[],        │                               │
  │       meta, unreadCount}      │                               │
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
| page | int | 1 | Trang hiện tại |
| pageSize | int | 20 | Số item/trang (max 50) |
| type | string? | null | Filter theo NotificationType |
| isRead | boolean? | null | `true` = đã đọc, `false` = chưa đọc, null = tất cả |

### Response

**200 OK:**
```json
{
  "data": [
    {
      "id": "notif-uuid-1",
      "type": "tournament_invite",
      "title": "Lời mời tham gia giải",
      "body": "Nguyễn Văn A mời bạn tham gia giải Pickleball Mùa Xuân",
      "isRead": false,
      "data": {
        "tournamentId": "tournament-uuid",
        "inviterId": "user-uuid-1"
      },
      "createdAt": "2026-03-12T10:00:00Z"
    },
    {
      "id": "notif-uuid-2",
      "type": "match_scheduled",
      "title": "Lịch thi đấu mới",
      "body": "Trận đấu của bạn vs Trần B được xếp lúc 14:00 ngày 15/03",
      "isRead": false,
      "data": {
        "matchId": "match-uuid",
        "tournamentId": "tournament-uuid"
      },
      "createdAt": "2026-03-12T09:30:00Z"
    },
    {
      "id": "notif-uuid-3",
      "type": "new_follower",
      "title": "Người theo dõi mới",
      "body": "Lê Văn C đã bắt đầu theo dõi bạn",
      "isRead": true,
      "data": {
        "followerId": "user-uuid-3"
      },
      "createdAt": "2026-03-11T18:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "pageSize": 20,
    "totalCount": 15,
    "totalPages": 1,
    "unreadCount": 8
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID thông báo |
| type | string | Loại thông báo (NotificationType enum) |
| title | string | Tiêu đề thông báo |
| body | string | Nội dung chi tiết |
| isRead | boolean | Đã đọc chưa |
| data | object | Context data — chứa IDs liên quan (tournamentId, matchId, ...) |
| createdAt | datetime | Thời điểm tạo |
| meta.unreadCount | int | Tổng số thông báo chưa đọc (không phụ thuộc filter) |

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 422 | INVALID_NOTIFICATION_TYPE | type filter không hợp lệ |

### Business Rules

1. Chỉ trả thông báo của user hiện tại
2. Sắp xếp mặc định `createdAt DESC`
3. `unreadCount` trong meta luôn là tổng số chưa đọc của user (KHÔNG bị ảnh hưởng bởi filter)
4. `data` chứa context để client navigate tới resource liên quan (VD: click vào tournament_invite → mở trang giải)
5. Thông báo được tạo bởi server khi có sự kiện (không có API tạo thông báo trực tiếp)
6. Thông báo cũ hơn 90 ngày có thể bị xóa tự động (background job)

### NotificationType — Chi tiết data payload

| Type | data fields | Mô tả |
|------|-------------|-------|
| `tournament_invite` | tournamentId, inviterId | Được mời vào giải |
| `request_approved` | tournamentId | Yêu cầu tham gia được duyệt |
| `request_rejected` | tournamentId, reason? | Yêu cầu tham gia bị từ chối |
| `tournament_started` | tournamentId | Giải bắt đầu thi đấu |
| `match_scheduled` | matchId, tournamentId | Lịch trận đấu mới |
| `match_result` | matchId, tournamentId | Kết quả trận đấu |
| `tournament_completed` | tournamentId | Giải hoàn thành |
| `tournament_cancelled` | tournamentId, reason? | Giải bị hủy |
| `game_invite` | gameId, inviterId | Được mời vào game giao hữu |
| `new_message` | chatRoomId, senderId | Tin nhắn mới (khi offline) |
| `new_follower` | followerId | Có người theo dõi mới |

---

## 7.6. PUT /notifications/:id/read — Đánh dấu đã đọc

### Summary
Đánh dấu một thông báo cụ thể là đã đọc.

### User Story
```
Là một người dùng,
Khi tôi mở xem một thông báo,
Tôi muốn thông báo đó được đánh dấu đã đọc,
Để biết thông báo nào mới và chưa xem.

Acceptance Criteria:
- Đánh dấu đúng thông báo của mình
- Không đánh dấu được thông báo của người khác
- Nếu đã đọc rồi → vẫn trả 200 (idempotent)
- unreadCount giảm (real-time update qua SignalR)
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  PUT /notifications/:id/read  │                               │
  │──────────────────────────────>│                               │
  │                               │  Check: notification belongs  │
  │                               │  to currentUser?              │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  UPDATE Notifications         │
  │                               │  SET isRead = true,           │
  │                               │      readAt = NOW()           │
  │                               │  WHERE id = :id               │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Broadcast unreadCount update │
  │                               │  via NotificationHub          │
  │                               │                               │
  │  200 {notification}           │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Owner — chỉ đánh dấu thông báo của chính mình |

### Request

**Path Params:**

| Param | Type | Mô tả |
|-------|------|-------|
| id | UUID | ID thông báo |

**Body:** Không có

### Response

**200 OK:**
```json
{
  "data": {
    "id": "notif-uuid-1",
    "type": "tournament_invite",
    "title": "Lời mời tham gia giải",
    "body": "Nguyễn Văn A mời bạn tham gia giải Pickleball Mùa Xuân",
    "isRead": true,
    "readAt": "2026-03-12T11:00:00Z",
    "data": {
      "tournamentId": "tournament-uuid",
      "inviterId": "user-uuid-1"
    },
    "createdAt": "2026-03-12T10:00:00Z"
  }
}
```

### SignalR Event (NotificationHub)

```
Hub: NotificationHub
Method: UnreadCountUpdated
Target: user-{userId}

Payload:
{
  "unreadCount": 7
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |
| 403 | FORBIDDEN | Thông báo không thuộc về user hiện tại |
| 404 | NOTIFICATION_NOT_FOUND | Thông báo không tồn tại |

### Business Rules

1. Idempotent: gọi nhiều lần với thông báo đã đọc → vẫn trả 200, không lỗi
2. `readAt` được set = thời điểm gọi API (lần đầu)
3. Sau khi đánh dấu → broadcast `unreadCount` mới qua SignalR NotificationHub

---

## 7.7. PUT /notifications/read-all — Đọc tất cả thông báo

### Summary
Đánh dấu tất cả thông báo chưa đọc của user là đã đọc.

### User Story
```
Là một người dùng,
Khi có quá nhiều thông báo chưa đọc,
Tôi muốn đánh dấu tất cả là đã đọc cùng lúc,
Để "dọn dẹp" danh sách thông báo.

Acceptance Criteria:
- Đánh dấu TẤT CẢ thông báo chưa đọc → isRead = true
- unreadCount reset về 0
- Nếu không có thông báo chưa đọc → vẫn trả 200
- Real-time update unreadCount qua SignalR
```

### Luồng xử lý

```
Client                          Server                          Database
  │                               │                               │
  │  PUT /notifications/read-all  │                               │
  │──────────────────────────────>│                               │
  │                               │  UPDATE Notifications         │
  │                               │  SET isRead = true,           │
  │                               │      readAt = NOW()           │
  │                               │  WHERE userId = currentUser   │
  │                               │  AND isRead = false           │
  │                               │──────────────────────────────>│
  │                               │                               │
  │                               │  Broadcast unreadCount = 0    │
  │                               │  via NotificationHub          │
  │                               │                               │
  │  200 {updatedCount}           │                               │
  │<──────────────────────────────│                               │
```

### Auth & Role

| Yêu cầu | Chi tiết |
|----------|----------|
| Auth | ✅ Bearer Token (JWT) |
| Role | Bất kỳ user đã đăng nhập |

### Request

**Body:** Không có

### Response

**200 OK:**
```json
{
  "data": {
    "updatedCount": 8,
    "unreadCount": 0
  }
}
```

| Field | Type | Mô tả |
|-------|------|-------|
| updatedCount | int | Số thông báo vừa được đánh dấu đã đọc |
| unreadCount | int | Tổng số chưa đọc sau khi cập nhật (luôn = 0) |

### SignalR Event (NotificationHub)

```
Hub: NotificationHub
Method: UnreadCountUpdated
Target: user-{userId}

Payload:
{
  "unreadCount": 0
}
```

### Error Codes

| HTTP | Error Type | Điều kiện |
|:----:|-----------|-----------|
| 401 | UNAUTHORIZED | Chưa đăng nhập |

### Business Rules

1. Idempotent: gọi khi không có thông báo chưa đọc → `updatedCount = 0`, vẫn trả 200
2. Chỉ update thông báo của user hiện tại
3. `readAt` set cho tất cả thông báo = thời điểm gọi API
4. Broadcast `unreadCount = 0` qua SignalR NotificationHub sau khi update
