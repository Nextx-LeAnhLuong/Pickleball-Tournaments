# IAM Service - API Function List

**Service**: Identity and Access Management (IAM)  
**Version**: 7.0 | **Base URL**: `/api`  
**Last Updated**: 2026-02-23

---

## 📦 Response Wrappers

Tất cả API đều trả về 1 trong 2 format duy nhất:

### Single Response: `ApiResponse<T>`
```json
{
  "success": true,
  "message": "Success",
  "data": { },
  "errors": null,
  "timestamp": "2026-02-11T07:00:00Z",
  "traceId": "abc-123"
}
```

### Paged Response: `PagedResponse<T>` (kế thừa ApiResponse)
```json
{
  "success": true,
  "message": "Success",
  "data": [ ],
  "errors": null,
  "timestamp": "2026-02-11T07:00:00Z",
  "traceId": "abc-123",
  "pageNumber": 1,
  "pageSize": 20,
  "totalPages": 5,
  "totalRecords": 100
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error description",
  "data": null,
  "errors": ["Detail error 1", "Detail error 2"],
  "timestamp": "2026-02-11T07:00:00Z",
  "traceId": "abc-123"
}
```

---

## 📋 Common Headers

| Header | Mô tả | Bắt buộc |
|--------|--------|----------|
| `Authorization` | `Bearer <access_token>` | Có (trừ Auth public) |
| `Idempotency-Key` | UUID tránh duplicate cho POST/PUT | Không |
| `Content-Type` | `application/json` | Có |

> JWT chứa: `uid` (User ID), `wid` (Workspace ID), `grps` (Group Codes[])

---

# PART 1: MODULE & FUNCTION LIST OVERVIEW

## Module 1: Authentication (12 endpoints) — ⏱️ ~48h

| # | Method | Endpoint | Mô tả | Auth | ⏱️ Est |
|---|--------|----------|--------|------|--------|
| 1 | POST | `/auth/register` | Đăng ký tài khoản | ❌ | 6h |
| 2 | POST | `/auth/verify-email` | Xác thực email | ❌ | 3h |
| 3 | POST | `/auth/resend-verification` | Gửi lại email xác thực | ❌ | 2h |
| 4 | POST | `/auth/login` | Đăng nhập | ❌ | 8h |
| 5 | POST | `/auth/google-login` | Đăng nhập Google SSO | ❌ | 8h |
| 6 | POST | `/auth/2fa/challenge` | Verify 2FA code khi login | 🔑 Temp | 4h |
| 7 | POST | `/auth/2fa/backup-code` | Dùng backup code thay 2FA | 🔑 Temp | 3h |
| 8 | POST | `/auth/refresh-token` | Làm mới access token | ❌ | 4h |
| 9 | POST | `/auth/logout` | Đăng xuất session hiện tại | 🔒 | 2h |
| 10 | POST | `/auth/logout-all` | Đăng xuất tất cả thiết bị | 🔒 | 2h |
| 11 | POST | `/auth/forgot-password` | Yêu cầu reset password | ❌ | 3h |
| 12 | POST | `/auth/reset-password` | Đặt lại mật khẩu mới | ❌ | 3h |

> **Ghi chú**: Login (8h) phức tạp nhất do kiểm tra IP whitelist, failed attempts, workspace selection, JWT generation. Google SSO (8h) cần integrate Google OAuth2 + auto-create/link user.

---

## Module 2: Workspace Management (8 endpoints) — ⏱️ ~30h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/workspaces` | DS workspace của user | 🔒 | - | 3h |
| 2 | GET | `/workspaces/:id` | Chi tiết workspace | 🔒 | - | 2h |
| 3 | POST | `/workspaces` | Tạo workspace mới | 🔒 | - | 6h |
| 4 | PUT | `/workspaces/:id` | Cập nhật workspace | 🔒 | `workspace.update` | 2h |
| 5 | POST | `/workspaces/switch` | Chuyển workspace | 🔒 | - | 4h |
| 6 | POST | `/workspaces/:id/invite` | Mời user vào workspace | 🔒 | `workspace.invite` | 6h |
| 7 | POST | `/workspaces/accept-invite` | Chấp nhận lời mời | 🔒 | - | 4h |
| 8 | DELETE | `/workspaces/:id/leave` | Rời khỏi workspace | 🔒 | - | 3h |

> **Ghi chú**: Create workspace (6h) cần tạo default groups, settings, gán Owner. Invite (6h) gồm gửi email + token + idempotency.

---

## Module 3: Workspace IAM Settings (4 endpoints) — ⏱️ ~11h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/workspaces/:id/iam-settings` | Lấy cấu hình bảo mật | 🔒 | `settings.read` | 2h |
| 2 | PUT | `/workspaces/:id/iam-settings` | Cập nhật cấu hình | 🔒 | `settings.update` | 3h |
| 3 | PUT | `/workspaces/:id/iam-settings/ip-whitelist` | Cập nhật IP whitelist | 🔒 | `settings.update` | 3h |
| 4 | POST | `/workspaces/:id/iam-settings/test-ip` | Test IP có trong whitelist | 🔒 | `settings.read` | 3h |

> **Ghi chú**: IP whitelist (3h) cần validate CIDR notation + matching logic.

---

## Module 4: User Management (5 endpoints) — ⏱️ ~16h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/users` | DS users trong workspace | 🔒 | `user.read` | 4h |
| 2 | GET | `/users/:id` | Chi tiết user | 🔒 | `user.read` | 3h |
| 3 | PUT | `/users/:id/groups` | Gán groups cho user (N-N) | 🔒 | `user.update` | 4h |
| 4 | PUT | `/users/:id/status` | Activate/Deactivate user | 🔒 | `user.update` | 2h |
| 5 | DELETE | `/users/:id` | Xóa user khỏi workspace | 🔒 | `user.delete` | 3h |

> **Ghi chú**: GET users (4h) cần paging, search, filter + JOIN nhiều bảng. Assign groups (4h) xử lý N-N junction table.

---

## Module 5: User Profile (6 endpoints) — ⏱️ ~14h

| # | Method | Endpoint | Mô tả | Auth | ⏱️ Est |
|---|--------|----------|--------|------|--------|
| 1 | GET | `/profile` | Thông tin cá nhân | 🔒 | 2h |
| 2 | PUT | `/profile` | Cập nhật profile | 🔒 | 2h |
| 3 | POST | `/profile/change-password` | Đổi mật khẩu | 🔒 | 3h |
| 4 | DELETE | `/profile` | Xóa tài khoản (soft delete) | 🔒 | 3h |
| 5 | GET | `/profile/sessions` | DS phiên đăng nhập | 🔒 | 2h |
| 6 | DELETE | `/profile/sessions/:id` | Hủy phiên đăng nhập | 🔒 | 2h |

> **Ghi chú**: Change password (3h) cần verify old password + invalidate sessions. Delete account (3h) cần soft delete + cleanup sessions.

---

## Module 6: Two-Factor Authentication (6 endpoints) — ⏱️ ~24h

| # | Method | Endpoint | Mô tả | Auth | ⏱️ Est |
|---|--------|----------|--------|------|--------|
| 1 | POST | `/profile/2fa/setup` | Khởi tạo 2FA (QR code) | 🔒 | 6h |
| 2 | POST | `/profile/2fa/verify` | Verify & kích hoạt 2FA | 🔒 | 4h |
| 3 | POST | `/profile/2fa/disable` | Tắt 2FA | 🔒 | 3h |
| 4 | GET | `/profile/2fa/methods` | DS 2FA methods | 🔒 | 2h |
| 5 | POST | `/profile/2fa/backup-codes/generate` | Tạo mới backup codes | 🔒 | 4h |
| 6 | GET | `/profile/2fa/backup-codes` | Xem backup codes (masked) | 🔒 | 5h |

> **Ghi chú**: Setup (6h) cần generate TOTP secret + QR code. Backup codes (5h) cần hash + mask logic. Module này đòi hỏi thư viện TOTP (VD: OtpNet).

---

## Module 7: OAuth/SSO (3 endpoints) — ⏱️ ~10h

| # | Method | Endpoint | Mô tả | Auth | ⏱️ Est |
|---|--------|----------|--------|------|--------|
| 1 | GET | `/profile/logins` | DS provider đã liên kết | 🔒 | 2h |
| 2 | POST | `/profile/logins/google` | Liên kết Google account | 🔒 | 5h |
| 3 | DELETE | `/profile/logins/:provider` | Ngắt liên kết provider | 🔒 | 3h |

> **Ghi chú**: Link Google (5h) cần validate ID token + check duplicate. Unlink (3h) phải check đây không phải login method duy nhất.

---

## Module 8: User Groups (8 endpoints) — ⏱️ ~24h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/groups` | DS groups trong workspace | 🔒 | `group.read` | 3h |
| 2 | GET | `/groups/:id` | Chi tiết group + permissions | 🔒 | `group.read` | 3h |
| 3 | POST | `/groups` | Tạo group mới | 🔒 | `group.create` | 4h |
| 4 | PUT | `/groups/:id` | Cập nhật group | 🔒 | `group.update` | 2h |
| 5 | DELETE | `/groups/:id` | Xóa group | 🔒 | `group.delete` | 2h |
| 6 | GET | `/groups/:id/members` | DS thành viên trong group | 🔒 | `group.read` | 3h |
| 7 | GET | `/groups/:id/permissions` | DS quyền của group | 🔒 | `group.read` | 2h |
| 8 | PUT | `/groups/:id/permissions` | Cập nhật quyền cho group | 🔒 | `group.update` | 5h |

> **Ghi chú**: Update permissions (5h) phức tạp do validate hierarchy subset rule (child ⊆ parent). Create group (4h) cần validate hierarchy + default permissions.

---

## Module 9: Permissions (7 endpoints) — ⏱️ ~14h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/permissions` | DS tất cả permissions | 🔒 | `permission.read` | 3h |
| 2 | GET | `/permissions/:id` | Chi tiết permission | 🔒 | `permission.read` | 1h |
| 3 | POST | `/permissions` | Tạo permission mới | 🔒 | `permission.create` | 3h |
| 4 | PUT | `/permissions/:id` | Cập nhật permission | 🔒 | `permission.update` | 2h |
| 5 | DELETE | `/permissions/:id` | Xóa permission | 🔒 | `permission.delete` | 2h |
| 6 | GET | `/permissions/resources` | DS resources | 🔒 | `permission.read` | 1.5h |
| 7 | GET | `/permissions/actions` | DS actions | 🔒 | `permission.read` | 1.5h |

> **Ghi chú**: CRUD đơn giản. Delete (2h) cần check permission đang được group nào sử dụng trước khi xóa.

---

## Module 10: Audit Logs (4 endpoints) — ⏱️ ~14h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/audit-logs` | DS audit logs | 🔒 | `audit.read` | 4h |
| 2 | GET | `/audit-logs/:id` | Chi tiết audit log | 🔒 | `audit.read` | 2h |
| 3 | GET | `/audit-logs/users/:userId` | Audit logs theo user | 🔒 | `audit.read` | 2h |
| 4 | GET | `/audit-logs/export` | Export logs (CSV/JSON) | 🔒 | `audit.export` | 6h |

> **Ghi chú**: Export (6h) cần stream large dataset + generate CSV/JSON file download. GET list (4h) cần multi-filter + date range query.

---

## Module 11: API Keys (4 endpoints) — ⏱️ ~14h

| # | Method | Endpoint | Mô tả | Auth | Permission | ⏱️ Est |
|---|--------|----------|--------|------|------------|--------|
| 1 | GET | `/api-keys` | DS API keys | 🔒 | `apikey.read` | 2h |
| 2 | POST | `/api-keys` | Tạo API key mới | 🔒 | `apikey.create` | 6h |
| 3 | PUT | `/api-keys/:id` | Cập nhật API key | 🔒 | `apikey.update` | 3h |
| 4 | DELETE | `/api-keys/:id` | Revoke API key | 🔒 | `apikey.delete` | 3h |

> **Ghi chú**: Create (6h) phức tạp nhất: generate secure random key, show once, hash with bcrypt, validate scopes format.

---

## 📊 Tổng kết

| Module | Endpoints | ⏱️ Estimate | Ghi chú |
|--------|:---------:|:-----------:|----------|
| 1. Authentication | 12 | ~48h | Core phức tạp nhất |
| 2. Workspace Management | 8 | ~30h | Multi-tenant logic |
| 3. Workspace IAM Settings | 4 | ~11h | IP whitelist |
| 4. User Management | 5 | ~16h | CRUD + N-N groups |
| 5. User Profile | 6 | ~14h | Self-service |
| 6. Two-Factor Authentication | 6 | ~24h | TOTP + backup codes |
| 7. OAuth/SSO | 3 | ~10h | Google integration |
| 8. User Groups | 8 | ~24h | Hierarchy + permissions |
| 9. Permissions | 7 | ~14h | CRUD đơn giản |
| 10. Audit Logs | 4 | ~14h | Query + export |
| 11. API Keys | 4 | ~14h | Secure key generation |
| **Tổng cộng** | **67** | **~219h** | **~27.5 ngày (8h/ngày)** |

**Legend**: ❌ = No Auth | 🔑 Temp = Temporary Token | 🔒 = Bearer Token Required

> ⚠️ **Lưu ý**: Estimate trên chỉ tính **development time** (code + unit test). Chưa bao gồm: setup project/infra (~16h), integration test (~24h), code review, bug fixing. Tổng thực tế có thể **x1.3 ~ x1.5**.

---
---

# PART 2: CHI TIẾT TỪNG ENDPOINT

## Module 1: Authentication

### 1.1. POST `/auth/register`
> Đăng ký tài khoản mới bằng Email.

**Auth**: ❌ | **Idempotency**: ✅

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| email | string | ✅ | Email đăng nhập |
| password | string | ✅ | Mật khẩu (min 8 ký tự) |
| fullName | string | ✅ | Họ tên |

**Output**: `ApiResponse<RegisterResult>`
| Field | Type | Description |
|-------|------|-------------|
| userId | uuid | ID user mới |
| email | string | Email đã đăng ký |
| status | string | `"pending_verification"` |

**Notes**: Tạo user → gửi email verification token.

---

### 1.2. POST `/auth/verify-email`
> Xác thực email từ link trong email.

**Auth**: ❌

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| token | string | ✅ | Token từ email |

**Output**: `ApiResponse<object>` — chỉ có `success` + `message`

---

### 1.3. POST `/auth/resend-verification`
> Gửi lại email xác thực.

**Auth**: ❌ | **Idempotency**: ✅

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| email | string | ✅ | Email cần gửi lại verification |

**Output**: `ApiResponse<object>`

---

### 1.4. POST `/auth/login`
> Đăng nhập bằng Email/Password.

**Auth**: ❌

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| email | string | ✅ | Email |
| password | string | ✅ | Mật khẩu |
| workspaceId | uuid | ❌ | Chọn workspace (nếu có nhiều) |

**Output**: `ApiResponse<LoginResult>`
| Field | Type | Description |
|-------|------|-------------|
| accessToken | string | JWT access token |
| refreshToken | string | Refresh token |
| expiresIn | int | Thời hạn (giây) |
| user | object | `{ id, email, fullName, avatar }` |
| workspace | object | `{ id, name, code }` |
| requiresTwoFactor | bool | `true` nếu cần verify 2FA |

**Notes**: Nếu `requiresTwoFactor = true` → FE phải gọi `/auth/2fa/challenge`. Kiểm tra IP whitelist + failed attempts.

---

### 1.5. POST `/auth/google-login`
> Đăng nhập bằng Google SSO.

**Auth**: ❌

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| idToken | string | ✅ | Google ID token |
| workspaceId | uuid | ❌ | Chọn workspace |

**Output**: `ApiResponse<LoginResult>` — giống Login

---

### 1.6. POST `/auth/2fa/challenge`
> Verify mã 2FA trong quá trình login.

**Auth**: 🔑 Temporary token từ login

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| code | string | ✅ | Mã OTP 6 số |
| method | string | ✅ | `"totp"` / `"sms"` / `"email"` |

**Output**: `ApiResponse<LoginResult>` — full tokens

---

### 1.7. POST `/auth/2fa/backup-code`
> Dùng backup code bypass 2FA khi mất thiết bị.

**Auth**: 🔑 Temporary token từ login

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| code | string | ✅ | Backup code (VD: `A8F2-9X4K`) |

**Output**: `ApiResponse<LoginResult>` — full tokens

**Notes**: Code được đánh dấu `is_used = true` sau khi dùng.

---

### 1.8. POST `/auth/refresh-token`
> Làm mới access token.

**Auth**: ❌

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| refreshToken | string | ✅ | Refresh token hiện tại |

**Output**: `ApiResponse<TokenResult>`
| Field | Type | Description |
|-------|------|-------------|
| accessToken | string | JWT mới |
| refreshToken | string | Refresh token mới |
| expiresIn | int | Thời hạn (giây) |

---

### 1.9. POST `/auth/logout`
> Đăng xuất session hiện tại.

**Auth**: 🔒

**Input**: None

**Output**: `ApiResponse<object>`

---

### 1.10. POST `/auth/logout-all`
> Đăng xuất tất cả thiết bị.

**Auth**: 🔒

**Input**: None

**Output**: `ApiResponse<LogoutAllResult>`
| Field | Type | Description |
|-------|------|-------------|
| sessionsTerminated | int | Số sessions đã hủy |

---

### 1.11. POST `/auth/forgot-password`
> Gửi email reset mật khẩu.

**Auth**: ❌ | **Idempotency**: ✅

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| email | string | ✅ | Email cần reset |

**Output**: `ApiResponse<object>`

---

### 1.12. POST `/auth/reset-password`
> Đặt lại mật khẩu bằng token.

**Auth**: ❌

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| token | string | ✅ | Token từ email |
| newPassword | string | ✅ | Mật khẩu mới (min 8 ký tự) |

**Output**: `ApiResponse<object>`

---

## Module 2: Workspace Management

### 2.1. GET `/workspaces`
> Danh sách workspace của user hiện tại.

**Auth**: 🔒 | **Response**: `PagedResponse<WorkspaceItem>`

**Query Params**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| pageNumber | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang |
| sortBy | string | `lastAccessed` | `name` / `lastAccessed` / `createdAt` |

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID workspace |
| name | string | Tên workspace |
| code | string | Mã workspace |
| imageUrl | string | Logo URL |
| status | string | `active` / `trial` / `inactive` |
| isDefault | bool | Workspace mặc định? |
| lastAccessedAt | datetime | Lần truy cập cuối |

---

### 2.2. GET `/workspaces/:id`
> Chi tiết workspace.

**Auth**: 🔒 | **Response**: `ApiResponse<WorkspaceDetail>`

**Data**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID |
| name | string | Tên |
| code | string | Mã |
| imageUrl | string | Logo |
| status | string | Trạng thái |
| memberCount | int | Số thành viên |
| createdAt | datetime | Ngày tạo |

---

### 2.3. POST `/workspaces`
> Tạo workspace mới. User tạo tự động là Owner.

**Auth**: 🔒 | **Response**: `ApiResponse<WorkspaceDetail>`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ✅ | Tên workspace (max 100) |
| code | string | ✅ | Mã unique (max 50) |
| imageUrl | string | ❌ | Logo URL |

---

### 2.4. PUT `/workspaces/:id`
> Cập nhật workspace.

**Auth**: 🔒 | **Permission**: `workspace.update` | **Response**: `ApiResponse<WorkspaceDetail>`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ❌ | Tên mới |
| imageUrl | string | ❌ | Logo mới |

**Notes**: `code` không thể thay đổi.

---

### 2.5. POST `/workspaces/switch`
> Chuyển sang workspace khác, cấp token mới.

**Auth**: 🔒 | **Response**: `ApiResponse<LoginResult>`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| workspaceId | uuid | ✅ | Workspace cần chuyển |

---

### 2.6. POST `/workspaces/:id/invite`
> Mời user vào workspace qua email.

**Auth**: 🔒 | **Permission**: `workspace.invite` | **Idempotency**: ✅

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| email | string | ✅ | Email người được mời |
| groupId | uuid | ❌ | Group dự kiến |

**Output**: `ApiResponse<InvitationResult>`
| Field | Type | Description |
|-------|------|-------------|
| invitationId | uuid | ID lời mời |
| email | string | Email |
| expiresAt | datetime | Hết hạn |
| status | string | `"pending"` |

---

### 2.7. POST `/workspaces/accept-invite`
> Chấp nhận lời mời tham gia workspace.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| token | string | ✅ | Token từ email mời |

**Output**: `ApiResponse<object>`

---

### 2.8. DELETE `/workspaces/:id/leave`
> Rời khỏi workspace.

**Auth**: 🔒

**Input**: None | **Output**: `ApiResponse<object>`

**Notes**: Owner không thể leave.

---

## Module 3: Workspace IAM Settings

### 3.1. GET `/workspaces/:id/iam-settings`
> Lấy cấu hình bảo mật workspace.

**Auth**: 🔒 | **Permission**: `settings.read` | **Response**: `ApiResponse<IamSettings>`

**Data**:
| Field | Type | Description |
|-------|------|-------------|
| workspaceId | uuid | ID workspace |
| enableIpWhitelist | bool | Bật IP whitelist? |
| whitelistIps | string[] | DS IP/CIDR |

---

### 3.2. PUT `/workspaces/:id/iam-settings`
> Cập nhật toàn bộ cấu hình.

**Auth**: 🔒 | **Permission**: `settings.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| enableIpWhitelist | bool | ❌ | Bật/tắt |
| whitelistIps | string[] | ❌ | DS IP/CIDR |

**Output**: `ApiResponse<IamSettings>`

---

### 3.3. PUT `/workspaces/:id/iam-settings/ip-whitelist`
> Cập nhật riêng IP whitelist.

**Auth**: 🔒 | **Permission**: `settings.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| whitelistIps | string[] | ✅ | DS IP/CIDR mới |

**Output**: `ApiResponse<IamSettings>`

---

### 3.4. POST `/workspaces/:id/iam-settings/test-ip`
> Kiểm tra IP có trong whitelist không.

**Auth**: 🔒 | **Permission**: `settings.read`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| ipAddress | string | ✅ | IP cần test |

**Output**: `ApiResponse<IpTestResult>`
| Field | Type | Description |
|-------|------|-------------|
| allowed | bool | Có trong whitelist? |
| ipAddress | string | IP đã test |
| matchedRule | string | Rule match (nếu có) |

---

## Module 4: User Management

### 4.1. GET `/users`
> Danh sách users trong workspace hiện tại.

**Auth**: 🔒 | **Permission**: `user.read` | **Response**: `PagedResponse<UserItem>`

**Query Params**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| pageNumber | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang |
| status | string | - | `active` / `inactive` / `suspended` |
| groupId | uuid | - | Filter theo group |
| search | string | - | Tìm theo tên/email |

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID user |
| email | string | Email |
| fullName | string | Họ tên |
| avatarUrl | string | Avatar |
| status | string | Trạng thái |
| groups | array | `[{ id, name, code }]` |
| lastAccessedAt | datetime | Truy cập cuối |

---

### 4.2. GET `/users/:id`
> Chi tiết user trong workspace.

**Auth**: 🔒 | **Permission**: `user.read` | **Response**: `ApiResponse<UserDetail>`

**Data**: Giống UserItem + thêm `phone`, `address`, `permissions[]`, `joinedAt`.

---

### 4.3. PUT `/users/:id/groups`
> Gán nhiều groups cho user (quan hệ N-N).

**Auth**: 🔒 | **Permission**: `user.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| groupIds | uuid[] | ✅ | DS group IDs (ghi đè toàn bộ) |

**Output**: `ApiResponse<UserGroupsResult>`

**Notes**: Pass `[]` rỗng để remove tất cả groups.

---

### 4.4. PUT `/users/:id/status`
> Activate/Deactivate user trong workspace.

**Auth**: 🔒 | **Permission**: `user.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| status | string | ✅ | `"active"` / `"inactive"` / `"suspended"` |

**Output**: `ApiResponse<object>`

---

### 4.5. DELETE `/users/:id`
> Xóa user khỏi workspace (soft delete).

**Auth**: 🔒 | **Permission**: `user.delete`

**Input**: None | **Output**: `ApiResponse<object>`

**Notes**: Owner không thể bị remove.

---

## Module 5: User Profile

### 5.1. GET `/profile`
> Thông tin cá nhân user hiện tại.

**Auth**: 🔒 | **Response**: `ApiResponse<ProfileDetail>`

**Data**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID user |
| email | string | Email |
| fullName | string | Họ tên |
| phone | string | Số ĐT |
| avatarUrl | string | Avatar |
| address | string | Địa chỉ |
| emailVerified | bool | Đã verify email? |
| twoFactorEnabled | bool | Đã bật 2FA? |

---

### 5.2. PUT `/profile`
> Cập nhật profile cá nhân.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| fullName | string | ❌ | Họ tên |
| phone | string | ❌ | SĐT |
| avatarUrl | string | ❌ | Avatar URL |
| address | string | ❌ | Địa chỉ |

**Output**: `ApiResponse<ProfileDetail>`

---

### 5.3. POST `/profile/change-password`
> Đổi mật khẩu.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| currentPassword | string | ✅ | Mật khẩu hiện tại |
| newPassword | string | ✅ | Mật khẩu mới (min 8) |

**Output**: `ApiResponse<object>`

**Notes**: Vô hiệu tất cả sessions khác.

---

### 5.4. DELETE `/profile`
> Xóa tài khoản (soft delete).

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| password | string | ✅ | Xác nhận mật khẩu |

**Output**: `ApiResponse<object>`

---

### 5.5. GET `/profile/sessions`
> DS phiên đăng nhập đang active.

**Auth**: 🔒 | **Response**: `ApiResponse<List<SessionItem>>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Session ID |
| deviceName | string | "Chrome on Windows" |
| ipAddress | string | IP |
| isTrustedDevice | bool | Thiết bị tin cậy? |
| lastActivity | datetime | Hoạt động cuối |
| isCurrent | bool | Session hiện tại? |

---

### 5.6. DELETE `/profile/sessions/:id`
> Hủy 1 phiên đăng nhập.

**Auth**: 🔒

**Input**: None | **Output**: `ApiResponse<object>`

---

## Module 6: Two-Factor Authentication (2FA)

### 6.1. POST `/profile/2fa/setup`
> Khởi tạo 2FA, trả về QR code (chưa enable).

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| method | string | ✅ | `"totp"` / `"sms"` / `"email"` |

**Output**: `ApiResponse<TwoFactorSetupResult>`
| Field | Type | Description |
|-------|------|-------------|
| method | string | Loại 2FA |
| secret | string | TOTP secret (chỉ cho totp) |
| qrCodeUrl | string | QR code base64 (chỉ cho totp) |

---

### 6.2. POST `/profile/2fa/verify`
> Xác thực & kích hoạt 2FA.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| method | string | ✅ | `"totp"` / `"sms"` / `"email"` |
| code | string | ✅ | Mã OTP 6 số |

**Output**: `ApiResponse<TwoFactorVerifyResult>`
| Field | Type | Description |
|-------|------|-------------|
| backupCodes | string[] | 10 mã backup (hiển thị 1 lần) |

---

### 6.3. POST `/profile/2fa/disable`
> Tắt 2FA.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| password | string | ✅ | Mật khẩu xác nhận |

**Output**: `ApiResponse<object>`

---

### 6.4. GET `/profile/2fa/methods`
> DS 2FA methods đang enabled.

**Auth**: 🔒 | **Response**: `ApiResponse<List<TwoFactorMethod>>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| method | string | totp/sms/email |
| enabled | bool | Đang active? |
| verifiedAt | datetime | Lần verify đầu |
| lastUsedAt | datetime | Lần dùng cuối |

---

### 6.5. POST `/profile/2fa/backup-codes/generate`
> Tạo mới backup codes (hủy codes cũ).

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| password | string | ✅ | Xác nhận mật khẩu |

**Output**: `ApiResponse<BackupCodesResult>`
| Field | Type | Description |
|-------|------|-------------|
| backupCodes | string[] | 10 mã mới |

---

### 6.6. GET `/profile/2fa/backup-codes`
> Xem backup codes chưa dùng (masked).

**Auth**: 🔒 | **Response**: `ApiResponse<BackupCodesStatus>`

**Data**:
| Field | Type | Description |
|-------|------|-------------|
| codes | array | `[{ code: "A8F2-****", isUsed: false }]` |
| remainingCodes | int | Số codes còn lại |

---

## Module 7: OAuth/SSO

### 7.1. GET `/profile/logins`
> DS provider đã liên kết.

**Auth**: 🔒 | **Response**: `ApiResponse<List<LinkedAccount>>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| provider | string | `"google"` |
| providerDisplayName | string | Email/Name trên provider |
| linkedAt | datetime | Ngày liên kết |

---

### 7.2. POST `/profile/logins/google`
> Liên kết tài khoản Google.

**Auth**: 🔒

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| idToken | string | ✅ | Google ID Token |

**Output**: `ApiResponse<object>`

---

### 7.3. DELETE `/profile/logins/:provider`
> Ngắt liên kết provider.

**Auth**: 🔒

**Input**: None | **Output**: `ApiResponse<object>`

**Notes**: Không thể unlink nếu là phương thức đăng nhập duy nhất.

---

## Module 8: User Groups

### 8.1. GET `/groups`
> DS groups trong workspace hiện tại.

**Auth**: 🔒 | **Permission**: `group.read` | **Response**: `PagedResponse<GroupItem>`

**Query Params**:
| Param | Type | Default | Description |
|-------|------|---------|-------------|
| pageNumber | int | 1 | Trang |
| pageSize | int | 20 | Số item/trang |
| status | string | - | `Active` / `Inactive` |
| parentId | uuid | - | Filter theo group cha |

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID group |
| name | string | Tên |
| code | string | Mã |
| level | int | Cấp (1=Cao nhất) |
| parentId | uuid | Group cha |
| status | string | Active/Inactive |
| memberCount | int | Số thành viên |
| permissionCount | int | Số quyền |

---

### 8.2. GET `/groups/:id`
> Chi tiết group + danh sách permissions.

**Auth**: 🔒 | **Permission**: `group.read` | **Response**: `ApiResponse<GroupDetail>`

**Data**: Giống GroupItem + `description`, `permissions[]`, `createdAt`.

---

### 8.3. POST `/groups`
> Tạo group mới.

**Auth**: 🔒 | **Permission**: `group.create`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ✅ | Tên group |
| code | string | ✅ | Mã unique |
| level | int | ✅ | Cấp (1=Cao) |
| parentId | uuid | ❌ | Group cha |
| description | string | ❌ | Mô tả |

**Output**: `ApiResponse<GroupDetail>`

**Notes**: Permissions(child) ⊆ Permissions(parent).

---

### 8.4. PUT `/groups/:id`
> Cập nhật group.

**Auth**: 🔒 | **Permission**: `group.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ❌ | Tên |
| description | string | ❌ | Mô tả |
| status | string | ❌ | `Active` / `Inactive` |

**Output**: `ApiResponse<GroupDetail>`

**Notes**: `code`, `level`, `parentId` không thay đổi được.

---

### 8.5. DELETE `/groups/:id`
> Xóa group (chỉ khi không có user).

**Auth**: 🔒 | **Permission**: `group.delete`

**Input**: None | **Output**: `ApiResponse<object>`

---

### 8.6. GET `/groups/:id/members`
> DS thành viên trong group.

**Auth**: 🔒 | **Permission**: `group.read` | **Response**: `PagedResponse<MemberItem>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| userId | uuid | ID user |
| email | string | Email |
| fullName | string | Họ tên |
| assignedAt | datetime | Ngày gán |

---

### 8.7. GET `/groups/:id/permissions`
> DS quyền của group.

**Auth**: 🔒 | **Permission**: `group.read` | **Response**: `ApiResponse<List<PermissionItem>>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Permission ID |
| code | string | `"user.create"` |
| name | string | Tên |
| resource | string | Resource |
| action | string | Action |
| category | string | Module |

---

### 8.8. PUT `/groups/:id/permissions`
> Cập nhật quyền cho group (ghi đè toàn bộ).

**Auth**: 🔒 | **Permission**: `group.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| permissionIds | uuid[] | ✅ | DS permission IDs |

**Output**: `ApiResponse<object>`

**Notes**: Validate subset rule nếu có parent group.

---

## Module 9: Permissions

### 9.1. GET `/permissions`
> DS tất cả permissions hệ thống.

**Auth**: 🔒 | **Permission**: `permission.read` | **Response**: `PagedResponse<PermissionItem>`

**Query Params**:
| Param | Type | Description |
|-------|------|-------------|
| category | string | Filter theo module |
| resource | string | Filter theo resource |
| action | string | Filter theo action |
| pageNumber | int | Trang |
| pageSize | int | Số item/trang |

---

### 9.2. GET `/permissions/:id`
> Chi tiết permission.

**Auth**: 🔒 | **Permission**: `permission.read` | **Response**: `ApiResponse<PermissionDetail>`

---

### 9.3. POST `/permissions`
> Tạo permission mới (System Admin only).

**Auth**: 🔒 | **Permission**: `permission.create`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| code | string | ✅ | Mã unique (`user.create`) |
| name | string | ✅ | Tên |
| resource | string | ✅ | Resource (`users`) |
| action | string | ✅ | Action (`create`) |
| category | string | ❌ | Module (`CRM`) |
| description | string | ❌ | Mô tả |
| displayOrder | int | ❌ | Thứ tự hiển thị |

**Output**: `ApiResponse<PermissionDetail>`

---

### 9.4. PUT `/permissions/:id`
> Cập nhật permission.

**Auth**: 🔒 | **Permission**: `permission.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ❌ | Tên |
| description | string | ❌ | Mô tả |
| category | string | ❌ | Module |
| displayOrder | int | ❌ | Thứ tự |

**Output**: `ApiResponse<PermissionDetail>`

**Notes**: `code`, `resource`, `action` không thay đổi được.

---

### 9.5. DELETE `/permissions/:id`
> Xóa permission (nếu chưa dùng).

**Auth**: 🔒 | **Permission**: `permission.delete`

**Input**: None | **Output**: `ApiResponse<object>`

**Notes**: System permissions (`is_system = true`) không xóa được.

---

### 9.6. GET `/permissions/resources`
> DS resources hiện có.

**Auth**: 🔒 | **Permission**: `permission.read`

**Output**: `ApiResponse<List<string>>`

---

### 9.7. GET `/permissions/actions`
> DS actions hiện có.

**Auth**: 🔒 | **Permission**: `permission.read`

**Output**: `ApiResponse<List<string>>`

---

## Module 10: Audit Logs

### 10.1. GET `/audit-logs`
> DS audit logs trong workspace.

**Auth**: 🔒 | **Permission**: `audit.read` | **Response**: `PagedResponse<AuditLogItem>`

**Query Params**:
| Param | Type | Description |
|-------|------|-------------|
| pageNumber | int | Trang |
| pageSize | int | Số item/trang |
| userId | uuid | Filter theo user |
| eventType | string | `Login` / `Logout` / `RoleAssign`... |
| eventStatus | string | `Success` / `Failed` |
| startDate | datetime | Từ ngày |
| endDate | datetime | Đến ngày |

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Log ID |
| userId | uuid | User ID |
| userName | string | Tên user |
| eventType | string | Loại event |
| eventStatus | string | Success/Failed |
| ipAddress | string | IP |
| details | object | Chi tiết (JSONB) |
| createdAt | datetime | Thời gian |

---

### 10.2. GET `/audit-logs/:id`
> Chi tiết audit log.

**Auth**: 🔒 | **Permission**: `audit.read` | **Response**: `ApiResponse<AuditLogDetail>`

---

### 10.3. GET `/audit-logs/users/:userId`
> Audit logs của 1 user cụ thể.

**Auth**: 🔒 | **Permission**: `audit.read` | **Response**: `PagedResponse<AuditLogItem>`

---

### 10.4. GET `/audit-logs/export`
> Export audit logs ra file.

**Auth**: 🔒 | **Permission**: `audit.export`

**Query Params**:
| Param | Type | Description |
|-------|------|-------------|
| format | string | `csv` / `json` |
| startDate | datetime | Từ ngày |
| endDate | datetime | Đến ngày |

**Output**: File download (CSV/JSON)

---

## Module 11: API Keys

### 11.1. GET `/api-keys`
> DS API keys của workspace.

**Auth**: 🔒 | **Permission**: `apikey.read` | **Response**: `PagedResponse<ApiKeyItem>`

**Data Item**:
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID |
| name | string | Tên key |
| keyPrefix | string | `"sk_live_"` |
| scopes | string[] | `["crm:*"]` |
| isActive | bool | Còn active? |
| lastUsedAt | datetime | Lần dùng cuối |
| expiresAt | datetime | Hạn |

---

### 11.2. POST `/api-keys`
> Tạo API key mới.

**Auth**: 🔒 | **Permission**: `apikey.create`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ✅ | Tên |
| description | string | ❌ | Mô tả |
| scopes | string[] | ✅ | VD: `["crm:read", "calls:*"]` |
| expiresAt | datetime | ❌ | Ngày hết hạn |

**Output**: `ApiResponse<ApiKeyCreateResult>`
| Field | Type | Description |
|-------|------|-------------|
| id | uuid | ID |
| apiKey | string | ⚠️ Full key (hiển thị 1 lần duy nhất) |
| keyPrefix | string | Prefix |
| scopes | string[] | Scopes |

---

### 11.3. PUT `/api-keys/:id`
> Cập nhật API key.

**Auth**: 🔒 | **Permission**: `apikey.update`

**Input (Body)**:
| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| name | string | ❌ | Tên |
| description | string | ❌ | Mô tả |
| scopes | string[] | ❌ | Scopes mới |
| isActive | bool | ❌ | Active? |

**Output**: `ApiResponse<ApiKeyItem>`

---

### 11.4. DELETE `/api-keys/:id`
> Revoke API key.

**Auth**: 🔒 | **Permission**: `apikey.delete`

**Input**: None | **Output**: `ApiResponse<object>`

**Notes**: Set `revoked_at` + `is_active = false`.

---

## 🔒 HTTP Status Codes

| Code | Meaning |
|:----:|---------|
| 200 | Thành công |
| 201 | Tạo mới thành công |
| 400 | Input không hợp lệ |
| 401 | Chưa đăng nhập / Token hết hạn |
| 403 | Không có quyền |
| 404 | Không tìm thấy |
| 409 | Trùng lặp (email, code) |
| 429 | Rate limit |
| 500 | Lỗi server |

---

**Version**: 7.0 (UUID Migration + 2FA + API Keys)  
**End of Document**
