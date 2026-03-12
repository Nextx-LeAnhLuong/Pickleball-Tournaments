-- =====================================================
-- Pickleball App Database Migration Script
-- Database: pickleball_db
-- Version: 3.0 (Multi-provider Auth + Email Verification)
-- Date: 2026-03-12
-- Features: INTEGER Auto-increment IDs, Round Robin,
--           JSONB Scores, Cloudinary File Storage,
--           Multi-provider OAuth, Email Verification
-- =====================================================

-- =====================================================
-- TABLE 1: users (Tài khoản & Hồ sơ)
-- Lưu thông tin tài khoản và hồ sơ người chơi.
-- =====================================================

CREATE TABLE "Users" (
    "Id"                       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "Email"                    VARCHAR(255) NOT NULL,
    "PasswordHash"             VARCHAR(255),
    "Name"                     VARCHAR(100) NOT NULL,
    "AvatarUrl"                VARCHAR(500),
    "Bio"                      TEXT,
    "SkillLevel"               DECIMAL(2,1) NOT NULL DEFAULT 3.0,
    "DominantHand"             VARCHAR(10),
    "PaddleType"               VARCHAR(100),
    "EmailVerified"            BOOLEAN NOT NULL DEFAULT FALSE,
    "EmailVerifiedAt"          TIMESTAMPTZ,
    "EmailVerificationToken"   VARCHAR(500),
    "CreatedAt"                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Users_Email" UNIQUE ("Email"),
    CONSTRAINT "CK_Users_SkillLevel" CHECK ("SkillLevel" >= 1.0 AND "SkillLevel" <= 5.0),
    CONSTRAINT "CK_Users_DominantHand" CHECK ("DominantHand" IN ('left', 'right') OR "DominantHand" IS NULL)
);

COMMENT ON TABLE "Users" IS 'Tài khoản và hồ sơ người chơi. OAuth providers tách ra bảng UserAuthProviders.';

-- =====================================================
-- TABLE 2: user_auth_providers (OAuth Providers)
-- Lưu OAuth providers đã liên kết. 1 user → N providers.
-- =====================================================

CREATE TABLE "UserAuthProviders" (
    "Id"              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "UserId"          INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "Provider"        VARCHAR(20) NOT NULL,
    "ProviderUserId"  VARCHAR(255) NOT NULL,
    "Email"           VARCHAR(255),
    "Name"            VARCHAR(100),
    "AvatarUrl"       VARCHAR(500),
    "CreatedAt"       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_UserAuthProviders_Provider" CHECK ("Provider" IN ('google', 'facebook', 'apple')),
    CONSTRAINT "UQ_UserAuthProviders_Provider_UserId" UNIQUE ("Provider", "ProviderUserId"),
    CONSTRAINT "UQ_UserAuthProviders_User_Provider" UNIQUE ("UserId", "Provider")
);

CREATE INDEX "IX_UserAuthProviders_UserId" ON "UserAuthProviders"("UserId");

COMMENT ON TABLE "UserAuthProviders" IS 'OAuth providers liên kết với user. 1 user có thể link Google + Facebook + Apple.';

-- =====================================================
-- TABLE 2: refresh_tokens (Token làm mới)
-- Lưu refresh token (multi-device). Hỗ trợ token rotation.
-- =====================================================

CREATE TABLE "RefreshTokens" (
    "Id"                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "UserId"            INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "TokenHash"         VARCHAR(500) NOT NULL,
    "ExpiresAt"         TIMESTAMPTZ NOT NULL,
    "CreatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "RevokedAt"         TIMESTAMPTZ,
    "ReplacedByTokenId" INTEGER REFERENCES "RefreshTokens"("Id")
);

CREATE INDEX "IX_RefreshTokens_UserId" ON "RefreshTokens"("UserId");
CREATE INDEX "IX_RefreshTokens_TokenHash" ON "RefreshTokens"("TokenHash");

COMMENT ON TABLE "RefreshTokens" IS 'Refresh tokens cho JWT authentication. Hỗ trợ token rotation và multi-device.';

-- =====================================================
-- TABLE 3: follows (Quan hệ theo dõi — Phase 2)
-- Quan hệ theo dõi giữa users (many-to-many).
-- =====================================================

CREATE TABLE "Follows" (
    "Id"          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "FollowerId"  INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "FollowingId" INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "CreatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Follows_Pair" UNIQUE ("FollowerId", "FollowingId"),
    CONSTRAINT "CK_Follows_NoSelfFollow" CHECK ("FollowerId" != "FollowingId")
);

CREATE INDEX "IX_Follows_FollowerId" ON "Follows"("FollowerId");
CREATE INDEX "IX_Follows_FollowingId" ON "Follows"("FollowingId");

COMMENT ON TABLE "Follows" IS 'Quan hệ theo dõi giữa users. Không cho phép tự follow.';

-- =====================================================
-- TABLE 4: tournaments (Giải đấu)
-- Bảng chính lưu thông tin giải đấu Singles/Doubles.
-- =====================================================

CREATE TABLE "Tournaments" (
    "Id"            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "CreatorId"     INTEGER NOT NULL REFERENCES "Users"("Id"),
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

COMMENT ON TABLE "Tournaments" IS 'Giải đấu pickleball. Singles: max 4 bảng (16 người). Doubles: max 2 bảng (8 đội).';

-- =====================================================
-- TABLE 5: participants (Người tham gia giải)
-- Junction table: Users ↔ Tournaments (N-N) + Status.
-- =====================================================

CREATE TABLE "Participants" (
    "Id"           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "TournamentId" INTEGER NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "UserId"       INTEGER NOT NULL REFERENCES "Users"("Id"),
    "Status"       VARCHAR(20) NOT NULL DEFAULT 'request_pending',
    "InvitedBy"    INTEGER REFERENCES "Users"("Id"),
    "RejectReason" VARCHAR(500),
    "JoinedAt"     TIMESTAMPTZ,
    "CreatedAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_Participants_Tournament_User" UNIQUE ("TournamentId", "UserId"),
    CONSTRAINT "CK_Participants_Status" CHECK ("Status" IN ('confirmed', 'invited_pending', 'request_pending', 'rejected'))
);

CREATE INDEX "IX_Participants_TournamentId" ON "Participants"("TournamentId");
CREATE INDEX "IX_Participants_UserId" ON "Participants"("UserId");
CREATE INDEX "IX_Participants_Tournament_Status" ON "Participants"("TournamentId", "Status");

COMMENT ON TABLE "Participants" IS 'Người tham gia giải. Status flow: pending → confirmed/rejected.';

-- =====================================================
-- TABLE 6: teams (Đội — chỉ Doubles)
-- Đội trong giải đấu đôi. Mỗi đội gồm 2 người chơi.
-- =====================================================

CREATE TABLE "Teams" (
    "Id"           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "TournamentId" INTEGER NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "Name"         VARCHAR(100),
    "Player1Id"    INTEGER NOT NULL REFERENCES "Users"("Id"),
    "Player2Id"    INTEGER NOT NULL REFERENCES "Users"("Id"),
    "CreatedAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Teams_DifferentPlayers" CHECK ("Player1Id" != "Player2Id")
);

CREATE INDEX "IX_Teams_TournamentId" ON "Teams"("TournamentId");

COMMENT ON TABLE "Teams" IS 'Đội trong giải Doubles. 2 thành viên/đội, không được trùng.';

-- =====================================================
-- TABLE 7: groups (Bảng đấu)
-- Mỗi giải có N bảng, mỗi bảng 4 đơn vị thi đấu.
-- =====================================================

CREATE TABLE "Groups" (
    "Id"           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "TournamentId" INTEGER NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "Name"         VARCHAR(10) NOT NULL,
    "DisplayOrder" INTEGER NOT NULL,

    CONSTRAINT "UQ_Groups_Tournament_Name" UNIQUE ("TournamentId", "Name"),
    CONSTRAINT "UQ_Groups_Tournament_Order" UNIQUE ("TournamentId", "DisplayOrder")
);

CREATE INDEX "IX_Groups_TournamentId" ON "Groups"("TournamentId");

COMMENT ON TABLE "Groups" IS 'Bảng đấu (A, B, C, D). Mỗi bảng có đúng 4 đơn vị thi đấu.';

-- =====================================================
-- TABLE 8: group_members (Thành viên bảng đấu)
-- Lưu player (Singles) hoặc team (Doubles) thuộc bảng.
-- =====================================================

CREATE TABLE "GroupMembers" (
    "Id"        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "GroupId"   INTEGER NOT NULL REFERENCES "Groups"("Id") ON DELETE CASCADE,
    "PlayerId"  INTEGER REFERENCES "Users"("Id"),
    "TeamId"    INTEGER REFERENCES "Teams"("Id"),
    "SeedOrder" INTEGER NOT NULL,

    CONSTRAINT "CK_GroupMembers_OneType" CHECK (
        ("PlayerId" IS NOT NULL AND "TeamId" IS NULL) OR
        ("PlayerId" IS NULL AND "TeamId" IS NOT NULL)
    ),
    CONSTRAINT "CK_GroupMembers_SeedOrder" CHECK ("SeedOrder" BETWEEN 1 AND 4)
);

CREATE INDEX "IX_GroupMembers_GroupId" ON "GroupMembers"("GroupId");

COMMENT ON TABLE "GroupMembers" IS 'Thành viên bảng đấu. Singles: PlayerId, Doubles: TeamId. Mỗi bảng 4 thành viên.';

-- =====================================================
-- TABLE 9: matches (Trận đấu)
-- Trận đấu Round Robin. Mỗi bảng 6 trận, 3 vòng.
-- =====================================================

CREATE TABLE "Matches" (
    "Id"            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "TournamentId"  INTEGER NOT NULL REFERENCES "Tournaments"("Id") ON DELETE CASCADE,
    "GroupId"       INTEGER NOT NULL REFERENCES "Groups"("Id") ON DELETE CASCADE,
    "Round"         INTEGER NOT NULL,
    "MatchOrder"    INTEGER NOT NULL,
    "Player1Id"     INTEGER NOT NULL,
    "Player2Id"     INTEGER NOT NULL,
    "Player1Scores" JSONB,
    "Player2Scores" JSONB,
    "WinnerId"      INTEGER,
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

COMMENT ON TABLE "Matches" IS 'Trận đấu Round Robin. JSONB scores: [11, 9, 11]. Player1/2Id = UserId (Singles) hoặc TeamId (Doubles).';

-- =====================================================
-- TABLE 10: match_score_histories (Audit Trail điểm số)
-- Lưu lịch sử mỗi lần sửa điểm.
-- =====================================================

CREATE TABLE "MatchScoreHistories" (
    "Id"               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "MatchId"          INTEGER NOT NULL REFERENCES "Matches"("Id") ON DELETE CASCADE,
    "ModifiedBy"       INTEGER NOT NULL REFERENCES "Users"("Id"),
    "OldPlayer1Scores" JSONB,
    "OldPlayer2Scores" JSONB,
    "NewPlayer1Scores" JSONB NOT NULL,
    "NewPlayer2Scores" JSONB NOT NULL,
    "Reason"           VARCHAR(500),
    "CreatedAt"        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX "IX_MatchScoreHistories_MatchId" ON "MatchScoreHistories"("MatchId");

COMMENT ON TABLE "MatchScoreHistories" IS 'Audit trail cho mọi thay đổi điểm số. Lưu cả điểm cũ và mới.';

-- =====================================================
-- TABLE 11: community_games (Game cộng đồng — Phase 2)
-- Game giao hữu, hỗ trợ tìm theo vị trí địa lý.
-- =====================================================

CREATE TABLE "CommunityGames" (
    "Id"          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "CreatorId"   INTEGER NOT NULL REFERENCES "Users"("Id"),
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

COMMENT ON TABLE "CommunityGames" IS 'Game giao hữu cộng đồng. Hỗ trợ lọc theo vị trí, skill level, và trạng thái.';

-- =====================================================
-- TABLE 12: game_participants (Người tham gia game — Phase 2)
-- Junction: Users ↔ CommunityGames + waitlist support.
-- =====================================================

CREATE TABLE "GameParticipants" (
    "Id"               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "GameId"           INTEGER NOT NULL REFERENCES "CommunityGames"("Id") ON DELETE CASCADE,
    "UserId"           INTEGER NOT NULL REFERENCES "Users"("Id"),
    "Status"           VARCHAR(15) NOT NULL DEFAULT 'confirmed',
    "WaitlistPosition" INTEGER,
    "JoinedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_GameParticipants_Game_User" UNIQUE ("GameId", "UserId"),
    CONSTRAINT "CK_GameParticipants_Status" CHECK ("Status" IN ('confirmed', 'waitlist', 'invited_pending', 'cancelled'))
);

CREATE INDEX "IX_GameParticipants_GameId" ON "GameParticipants"("GameId");
CREATE INDEX "IX_GameParticipants_UserId" ON "GameParticipants"("UserId");

COMMENT ON TABLE "GameParticipants" IS 'Người tham gia game cộng đồng. Hỗ trợ waitlist khi game đã đầy.';

-- =====================================================
-- TABLE 13: chat_rooms (Phòng chat — Phase 2)
-- Hỗ trợ chat 1-1 (direct) và nhóm (group).
-- =====================================================

CREATE TABLE "ChatRooms" (
    "Id"        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "Type"      VARCHAR(10) NOT NULL,
    "Name"      VARCHAR(100),
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_ChatRooms_Type" CHECK ("Type" IN ('direct', 'group'))
);

COMMENT ON TABLE "ChatRooms" IS 'Phòng chat. Type: direct (1-1) hoặc group. Name NULL cho direct.';

-- =====================================================
-- TABLE 14: chat_members (Thành viên phòng chat — Phase 2)
-- Thành viên + track đã đọc qua LastReadMessageId.
-- =====================================================

CREATE TABLE "ChatMembers" (
    "Id"                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "RoomId"            INTEGER NOT NULL REFERENCES "ChatRooms"("Id") ON DELETE CASCADE,
    "UserId"            INTEGER NOT NULL REFERENCES "Users"("Id"),
    "JoinedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "MutedUntil"        TIMESTAMPTZ,
    "LastReadMessageId" INTEGER,

    CONSTRAINT "UQ_ChatMembers_Room_User" UNIQUE ("RoomId", "UserId")
);

CREATE INDEX "IX_ChatMembers_RoomId" ON "ChatMembers"("RoomId");
CREATE INDEX "IX_ChatMembers_UserId" ON "ChatMembers"("UserId");

COMMENT ON TABLE "ChatMembers" IS 'Thành viên phòng chat. Read status qua LastReadMessageId (tối ưu hơn JSONB).';

-- =====================================================
-- TABLE 15: messages (Tin nhắn — Phase 2)
-- Tin nhắn text, image, system. Cursor-based pagination.
-- =====================================================

CREATE TABLE "Messages" (
    "Id"        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "RoomId"    INTEGER NOT NULL REFERENCES "ChatRooms"("Id") ON DELETE CASCADE,
    "SenderId"  INTEGER NOT NULL REFERENCES "Users"("Id"),
    "Content"   TEXT NOT NULL,
    "Type"      VARCHAR(10) NOT NULL DEFAULT 'text',
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "CK_Messages_Type" CHECK ("Type" IN ('text', 'image', 'system'))
);

CREATE INDEX "IX_Messages_RoomId_CreatedAt" ON "Messages"("RoomId", "CreatedAt" DESC);

COMMENT ON TABLE "Messages" IS 'Tin nhắn trong phòng chat. Pagination bằng cursor (CreatedAt DESC).';

-- =====================================================
-- TABLE 16: notifications (Thông báo)
-- In-app + Push (FCM). Deep link qua JSONB Data.
-- =====================================================

CREATE TABLE "Notifications" (
    "Id"        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "UserId"    INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "Type"      VARCHAR(30) NOT NULL,
    "Title"     VARCHAR(200) NOT NULL,
    "Body"      TEXT,
    "Data"      JSONB,
    "IsRead"    BOOLEAN NOT NULL DEFAULT FALSE,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX "IX_Notifications_UserId_IsRead" ON "Notifications"("UserId", "IsRead", "CreatedAt" DESC);
CREATE INDEX "IX_Notifications_UserId_CreatedAt" ON "Notifications"("UserId", "CreatedAt" DESC);

COMMENT ON TABLE "Notifications" IS 'Thông báo in-app + push. Data chứa deep link info (tournamentId, matchId...).';

-- =====================================================
-- TABLE 17: device_tokens (FCM Token)
-- Lưu FCM token cho push notification. 1 device = 1 token.
-- =====================================================

CREATE TABLE "DeviceTokens" (
    "Id"        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "UserId"    INTEGER NOT NULL REFERENCES "Users"("Id") ON DELETE CASCADE,
    "Token"     VARCHAR(500) NOT NULL,
    "Platform"  VARCHAR(10) NOT NULL,
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT "UQ_DeviceTokens_Token" UNIQUE ("Token"),
    CONSTRAINT "CK_DeviceTokens_Platform" CHECK ("Platform" IN ('ios', 'android', 'web'))
);

CREATE INDEX "IX_DeviceTokens_UserId" ON "DeviceTokens"("UserId");

COMMENT ON TABLE "DeviceTokens" IS 'FCM device tokens cho push notification. Unique per device.';

-- =====================================================
-- PERFORMANCE: Partial Indexes
-- =====================================================

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

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."UpdatedAt" = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON "Users" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tournaments_updated_at BEFORE UPDATE ON "Tournaments" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_matches_updated_at BEFORE UPDATE ON "Matches" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_community_games_updated_at BEFORE UPDATE ON "CommunityGames" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_device_tokens_updated_at BEFORE UPDATE ON "DeviceTokens" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SEED DATA
-- =====================================================

-- 1. Admin User (EmailVerified = TRUE)
INSERT INTO "Users" ("Email", "PasswordHash", "Name", "SkillLevel", "EmailVerified", "EmailVerifiedAt")
VALUES (
    'admin@pickleball-app.com',
    '$2a$12$LJ3m4ys.kN5Xx1Kf5sNZxuYVfGqXKVJiL6SO0qH5..x3G3Y2HhMGe', -- hash of 'Admin@123'
    'System Admin',
    5.0,
    TRUE,
    NOW()
);

-- 2. Demo Users (EmailVerified = TRUE cho testing)
INSERT INTO "Users" ("Email", "PasswordHash", "Name", "SkillLevel", "EmailVerified", "EmailVerifiedAt") VALUES
('player1@demo.com', '$2a$12$LJ3m4ys.kN5Xx1Kf5sNZxuYVfGqXKVJiL6SO0qH5..x3G3Y2HhMGe', 'Nguyễn Văn A', 3.5, TRUE, NOW()),
('player2@demo.com', '$2a$12$LJ3m4ys.kN5Xx1Kf5sNZxuYVfGqXKVJiL6SO0qH5..x3G3Y2HhMGe', 'Trần Văn B', 4.0, TRUE, NOW()),
('player3@demo.com', '$2a$12$LJ3m4ys.kN5Xx1Kf5sNZxuYVfGqXKVJiL6SO0qH5..x3G3Y2HhMGe', 'Lê Văn C', 3.0, TRUE, NOW()),
('player4@demo.com', '$2a$12$LJ3m4ys.kN5Xx1Kf5sNZxuYVfGqXKVJiL6SO0qH5..x3G3Y2HhMGe', 'Phạm Văn D', 3.5, TRUE, NOW());

-- 3. Demo Tournament (Singles, 1 bảng, completed)
INSERT INTO "Tournaments" ("CreatorId", "Name", "Type", "NumGroups", "ScoringFormat", "Status", "Date", "Location")
VALUES (
    2,
    'Giải Demo Đấu Đơn',
    'singles', 1, 'best_of_3', 'completed',
    '2026-03-01', 'Sân Demo, Quận 1'
);

SELECT 'Pickleball Database v3.0 Migration Completed' as status;
