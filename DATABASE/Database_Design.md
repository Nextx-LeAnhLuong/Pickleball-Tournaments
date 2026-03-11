# PICKLEBALL APP — DATABASE DESIGN
## Tài Liệu Thiết Kế Cơ Sở Dữ Liệu

**Phiên bản:** 1.0
**Ngày:** Tháng 3, 2026
**Database:** PostgreSQL 16
**ORM:** Entity Framework Core 8

---

## MỤC LỤC

1. [Tổng quan](#1-tổng-quan)
2. [ERD — Sơ đồ quan hệ thực thể](#2-erd)
3. [Chi tiết từng bảng](#3-chi-tiết-từng-bảng)
4. [Indexes & Performance](#4-indexes--performance)
5. [Migrations Strategy](#5-migrations-strategy)
6. [Seed Data](#6-seed-data)
7. [Quy tắc & Ràng buộc nghiệp vụ](#7-quy-tắc--ràng-buộc-nghiệp-vụ)

---

## 1. Tổng Quan

### 1.1. Danh sách bảng

| # | Bảng | Module | Mô tả | Phase |
|---|------|--------|--------|:-----:|
| 1 | Users | Auth & Profile | Người dùng | 1 |
| 2 | RefreshTokens | Auth | Token làm mới | 1 |
| 3 | Follows | Profile | Quan hệ theo dõi | 2 |
| 4 | Tournaments | Tournament | Giải đấu | 1 |
| 5 | Participants | Tournament | Người tham gia giải | 1 |
| 6 | Teams | Tournament (Doubles) | Đội (đấu đôi) | 1 |
| 7 | Groups | Tournament | Bảng đấu | 1 |
| 8 | GroupMembers | Tournament | Thành viên bảng | 1 |
| 9 | Matches | Match & Scoring | Trận đấu | 1 |
| 10 | MatchScoreHistories | Match & Scoring | Lịch sử sửa điểm | 1 |
| 11 | CommunityGames | Community | Game cộng đồng | 2 |
| 12 | GameParticipants | Community | Người tham gia game | 2 |
| 13 | ChatRooms | Chat | Phòng chat | 2 |
| 14 | ChatMembers | Chat | Thành viên phòng chat | 2 |
| 15 | Messages | Chat | Tin nhắn | 2 |
| 16 | Notifications | Notification | Thông báo | 1 |
| 17 | DeviceTokens | Notification | FCM tokens | 1 |

---

## 2. ERD — Sơ Đồ Quan Hệ Thực Thể

### 2.1. Module chính (Phase 1)

```
┌──────────────┐
│    Users     │
│──────────────│
│ Id        PK │──┐
│ Email        │  │
│ PasswordHash │  │
│ Name         │  │    ┌──────────────────┐
│ AvatarUrl    │  │    │   Tournaments    │
│ Bio          │  │    │──────────────────│
│ SkillLevel   │  ├───>│ CreatorId     FK │
│ DominantHand │  │    │ Id            PK │──┐
│ PaddleType   │  │    │ Name             │  │
│ CreatedAt    │  │    │ Type             │  │
│ UpdatedAt    │  │    │ NumGroups        │  │
└──────────────┘  │    │ ScoringFormat    │  │
                  │    │ Status           │  │
                  │    │ Date             │  │
                  │    │ Location         │  │
                  │    └──────────────────┘  │
                  │                          │
                  │    ┌──────────────────┐  │
                  │    │  Participants    │  │
                  │    │──────────────────│  │
                  ├───>│ UserId        FK │  │
                  │    │ TournamentId  FK │<─┤
                  │    │ Status           │  │
                  │    │ JoinedAt         │  │
                  │    └──────────────────┘  │
                  │                          │
                  │    ┌──────────────────┐  │
                  │    │     Teams        │  │
                  │    │──────────────────│  │
                  ├───>│ Player1Id     FK │  │
                  ├───>│ Player2Id     FK │  │
                  │    │ TournamentId  FK │<─┤
                  │    │ Name             │  │
                  │    └──────────────────┘  │
                  │                          │
                  │    ┌──────────────────┐  │     ┌──────────────────┐
                  │    │    Groups        │  │     │  GroupMembers    │
                  │    │──────────────────│  │     │──────────────────│
                  │    │ Id            PK │──┼────>│ GroupId       FK │
                  │    │ TournamentId  FK │<─┤     │ PlayerId      FK │←── Users.Id (singles)
                  │    │ Name             │  │     │ TeamId        FK │←── Teams.Id (doubles)
                  │    │ DisplayOrder     │  │     │ SeedOrder        │
                  │    └──────────────────┘  │     └──────────────────┘
                  │                          │
                  │    ┌──────────────────┐  │
                  │    │    Matches       │  │
                  │    │──────────────────│  │
                  │    │ Id            PK │  │
                  │    │ TournamentId  FK │<─┘
                  │    │ GroupId       FK │←── Groups.Id
                  │    │ Round            │
                  │    │ MatchOrder       │
                  │    │ Player1Id        │←── Users.Id hoặc Teams.Id
                  │    │ Player2Id        │←── Users.Id hoặc Teams.Id
                  │    │ Player1Scores    │  (JSONB)
                  │    │ Player2Scores    │  (JSONB)
                  │    │ WinnerId         │
                  │    │ Status           │
                  │    └──────────────────┘
```

### 2.2. Module mở rộng (Phase 2)

```
┌──────────────┐         ┌──────────────────┐
│    Users     │         │  CommunityGames  │
│──────────────│         │──────────────────│
│ Id        PK │────────>│ CreatorId     FK │
└──────────────┘         │ Id            PK │──┐     ┌────────────────────┐
      │                  │ Title            │  │     │ GameParticipants   │
      │                  │ Date             │  │     │────────────────────│
      │                  │ Location         │  ├────>│ GameId          FK │
      │                  │ Lat, Lng         │  │     │ UserId          FK │←── Users.Id
      │                  │ MaxPlayers       │  │     │ Status             │
      │                  │ SkillLevel       │  │     │ JoinedAt           │
      │                  │ Status           │  │     └────────────────────┘
      │                  └──────────────────┘  │
      │                                        │
      │    ┌──────────────────┐                │
      │    │   ChatRooms      │                │
      │    │──────────────────│                │
      │    │ Id            PK │──┐             │
      │    │ Type             │  │   ┌──────────────────┐
      │    │ Name             │  │   │  ChatMembers     │
      │    └──────────────────┘  │   │──────────────────│
      │                          ├──>│ RoomId        FK │
      ├─────────────────────────────>│ UserId        FK │
      │                          │   │ JoinedAt         │
      │                          │   │ MutedUntil       │
      │                          │   └──────────────────┘
      │                          │
      │    ┌──────────────────┐  │
      │    │   Messages       │  │
      │    │──────────────────│  │
      ├───>│ SenderId      FK │  │
      │    │ RoomId        FK │<─┘
      │    │ Content          │
      │    │ Type             │
      │    │ ReadBy           │  (JSONB)
      │    │ CreatedAt        │
      │    └──────────────────┘
      │
      │    ┌──────────────────┐    ┌──────────────────┐
      │    │  Notifications   │    │  DeviceTokens    │
      │    │──────────────────│    │──────────────────│
      ├───>│ UserId        FK │    │ UserId        FK │←── Users.Id
           │ Type             │    │ Token             │
           │ Title            │    │ Platform          │  (ios, android, web)
           │ Body             │    │ CreatedAt         │
           │ Data             │    └──────────────────┘
           │ IsRead           │
           │ CreatedAt        │
           └──────────────────┘

┌──────────────┐
│   Follows    │
│──────────────│
│ FollowerId FK│←── Users.Id
│ FollowingId FK│←── Users.Id
│ CreatedAt    │
└──────────────┘
```

---

## 3. Chi Tiết Từng Bảng

### 3.1. Users

Bảng người dùng chính, lưu thông tin tài khoản và hồ sơ.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| Email | VARCHAR(255) | ❌ | | Email đăng nhập, unique |
| PasswordHash | VARCHAR(255) | ❌ | | bcrypt hash |
| Name | VARCHAR(100) | ❌ | | Tên hiển thị |
| AvatarUrl | VARCHAR(500) | ✅ | NULL | Link ảnh đại diện S3 |
| Bio | TEXT | ✅ | NULL | Tiểu sử ngắn |
| SkillLevel | DECIMAL(2,1) | ❌ | 3.0 | Trình độ 1.0-5.0 |
| DominantHand | VARCHAR(10) | ✅ | NULL | `'left'` / `'right'` |
| PaddleType | VARCHAR(100) | ✅ | NULL | Loại vợt |
| Provider | VARCHAR(20) | ✅ | NULL | `'local'` / `'google'` / `'apple'` |
| ProviderId | VARCHAR(255) | ✅ | NULL | ID từ OAuth provider |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | Ngày tạo |
| UpdatedAt | TIMESTAMPTZ | ❌ | `NOW()` | Ngày cập nhật |

**Constraints:**
- `PK_Users` PRIMARY KEY (Id)
- `UQ_Users_Email` UNIQUE (Email)
- `CK_Users_SkillLevel` CHECK (SkillLevel >= 1.0 AND SkillLevel <= 5.0)
- `CK_Users_DominantHand` CHECK (DominantHand IN ('left', 'right') OR DominantHand IS NULL)

```sql
CREATE TABLE "Users" (
    "Id"            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "Email"         VARCHAR(255) NOT NULL,
    "PasswordHash"  VARCHAR(255) NOT NULL,
    "Name"          VARCHAR(100) NOT NULL,
    "AvatarUrl"     VARCHAR(500),
    "Bio"           TEXT,
    "SkillLevel"    DECIMAL(2,1) NOT NULL DEFAULT 3.0,
    "DominantHand"  VARCHAR(10),
    "PaddleType"    VARCHAR(100),
    "Provider"      VARCHAR(20),
    "ProviderId"    VARCHAR(255),
    "CreatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Users_Email" UNIQUE ("Email"),
    CONSTRAINT "CK_Users_SkillLevel" CHECK ("SkillLevel" >= 1.0 AND "SkillLevel" <= 5.0),
    CONSTRAINT "CK_Users_DominantHand" CHECK ("DominantHand" IN ('left', 'right') OR "DominantHand" IS NULL)
);
```

---

### 3.2. RefreshTokens

Lưu refresh token để cấp lại access token. Mỗi user có thể có nhiều refresh token (multi-device).

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| UserId | UUID | ❌ | | FK → Users |
| TokenHash | VARCHAR(500) | ❌ | | Hash của refresh token |
| ExpiresAt | TIMESTAMPTZ | ❌ | | Thời điểm hết hạn |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | Ngày tạo |
| RevokedAt | TIMESTAMPTZ | ✅ | NULL | Ngày bị thu hồi |
| ReplacedByTokenId | UUID | ✅ | NULL | Token thay thế (rotation) |

```sql
CREATE TABLE "RefreshTokens" (
    "Id"                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "UserId"            UUID NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "TokenHash"         VARCHAR(500) NOT NULL,
    "ExpiresAt"         TIMESTAMPTZ NOT NULL,
    "CreatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "RevokedAt"         TIMESTAMPTZ,
    "ReplacedByTokenId" UUID REFERENCES "RefreshTokens"("Id")
);

CREATE INDEX "IX_RefreshTokens_UserId" ON "RefreshTokens"("UserId");
CREATE INDEX "IX_RefreshTokens_TokenHash" ON "RefreshTokens"("TokenHash");
```

---

### 3.3. Follows

Quan hệ theo dõi giữa users (many-to-many).

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| FollowerId | UUID | ❌ | | Người theo dõi → Users |
| FollowingId | UUID | ❌ | | Người được theo dõi → Users |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | Ngày theo dõi |

```sql
CREATE TABLE "Follows" (
    "Id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "FollowerId"  UUID NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "FollowingId" UUID NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "CreatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Follows_Pair" UNIQUE ("FollowerId", "FollowingId"),
    CONSTRAINT "CK_Follows_NoSelfFollow" CHECK ("FollowerId" != "FollowingId")
);

CREATE INDEX "IX_Follows_FollowerId" ON "Follows"("FollowerId");
CREATE INDEX "IX_Follows_FollowingId" ON "Follows"("FollowingId");
```

---

### 3.4. Tournaments

Bảng chính lưu thông tin giải đấu.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| CreatorId | UUID | ❌ | | FK → Users (người tạo giải) |
| Name | VARCHAR(200) | ❌ | | Tên giải đấu |
| Description | TEXT | ✅ | NULL | Mô tả chi tiết |
| Type | VARCHAR(10) | ❌ | | `'singles'` / `'doubles'` |
| NumGroups | INTEGER | ❌ | | Số bảng đấu |
| ScoringFormat | VARCHAR(15) | ❌ | `'best_of_3'` | `'best_of_1'` / `'best_of_3'` |
| Status | VARCHAR(15) | ❌ | `'draft'` | Trạng thái giải |
| Date | DATE | ✅ | NULL | Ngày thi đấu |
| Location | VARCHAR(500) | ✅ | NULL | Địa điểm |
| BannerUrl | VARCHAR(500) | ✅ | NULL | Ảnh bìa S3 |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |
| UpdatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

**Business Rules:**
- Singles: NumGroups ∈ {1, 2, 3, 4} → max 16 người
- Doubles: NumGroups ∈ {1, 2} → max 8 đội (16 người)

```sql
CREATE TABLE "Tournaments" (
    "Id"            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "CreatorId"     UUID NOT NULL REFERENCES "Users"("Id"),
    "Name"          VARCHAR(200) NOT NULL,
    "Description"   TEXT,
    "Type"          VARCHAR(10) NOT NULL,
    "NumGroups"     INTEGER NOT NULL,
    "ScoringFormat" VARCHAR(15) NOT NULL DEFAULT 'best_of_3',
    "Status"        VARCHAR(15) NOT NULL DEFAULT 'draft',
    "Date"          DATE,
    "Location"      VARCHAR(500),
    "BannerUrl"     VARCHAR(500),
    "CreatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Tournaments_Type" CHECK ("Type" IN ('singles', 'doubles')),
    CONSTRAINT "CK_Tournaments_ScoringFormat" CHECK ("ScoringFormat" IN ('best_of_1', 'best_of_3')),
    CONSTRAINT "CK_Tournaments_Status" CHECK ("Status" IN ('draft', 'open', 'ready', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT "CK_Tournaments_NumGroups" CHECK (
        ("Type" = 'singles' AND "NumGroups" BETWEEN 1 AND 4) OR
        ("Type" = 'doubles' AND "NumGroups" BETWEEN 1 AND 2)
    )
);

CREATE INDEX "IX_Tournaments_CreatorId" ON "Tournaments"("CreatorId");
CREATE INDEX "IX_Tournaments_Status" ON "Tournaments"("Status");
CREATE INDEX "IX_Tournaments_Date" ON "Tournaments"("Date");
CREATE INDEX "IX_Tournaments_Status_Date" ON "Tournaments"("Status", "Date" DESC);
```

---

### 3.5. Participants

Quan hệ nhiều-nhiều giữa Users và Tournaments, kèm trạng thái tham gia.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| TournamentId | UUID | ❌ | | FK → Tournaments |
| UserId | UUID | ❌ | | FK → Users |
| Status | VARCHAR(20) | ❌ | `'request_pending'` | Trạng thái |
| InvitedBy | UUID | ✅ | NULL | FK → Users (người mời, NULL nếu tự xin) |
| RejectReason | VARCHAR(500) | ✅ | NULL | Lý do từ chối |
| JoinedAt | TIMESTAMPTZ | ✅ | NULL | Thời điểm xác nhận tham gia |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

**Status flow:**
```
invited_pending → confirmed (chấp nhận lời mời)
invited_pending → rejected  (từ chối lời mời)
request_pending → confirmed (creator duyệt)
request_pending → rejected  (creator từ chối)
```

```sql
CREATE TABLE "Participants" (
    "Id"           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "TournamentId" UUID NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "UserId"       UUID NOT NULL REFERENCES "Users"("Id"),
    "Status"       VARCHAR(20) NOT NULL DEFAULT 'request_pending',
    "InvitedBy"    UUID REFERENCES "Users"("Id"),
    "RejectReason" VARCHAR(500),
    "JoinedAt"     TIMESTAMPTZ,
    "CreatedAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Participants_Tournament_User" UNIQUE ("TournamentId", "UserId"),
    CONSTRAINT "CK_Participants_Status" CHECK ("Status" IN ('confirmed', 'invited_pending', 'request_pending', 'rejected'))
);

CREATE INDEX "IX_Participants_TournamentId" ON "Participants"("TournamentId");
CREATE INDEX "IX_Participants_UserId" ON "Participants"("UserId");
CREATE INDEX "IX_Participants_Tournament_Status" ON "Participants"("TournamentId", "Status");
```

---

### 3.6. Teams (chỉ Doubles)

Đội trong giải đấu đôi. Mỗi đội 2 người chơi.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| TournamentId | UUID | ❌ | | FK → Tournaments |
| Name | VARCHAR(100) | ✅ | NULL | Tên đội (tự chọn hoặc auto) |
| Player1Id | UUID | ❌ | | FK → Users |
| Player2Id | UUID | ❌ | | FK → Users |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "Teams" (
    "Id"           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "TournamentId" UUID NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "Name"         VARCHAR(100),
    "Player1Id"    UUID NOT NULL REFERENCES "Users"("Id"),
    "Player2Id"    UUID NOT NULL REFERENCES "Users"("Id"),
    "CreatedAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Teams_DifferentPlayers" CHECK ("Player1Id" != "Player2Id")
);

CREATE INDEX "IX_Teams_TournamentId" ON "Teams"("TournamentId");
```

---

### 3.7. Groups (Bảng đấu)

Mỗi giải có N bảng, mỗi bảng 4 đơn vị thi đấu.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| TournamentId | UUID | ❌ | | FK → Tournaments |
| Name | VARCHAR(10) | ❌ | | `'A'`, `'B'`, `'C'`, `'D'` |
| DisplayOrder | INTEGER | ❌ | | Thứ tự hiển thị |

```sql
CREATE TABLE "Groups" (
    "Id"           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "TournamentId" UUID NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "Name"         VARCHAR(10) NOT NULL,
    "DisplayOrder" INTEGER NOT NULL,

    CONSTRAINT "UQ_Groups_Tournament_Name" UNIQUE ("TournamentId", "Name"),
    CONSTRAINT "UQ_Groups_Tournament_Order" UNIQUE ("TournamentId", "DisplayOrder")
);

CREATE INDEX "IX_Groups_TournamentId" ON "Groups"("TournamentId");
```

---

### 3.8. GroupMembers

Thành viên của mỗi bảng. Lưu player (Singles) hoặc team (Doubles).

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| GroupId | UUID | ❌ | | FK → Groups |
| PlayerId | UUID | ✅ | NULL | FK → Users (Singles), NULL nếu Doubles |
| TeamId | UUID | ✅ | NULL | FK → Teams (Doubles), NULL nếu Singles |
| SeedOrder | INTEGER | ❌ | | Thứ tự seed (1-4) |

```sql
CREATE TABLE "GroupMembers" (
    "Id"        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "GroupId"   UUID NOT NULL REFERENCES "Groups"("Id") ON DELETE CASCADE,
    "PlayerId"  UUID REFERENCES "Users"("Id"),
    "TeamId"    UUID REFERENCES "Teams"("Id"),
    "SeedOrder" INTEGER NOT NULL,

    CONSTRAINT "CK_GroupMembers_OneType" CHECK (
        ("PlayerId" IS NOT NULL AND "TeamId" IS NULL) OR
        ("PlayerId" IS NULL AND "TeamId" IS NOT NULL)
    ),
    CONSTRAINT "CK_GroupMembers_SeedOrder" CHECK ("SeedOrder" BETWEEN 1 AND 4)
);

CREATE INDEX "IX_GroupMembers_GroupId" ON "GroupMembers"("GroupId");
```

---

### 3.9. Matches

Trận đấu trong giải. Mỗi bảng 4 đơn vị → 6 trận, 3 vòng.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| TournamentId | UUID | ❌ | | FK → Tournaments |
| GroupId | UUID | ❌ | | FK → Groups |
| Round | INTEGER | ❌ | | Vòng thi đấu (1-3) |
| MatchOrder | INTEGER | ❌ | | Thứ tự trận trong vòng (1-2) |
| Player1Id | UUID | ❌ | | User ID (Singles) hoặc Team ID (Doubles) |
| Player2Id | UUID | ❌ | | User ID (Singles) hoặc Team ID (Doubles) |
| Player1Scores | JSONB | ✅ | NULL | Điểm từng set, vd: `[11, 9, 11]` |
| Player2Scores | JSONB | ✅ | NULL | Điểm từng set, vd: `[7, 11, 8]` |
| WinnerId | UUID | ✅ | NULL | ID người/đội thắng |
| Status | VARCHAR(15) | ❌ | `'scheduled'` | Trạng thái trận đấu |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |
| UpdatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

**Lịch Round Robin cố định (mỗi bảng A, B, C, D):**

| Vòng | MatchOrder=1 | MatchOrder=2 |
|:----:|:----------:|:----------:|
| 1 | A vs B | C vs D |
| 2 | A vs C | B vs D |
| 3 | A vs D | B vs C |

**Ví dụ dữ liệu JSONB Player1Scores:**
```json
[11, 9, 11]     // Best of 3: thắng set 1 (11-7), thua set 2 (9-11), thắng set 3 (11-8)
[11]            // Best of 1: thắng (11-7)
[15, 11]        // Best of 3: thắng 2-0 (15-13, 11-9) — trận kết thúc sớm
```

```sql
CREATE TABLE "Matches" (
    "Id"            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "TournamentId"  UUID NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "GroupId"       UUID NOT NULL REFERENCES "Groups"("Id") ON DELETE CASCADE,
    "Round"         INTEGER NOT NULL,
    "MatchOrder"    INTEGER NOT NULL,
    "Player1Id"     UUID NOT NULL,
    "Player2Id"     UUID NOT NULL,
    "Player1Scores" JSONB,
    "Player2Scores" JSONB,
    "WinnerId"      UUID,
    "Status"        VARCHAR(15) NOT NULL DEFAULT 'scheduled',
    "CreatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Matches_Round" CHECK ("Round" BETWEEN 1 AND 3),
    CONSTRAINT "CK_Matches_MatchOrder" CHECK ("MatchOrder" BETWEEN 1 AND 2),
    CONSTRAINT "CK_Matches_Status" CHECK ("Status" IN ('scheduled', 'in_progress', 'completed', 'walkover')),
    CONSTRAINT "CK_Matches_DifferentPlayers" CHECK ("Player1Id" != "Player2Id"),
    CONSTRAINT "UQ_Matches_Unique" UNIQUE ("GroupId", "Round", "MatchOrder")
);

CREATE INDEX "IX_Matches_TournamentId" ON "Matches"("TournamentId");
CREATE INDEX "IX_Matches_GroupId" ON "Matches"("GroupId");
CREATE INDEX "IX_Matches_Group_Status" ON "Matches"("GroupId", "Status");
```

---

### 3.10. MatchScoreHistories

Lưu lịch sử sửa điểm để audit trail.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| MatchId | UUID | ❌ | | FK → Matches |
| ModifiedBy | UUID | ❌ | | FK → Users (người sửa) |
| OldPlayer1Scores | JSONB | ✅ | | Điểm cũ |
| OldPlayer2Scores | JSONB | ✅ | | Điểm cũ |
| NewPlayer1Scores | JSONB | ❌ | | Điểm mới |
| NewPlayer2Scores | JSONB | ❌ | | Điểm mới |
| Reason | VARCHAR(500) | ✅ | NULL | Lý do sửa |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "MatchScoreHistories" (
    "Id"               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "MatchId"          UUID NOT NULL REFERENCES "Matches"("Id") ON DELETE CASCADE,
    "ModifiedBy"       UUID NOT NULL REFERENCES "Users"("Id"),
    "OldPlayer1Scores" JSONB,
    "OldPlayer2Scores" JSONB,
    "NewPlayer1Scores" JSONB NOT NULL,
    "NewPlayer2Scores" JSONB NOT NULL,
    "Reason"           VARCHAR(500),
    "CreatedAt"        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX "IX_MatchScoreHistories_MatchId" ON "MatchScoreHistories"("MatchId");
```

---

### 3.11. CommunityGames (Phase 2)

Game giao hữu cộng đồng.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| CreatorId | UUID | ❌ | | FK → Users |
| Title | VARCHAR(200) | ❌ | | Tiêu đề |
| Description | TEXT | ✅ | NULL | Mô tả |
| Date | TIMESTAMPTZ | ❌ | | Ngày giờ diễn ra |
| Location | VARCHAR(500) | ❌ | | Địa điểm (text) |
| Latitude | DECIMAL(10,8) | ✅ | NULL | Vĩ độ |
| Longitude | DECIMAL(11,8) | ✅ | NULL | Kinh độ |
| MaxPlayers | INTEGER | ❌ | | Số người tối đa |
| SkillLevel | VARCHAR(20) | ❌ | `'all'` | Trình độ yêu cầu |
| Status | VARCHAR(15) | ❌ | `'open'` | Trạng thái |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |
| UpdatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "CommunityGames" (
    "Id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "CreatorId"   UUID NOT NULL REFERENCES "Users"("Id"),
    "Title"       VARCHAR(200) NOT NULL,
    "Description" TEXT,
    "Date"        TIMESTAMPTZ NOT NULL,
    "Location"    VARCHAR(500) NOT NULL,
    "Latitude"    DECIMAL(10,8),
    "Longitude"   DECIMAL(11,8),
    "MaxPlayers"  INTEGER NOT NULL,
    "SkillLevel"  VARCHAR(20) NOT NULL DEFAULT 'all',
    "Status"      VARCHAR(15) NOT NULL DEFAULT 'open',
    "CreatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_CommunityGames_SkillLevel" CHECK ("SkillLevel" IN ('beginner', 'intermediate', 'advanced', 'all')),
    CONSTRAINT "CK_CommunityGames_Status" CHECK ("Status" IN ('open', 'full', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT "CK_CommunityGames_MaxPlayers" CHECK ("MaxPlayers" BETWEEN 2 AND 50)
);

CREATE INDEX "IX_CommunityGames_CreatorId" ON "CommunityGames"("CreatorId");
CREATE INDEX "IX_CommunityGames_Date" ON "CommunityGames"("Date");
CREATE INDEX "IX_CommunityGames_Status_Date" ON "CommunityGames"("Status", "Date");
CREATE INDEX "IX_CommunityGames_Location" ON "CommunityGames"("Latitude", "Longitude");
```

---

### 3.12. GameParticipants (Phase 2)

Người tham gia game cộng đồng.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| GameId | UUID | ❌ | | FK → CommunityGames |
| UserId | UUID | ❌ | | FK → Users |
| Status | VARCHAR(15) | ❌ | `'confirmed'` | Trạng thái |
| WaitlistPosition | INTEGER | ✅ | NULL | Vị trí trong hàng đợi |
| JoinedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "GameParticipants" (
    "Id"               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "GameId"           UUID NOT NULL REFERENCES "CommunityGames"("Id") ON DELETE CASCADE,
    "UserId"           UUID NOT NULL REFERENCES "Users"("Id"),
    "Status"           VARCHAR(15) NOT NULL DEFAULT 'confirmed',
    "WaitlistPosition" INTEGER,
    "JoinedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_GameParticipants_Game_User" UNIQUE ("GameId", "UserId"),
    CONSTRAINT "CK_GameParticipants_Status" CHECK ("Status" IN ('confirmed', 'waitlist', 'invited_pending', 'cancelled'))
);

CREATE INDEX "IX_GameParticipants_GameId" ON "GameParticipants"("GameId");
CREATE INDEX "IX_GameParticipants_UserId" ON "GameParticipants"("UserId");
```

---

### 3.13. ChatRooms (Phase 2)

Phòng chat. Hỗ trợ chat 1-1 (direct) và nhóm (group).

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| Type | VARCHAR(10) | ❌ | | `'direct'` / `'group'` |
| Name | VARCHAR(100) | ✅ | NULL | Tên phòng (NULL cho direct) |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "ChatRooms" (
    "Id"        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "Type"      VARCHAR(10) NOT NULL,
    "Name"      VARCHAR(100),
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_ChatRooms_Type" CHECK ("Type" IN ('direct', 'group'))
);
```

---

### 3.14. ChatMembers (Phase 2)

Thành viên phòng chat.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| RoomId | UUID | ❌ | | FK → ChatRooms |
| UserId | UUID | ❌ | | FK → Users |
| JoinedAt | TIMESTAMPTZ | ❌ | `NOW()` | |
| MutedUntil | TIMESTAMPTZ | ✅ | NULL | Tắt thông báo đến thời điểm |
| LastReadMessageId | UUID | ✅ | NULL | Tin nhắn cuối đã đọc |

```sql
CREATE TABLE "ChatMembers" (
    "Id"                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "RoomId"            UUID NOT NULL REFERENCES "ChatRooms"("Id") ON DELETE CASCADE,
    "UserId"            UUID NOT NULL REFERENCES "Users"("Id"),
    "JoinedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "MutedUntil"        TIMESTAMPTZ,
    "LastReadMessageId" UUID,

    CONSTRAINT "UQ_ChatMembers_Room_User" UNIQUE ("RoomId", "UserId")
);

CREATE INDEX "IX_ChatMembers_RoomId" ON "ChatMembers"("RoomId");
CREATE INDEX "IX_ChatMembers_UserId" ON "ChatMembers"("UserId");
```

---

### 3.15. Messages (Phase 2)

Tin nhắn trong phòng chat.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| RoomId | UUID | ❌ | | FK → ChatRooms |
| SenderId | UUID | ❌ | | FK → Users |
| Content | TEXT | ❌ | | Nội dung tin nhắn |
| Type | VARCHAR(10) | ❌ | `'text'` | `'text'` / `'image'` / `'system'` |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

**Lưu ý:** Trạng thái đã đọc được track qua `ChatMembers.LastReadMessageId` thay vì JSONB `ReadBy` trong mỗi message → tối ưu performance hơn.

```sql
CREATE TABLE "Messages" (
    "Id"        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "RoomId"    UUID NOT NULL REFERENCES "ChatRooms"("Id") ON DELETE CASCADE,
    "SenderId"  UUID NOT NULL REFERENCES "Users"("Id"),
    "Content"   TEXT NOT NULL,
    "Type"      VARCHAR(10) NOT NULL DEFAULT 'text',
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Messages_Type" CHECK ("Type" IN ('text', 'image', 'system'))
);

CREATE INDEX "IX_Messages_RoomId_CreatedAt" ON "Messages"("RoomId", "CreatedAt" DESC);
```

---

### 3.16. Notifications

Thông báo trong ứng dụng.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| UserId | UUID | ❌ | | FK → Users (người nhận) |
| Type | VARCHAR(30) | ❌ | | Loại thông báo |
| Title | VARCHAR(200) | ❌ | | Tiêu đề |
| Body | TEXT | ✅ | NULL | Nội dung chi tiết |
| Data | JSONB | ✅ | NULL | Dữ liệu kèm theo (cho deep link) |
| IsRead | BOOLEAN | ❌ | FALSE | Đã đọc chưa |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

**Notification Types:**

| Type | Mô tả | Data |
|------|--------|------|
| `tournament_invite` | Được mời vào giải | `{ tournamentId, inviterId }` |
| `request_approved` | Yêu cầu tham gia được duyệt | `{ tournamentId }` |
| `request_rejected` | Yêu cầu tham gia bị từ chối | `{ tournamentId, reason }` |
| `tournament_started` | Giải bắt đầu thi đấu | `{ tournamentId }` |
| `match_scheduled` | Lịch thi đấu đã tạo | `{ tournamentId, matchId }` |
| `match_result` | Kết quả trận đấu | `{ tournamentId, matchId, winnerId }` |
| `tournament_completed` | Giải kết thúc | `{ tournamentId }` |
| `tournament_cancelled` | Giải bị hủy | `{ tournamentId, reason }` |
| `game_invite` | Mời vào game cộng đồng | `{ gameId, inviterId }` |
| `new_message` | Tin nhắn mới | `{ roomId, senderId }` |
| `new_follower` | Có người theo dõi mới | `{ followerId }` |

```sql
CREATE TABLE "Notifications" (
    "Id"        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "UserId"    UUID NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "Type"      VARCHAR(30) NOT NULL,
    "Title"     VARCHAR(200) NOT NULL,
    "Body"      TEXT,
    "Data"      JSONB,
    "IsRead"    BOOLEAN NOT NULL DEFAULT FALSE,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX "IX_Notifications_UserId_IsRead" ON "Notifications"("UserId", "IsRead", "CreatedAt" DESC);
CREATE INDEX "IX_Notifications_UserId_CreatedAt" ON "Notifications"("UserId", "CreatedAt" DESC);
```

---

### 3.17. DeviceTokens

Lưu FCM token cho push notification.

| Cột | Kiểu dữ liệu | Null | Default | Mô tả |
|-----|--------------|------|---------|--------|
| **Id** | UUID | ❌ | `gen_random_uuid()` | Khóa chính |
| UserId | UUID | ❌ | | FK → Users |
| Token | VARCHAR(500) | ❌ | | FCM device token |
| Platform | VARCHAR(10) | ❌ | | `'ios'` / `'android'` / `'web'` |
| CreatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |
| UpdatedAt | TIMESTAMPTZ | ❌ | `NOW()` | |

```sql
CREATE TABLE "DeviceTokens" (
    "Id"        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "UserId"    UUID NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "Token"     VARCHAR(500) NOT NULL,
    "Platform"  VARCHAR(10) NOT NULL,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_DeviceTokens_Token" UNIQUE ("Token"),
    CONSTRAINT "CK_DeviceTokens_Platform" CHECK ("Platform" IN ('ios', 'android', 'web'))
);

CREATE INDEX "IX_DeviceTokens_UserId" ON "DeviceTokens"("UserId");
```

---

## 4. Indexes & Performance

### 4.1. Tổng hợp Indexes

| Bảng | Index | Loại | Mục đích |
|------|-------|------|----------|
| Users | Email | UNIQUE | Lookup khi login |
| RefreshTokens | UserId | B-tree | Tìm tokens của user |
| RefreshTokens | TokenHash | B-tree | Verify refresh token |
| Follows | FollowerId | B-tree | Danh sách đang follow |
| Follows | FollowingId | B-tree | Danh sách followers |
| Tournaments | CreatorId | B-tree | Giải của tôi |
| Tournaments | Status, Date | Composite | Lọc + sắp xếp |
| Participants | TournamentId | B-tree | DS người tham gia |
| Participants | UserId | B-tree | Giải đã tham gia |
| Participants | TournamentId, Status | Composite | Đếm confirmed |
| Matches | TournamentId | B-tree | Lịch thi đấu |
| Matches | GroupId | B-tree | Trận trong bảng |
| Matches | GroupId, Status | Composite | Trận chưa đấu |
| CommunityGames | Status, Date | Composite | Lobby listing |
| CommunityGames | Lat, Lng | Composite | Tìm theo vị trí |
| Messages | RoomId, CreatedAt DESC | Composite | Load tin nhắn |
| Notifications | UserId, IsRead, CreatedAt | Composite | DS thông báo chưa đọc |

### 4.2. Query Patterns thường gặp & Index tương ứng

```sql
-- 1. Danh sách giải đấu đang mở (dùng nhiều nhất)
-- Index: IX_Tournaments_Status_Date
SELECT * FROM "Tournaments"
WHERE "Status" = 'open'
ORDER BY "Date" DESC
LIMIT 20 OFFSET 0;

-- 2. Đếm số người confirmed trong giải
-- Index: IX_Participants_Tournament_Status
SELECT COUNT(*) FROM "Participants"
WHERE "TournamentId" = $1 AND "Status" = 'confirmed';

-- 3. Lịch thi đấu của 1 bảng
-- Index: IX_Matches_GroupId
SELECT * FROM "Matches"
WHERE "GroupId" = $1
ORDER BY "Round", "MatchOrder";

-- 4. Thông báo chưa đọc
-- Index: IX_Notifications_UserId_IsRead
SELECT * FROM "Notifications"
WHERE "UserId" = $1 AND "IsRead" = FALSE
ORDER BY "CreatedAt" DESC;

-- 5. Tin nhắn mới nhất (cursor-based pagination)
-- Index: IX_Messages_RoomId_CreatedAt
SELECT * FROM "Messages"
WHERE "RoomId" = $1 AND "CreatedAt" < $2
ORDER BY "CreatedAt" DESC
LIMIT 50;

-- 6. Game cộng đồng gần vị trí (approximate distance)
-- Index: IX_CommunityGames_Location
SELECT *, (
    6371 * ACOS(
        COS(RADIANS($1)) * COS(RADIANS("Latitude"))
        * COS(RADIANS("Longitude") - RADIANS($2))
        + SIN(RADIANS($1)) * SIN(RADIANS("Latitude"))
    )
) AS distance
FROM "CommunityGames"
WHERE "Status" = 'open'
  AND "Latitude" BETWEEN $1 - 0.1 AND $1 + 0.1
  AND "Longitude" BETWEEN $2 - 0.1 AND $2 + 0.1
ORDER BY distance
LIMIT 20;
```

### 4.3. PostgreSQL-specific Optimizations

```sql
-- Partial index cho thông báo chưa đọc (giảm kích thước index)
CREATE INDEX "IX_Notifications_Unread"
ON "Notifications"("UserId", "CreatedAt" DESC)
WHERE "IsRead" = FALSE;

-- Partial index cho giải đang hoạt động
CREATE INDEX "IX_Tournaments_Active"
ON "Tournaments"("Status", "Date")
WHERE "Status" IN ('open', 'in_progress');

-- GIN index cho JSONB search (nếu cần query bên trong Notification.Data)
CREATE INDEX "IX_Notifications_Data" ON "Notifications" USING GIN("Data");
```

---

## 5. Migrations Strategy

### 5.1. EF Core Migration Commands

```bash
# Tạo migration
dotnet ef migrations add InitialCreate \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API

# Áp dụng (development)
dotnet ef database update \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API

# Export SQL (production)
dotnet ef migrations script \
  --project src/PickleballApp.Infrastructure \
  --startup-project src/PickleballApp.API \
  --idempotent \
  -o migrations/V1__InitialCreate.sql
```

### 5.2. Thứ tự Migration theo Phase

**Phase 1 — Migration 1: Core Tables**
```
V1__Create_Users.sql
V2__Create_RefreshTokens.sql
V3__Create_Tournaments.sql
V4__Create_Participants.sql
V5__Create_Teams.sql
V6__Create_Groups.sql
V7__Create_GroupMembers.sql
V8__Create_Matches.sql
V9__Create_MatchScoreHistories.sql
V10__Create_Notifications.sql
V11__Create_DeviceTokens.sql
V12__Create_Indexes_Phase1.sql
```

**Phase 2 — Migration 2: Social & Community**
```
V13__Create_Follows.sql
V14__Create_CommunityGames.sql
V15__Create_GameParticipants.sql
V16__Create_ChatRooms.sql
V17__Create_ChatMembers.sql
V18__Create_Messages.sql
V19__Create_Indexes_Phase2.sql
```

### 5.3. Production Migration Rules

| Quy tắc | Mô tả |
|---------|--------|
| Không bao giờ chạy `ef database update` trên production | Export SQL → Review → Apply thủ công |
| Luôn dùng `--idempotent` | Script an toàn khi chạy lại |
| Không xóa cột đang sử dụng | Đánh dấu deprecated → remove ở migration sau |
| Thêm cột mới luôn NULLABLE hoặc có DEFAULT | Tránh lock table |
| Không đổi tên cột trực tiếp | Thêm cột mới → migrate data → xóa cột cũ |
| Backup trước mỗi migration | `pg_dump` trước khi apply |

---

## 6. Seed Data

### 6.1. Admin User

```sql
INSERT INTO "Users" ("Id", "Email", "PasswordHash", "Name", "SkillLevel")
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'admin@pickleball-app.com',
    '$2a$12$...', -- bcrypt hash của admin password
    'System Admin',
    5.0
);
```

### 6.2. Demo Data (Development only)

```sql
-- 4 demo users
INSERT INTO "Users" ("Id", "Email", "PasswordHash", "Name", "SkillLevel") VALUES
('10000000-0000-0000-0000-000000000001', 'player1@demo.com', '$2a$12$...', 'Nguyễn Văn A', 3.5),
('10000000-0000-0000-0000-000000000002', 'player2@demo.com', '$2a$12$...', 'Trần Văn B', 4.0),
('10000000-0000-0000-0000-000000000003', 'player3@demo.com', '$2a$12$...', 'Lê Văn C', 3.0),
('10000000-0000-0000-0000-000000000004', 'player4@demo.com', '$2a$12$...', 'Phạm Văn D', 3.5);

-- 1 demo tournament (singles, 1 bảng, completed)
INSERT INTO "Tournaments" ("Id", "CreatorId", "Name", "Type", "NumGroups", "ScoringFormat", "Status", "Date", "Location")
VALUES (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Giải Demo Đấu Đơn',
    'singles', 1, 'best_of_3', 'completed',
    '2026-03-01', 'Sân Demo, Quận 1'
);
```

---

## 7. Quy Tắc & Ràng Buộc Nghiệp Vụ

### 7.1. Tournament Capacity

```
Singles:
  1 bảng = 4 người  → max 4
  2 bảng = 8 người  → max 8
  3 bảng = 12 người → max 12
  4 bảng = 16 người → max 16

Doubles:
  1 bảng = 4 đội = 8 người  → max 8
  2 bảng = 8 đội = 16 người → max 16

Công thức:
  Singles: maxParticipants = numGroups × 4
  Doubles: maxParticipants = numGroups × 4 × 2 (người)
           maxTeams = numGroups × 4
```

### 7.2. Score Validation Rules

```
Pickleball scoring:
  - Thắng set khi đạt tối thiểu 11 điểm
  - Phải thắng cách biệt ít nhất 2 điểm
  - Không có giới hạn trên (deuce liên tục)

Ví dụ hợp lệ:     11-0, 11-9, 12-10, 15-13, 25-23
Ví dụ KHÔNG hợp lệ: 10-8, 11-10, 5-3

Best of 1: đúng 1 set
Best of 3: kết thúc khi 1 bên thắng 2 set (tối thiểu 2, tối đa 3 set)
```

### 7.3. Standings Calculation

```
Xếp hạng trong bảng Round Robin:

1. Số trận thắng (cao → thấp)
2. Nếu bằng nhau → Hiệu số điểm (tổng ghi - tổng mất)
3. Nếu vẫn bằng → Đối đầu trực tiếp giữa 2 người
4. Nếu 3 người cùng điểm → Xét vòng tròn nhỏ giữa 3 người đó
5. Nếu vẫn hòa → Xét hiệu số điểm trong vòng tròn nhỏ

SQL tính standings:
```

```sql
-- Tính BXH cho 1 bảng
WITH match_stats AS (
    SELECT
        gm."PlayerId" AS player_id,
        COUNT(CASE WHEN m."WinnerId" = gm."PlayerId" THEN 1 END) AS wins,
        COUNT(CASE WHEN m."WinnerId" IS NOT NULL AND m."WinnerId" != gm."PlayerId" THEN 1 END) AS losses,
        COALESCE(SUM(
            CASE WHEN m."Player1Id" = gm."PlayerId"
                THEN (SELECT SUM(s::int) FROM jsonb_array_elements_text(m."Player1Scores") s)
                ELSE (SELECT SUM(s::int) FROM jsonb_array_elements_text(m."Player2Scores") s)
            END
        ), 0) AS points_for,
        COALESCE(SUM(
            CASE WHEN m."Player1Id" = gm."PlayerId"
                THEN (SELECT SUM(s::int) FROM jsonb_array_elements_text(m."Player2Scores") s)
                ELSE (SELECT SUM(s::int) FROM jsonb_array_elements_text(m."Player1Scores") s)
            END
        ), 0) AS points_against
    FROM "GroupMembers" gm
    LEFT JOIN "Matches" m ON m."GroupId" = gm."GroupId"
        AND (m."Player1Id" = gm."PlayerId" OR m."Player2Id" = gm."PlayerId")
        AND m."Status" = 'completed'
    WHERE gm."GroupId" = $1
    GROUP BY gm."PlayerId"
)
SELECT
    player_id,
    wins,
    losses,
    points_for,
    points_against,
    (points_for - points_against) AS point_diff,
    ROW_NUMBER() OVER (
        ORDER BY wins DESC, (points_for - points_against) DESC
    ) AS rank
FROM match_stats
ORDER BY rank;
```

### 7.4. Data Integrity Rules

| Quy tắc | Bảng | Mô tả |
|---------|------|--------|
| Unique participant | Participants | 1 user chỉ tham gia 1 lần / giải |
| Unique group member | GroupMembers | 1 player/team chỉ thuộc 1 bảng / giải |
| Unique match | Matches | 1 bảng chỉ có 1 trận / round + matchOrder |
| No self-follow | Follows | Không thể follow chính mình |
| No self-match | Matches | Player1Id != Player2Id |
| Different team players | Teams | Player1Id != Player2Id |
| Score immutability | MatchScoreHistories | Điểm cũ được lưu lại trước khi sửa |
| Soft delete | Tournaments, CommunityGames | Dùng status cancelled thay vì xóa thật |
| Cascade delete | Groups, GroupMembers, Matches | Xóa giải → xóa tất cả bảng, trận |

### 7.5. Timezone Convention

- Tất cả TIMESTAMP trong DB lưu dạng **TIMESTAMPTZ** (UTC)
- Frontend convert sang local timezone khi hiển thị
- API nhận/trả thời gian dạng ISO 8601 với timezone: `2026-03-12T15:00:00+07:00`
