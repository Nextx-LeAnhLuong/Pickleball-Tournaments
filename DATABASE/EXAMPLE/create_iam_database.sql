-- =====================================================
-- IAM Service Database Migration Script
-- Database: iam_db
-- Version: 7.0 (UUID Migration + Full Schema Update)
-- Date: 2026-02-23
-- Features: UUID IDs, Multi-Group N-N, 2FA, API Keys,
--           Workspace IAM Settings, Soft Delete, Idempotency
-- =====================================================

-- Requires: pgcrypto extension for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- TABLE 1: workspaces (Lightweight - Login Only)
-- Lưu thông tin tối thiểu về workspace, chỉ phục vụ login/auth.
-- Các trường business logic thuộc Operator Service.
-- =====================================================

CREATE TABLE workspaces (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    image_url VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'trial',
    services VARCHAR(50) DEFAULT 'iam',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP,
    deleted_at TIMESTAMP,
    created_by UUID,
    updated_by UUID,
    deleted_by UUID,

    CONSTRAINT chk_workspace_status CHECK (status IN ('active', 'inactive', 'trial'))
);

CREATE UNIQUE INDEX idx_workspaces_code ON workspaces(code) WHERE deleted_at IS NULL;
CREATE INDEX idx_workspaces_status ON workspaces(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_workspaces_deleted_at ON workspaces(deleted_at);

COMMENT ON TABLE workspaces IS 'Quản lý Workspace tối thiểu cho auth flow (tên, logo, status). Business logic thuộc Operator Service.';

-- =====================================================
-- TABLE 2: workspace_iam_settings (IP Whitelist Only)
-- Cấu hình IP Whitelist cho từng Workspace.
-- =====================================================

CREATE TABLE workspace_iam_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    enable_ip_whitelist BOOLEAN DEFAULT FALSE,
    whitelist_ips TEXT,

    CONSTRAINT uq_workspace_iam_settings UNIQUE (workspace_id)
);

COMMENT ON TABLE workspace_iam_settings IS 'Cấu hình IP Whitelist cho từng Workspace. Mỗi workspace có đúng 1 bản ghi settings.';

-- =====================================================
-- TABLE 3: users (Global Identity)
-- Lưu thông tin định danh toàn cục, không gắn chặt với Workspace.
-- =====================================================

CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    avatar_url VARCHAR(500),
    address VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'unverified',
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMP,
    last_login_ip VARCHAR(45),
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    password_changed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    deleted_by UUID REFERENCES users(id),

    CONSTRAINT chk_user_status CHECK (status IN ('active', 'inactive', 'locked', 'unverified'))
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

COMMENT ON TABLE users IS 'Thông tin định danh toàn cục. User tồn tại độc lập với Workspace.';

-- Add FK for workspaces.created_by/updated_by/deleted_by after users table exists
ALTER TABLE workspaces ADD CONSTRAINT fk_workspaces_created_by FOREIGN KEY (created_by) REFERENCES users(id);
ALTER TABLE workspaces ADD CONSTRAINT fk_workspaces_updated_by FOREIGN KEY (updated_by) REFERENCES users(id);
ALTER TABLE workspaces ADD CONSTRAINT fk_workspaces_deleted_by FOREIGN KEY (deleted_by) REFERENCES users(id);

-- =====================================================
-- TABLE 4: user_groups (Organizational & Functional Units)
-- Group đóng vai trò là Role. Cấu trúc phân cấp (Hierarchy).
-- =====================================================

CREATE TABLE user_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    level INTEGER NOT NULL,
    parent_id UUID REFERENCES user_groups(id),
    workspace_id UUID NOT NULL REFERENCES workspaces(id),
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    deleted_by UUID REFERENCES users(id),

    CONSTRAINT chk_group_status CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX idx_user_groups_code ON user_groups(code) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_user_groups_ws_name ON user_groups(workspace_id, name) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_groups_workspace_status ON user_groups(workspace_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_groups_parent_id ON user_groups(parent_id);
CREATE INDEX idx_user_groups_level ON user_groups(level);

COMMENT ON TABLE user_groups IS 'Nhóm người dùng (đóng vai trò Role). Hỗ trợ hierarchy: Permissions(Child) ⊆ Permissions(Parent).';

-- =====================================================
-- TABLE 5: permissions
-- Danh sách quyền hạn trong hệ thống.
-- =====================================================

CREATE TABLE permissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    category VARCHAR(50),
    display_order INTEGER,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    deleted_by UUID REFERENCES users(id)
);

CREATE UNIQUE INDEX idx_permissions_code ON permissions(code) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_permissions_resource_action ON permissions(resource, action) WHERE deleted_at IS NULL;
CREATE INDEX idx_permissions_category_order ON permissions(category, display_order);
CREATE INDEX idx_permissions_is_system ON permissions(is_system);

COMMENT ON TABLE permissions IS 'Danh sách quyền hạn hệ thống. Hỗ trợ category + display_order cho UI.';

-- =====================================================
-- TABLE 6: group_permissions (Junction Table)
-- Mapping trực tiếp giữa User Groups và Permissions.
-- =====================================================

CREATE TABLE group_permissions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),

    CONSTRAINT uq_group_permission UNIQUE (group_id, permission_id)
);

CREATE INDEX idx_group_permissions_group_id ON group_permissions(group_id);
CREATE INDEX idx_group_permissions_permission_id ON group_permissions(permission_id);

COMMENT ON TABLE group_permissions IS 'Junction table: Group ↔ Permission (N-N).';

-- =====================================================
-- TABLE 7: workspace_users (User-Workspace Junction)
-- Quản lý quyền truy cập của User vào từng Workspace.
-- =====================================================

CREATE TABLE workspace_users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workspace_id UUID NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    idempotency_key VARCHAR(100) UNIQUE,
    last_accessed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    deleted_by UUID REFERENCES users(id),

    CONSTRAINT chk_ws_user_status CHECK (status IN ('active', 'inactive', 'suspended'))
);

CREATE UNIQUE INDEX idx_workspace_users_uq ON workspace_users(user_id, workspace_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_workspace_users_ws_status ON workspace_users(workspace_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_workspace_users_user_default ON workspace_users(user_id, is_default);
CREATE INDEX idx_workspace_users_user_accessed ON workspace_users(user_id, last_accessed_at DESC);
CREATE INDEX idx_workspace_users_idempotency ON workspace_users(idempotency_key);

COMMENT ON TABLE workspace_users IS 'Junction table: User ↔ Workspace. Group gán qua workspace_user_groups (N-N).';

-- =====================================================
-- TABLE 8: workspace_user_groups (User-Group N-N Junction)
-- Một user có thể thuộc nhiều groups trong 1 workspace.
-- =====================================================

CREATE TABLE workspace_user_groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_user_id UUID NOT NULL REFERENCES workspace_users(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),

    CONSTRAINT uq_workspace_user_group UNIQUE (workspace_user_id, group_id)
);

CREATE INDEX idx_wug_workspace_user_id ON workspace_user_groups(workspace_user_id);
CREATE INDEX idx_wug_group_id ON workspace_user_groups(group_id);

COMMENT ON TABLE workspace_user_groups IS 'Junction N-N: User ↔ Groups trong workspace. Permissions = UNION(all Group Permissions).';

-- =====================================================
-- TABLE 9: user_sessions
-- Quản lý phiên đăng nhập.
-- =====================================================

CREATE TABLE user_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workspace_id UUID,
    token VARCHAR(500) UNIQUE NOT NULL,
    refresh_token VARCHAR(500) UNIQUE,
    device_id VARCHAR(255),
    device_name VARCHAR(255),
    is_trusted_device BOOLEAN DEFAULT FALSE,
    ip_address VARCHAR(45) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    idempotency_key VARCHAR(100) UNIQUE,
    last_activity TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token);
CREATE INDEX idx_user_sessions_refresh_token ON user_sessions(refresh_token);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_idempotency ON user_sessions(idempotency_key);

COMMENT ON TABLE user_sessions IS 'Phiên đăng nhập. workspace_id = context workspace hiện tại.';

-- =====================================================
-- TABLE 10: password_reset_tokens
-- Token khôi phục mật khẩu.
-- =====================================================

CREATE TABLE password_reset_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    idempotency_key VARCHAR(100) UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_password_reset_user_id ON password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_token ON password_reset_tokens(token);

COMMENT ON TABLE password_reset_tokens IS 'Token khôi phục mật khẩu (TTL ~1h).';

-- =====================================================
-- TABLE 11: invitations
-- Lời mời tham gia Workspace qua Email.
-- =====================================================

CREATE TABLE invitations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    idempotency_key VARCHAR(100) UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    invited_by UUID REFERENCES users(id) ON DELETE SET NULL,

    CONSTRAINT chk_invitation_status CHECK (status IN ('pending', 'accepted', 'expired', 'declined'))
);

CREATE INDEX idx_invitations_email ON invitations(email);
CREATE INDEX idx_invitations_workspace_id ON invitations(workspace_id);
CREATE INDEX idx_invitations_token ON invitations(token);
CREATE INDEX idx_invitations_idempotency ON invitations(idempotency_key);

COMMENT ON TABLE invitations IS 'Lời mời tham gia Workspace qua Email (TTL ~48h).';

-- =====================================================
-- TABLE 12: email_verification_tokens
-- Token xác thực email khi đăng ký.
-- =====================================================

CREATE TABLE email_verification_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    idempotency_key VARCHAR(100) UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_email_verification_user_id ON email_verification_tokens(user_id);
CREATE INDEX idx_email_verification_token ON email_verification_tokens(token);

COMMENT ON TABLE email_verification_tokens IS 'Token xác thực email chính chủ (TTL ~24h).';

-- =====================================================
-- TABLE 13: iam_audit_logs
-- Audit logs chuyên biệt cho IAM.
-- =====================================================

CREATE TABLE iam_audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    workspace_id UUID,
    event_type VARCHAR(50) NOT NULL,
    event_status VARCHAR(20) NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_audit_status CHECK (event_status IN ('success', 'failed'))
);

CREATE INDEX idx_iam_audit_user_id ON iam_audit_logs(user_id);
CREATE INDEX idx_iam_audit_workspace_id ON iam_audit_logs(workspace_id);
CREATE INDEX idx_iam_audit_event_type ON iam_audit_logs(event_type);
CREATE INDEX idx_iam_audit_created_at ON iam_audit_logs(created_at);

COMMENT ON TABLE iam_audit_logs IS 'Audit logs chuyên biệt cho IAM (Login, Logout, RoleAssign...).';

-- =====================================================
-- TABLE 14: oauth_accounts (OAuth/SSO Linked Accounts)
-- Lưu thông tin đăng nhập từ OAuth Providers.
-- =====================================================

CREATE TABLE oauth_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    provider_key VARCHAR(255) NOT NULL,
    provider_display_name VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_oauth_provider_key UNIQUE (provider, provider_key),
    CONSTRAINT uq_oauth_user_provider UNIQUE (user_id, provider)
);

CREATE INDEX idx_oauth_accounts_user_id ON oauth_accounts(user_id);

COMMENT ON TABLE oauth_accounts IS 'Liên kết tài khoản OAuth/SSO (Google, Facebook...).';

-- =====================================================
-- TABLE 15: user_two_factor_auth (2FA Methods)
-- Quản lý phương thức xác thực 2 lớp.
-- =====================================================

CREATE TABLE user_two_factor_auth (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    method VARCHAR(20) NOT NULL,
    secret_key VARCHAR(500),
    is_verified BOOLEAN DEFAULT FALSE,
    enabled BOOLEAN DEFAULT FALSE,
    backup_phone VARCHAR(20),
    verified_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_user_2fa_method UNIQUE (user_id, method),
    CONSTRAINT chk_2fa_method CHECK (method IN ('totp', 'sms', 'email'))
);

CREATE INDEX idx_user_2fa_user_id ON user_two_factor_auth(user_id);

COMMENT ON TABLE user_two_factor_auth IS 'Phương thức 2FA (TOTP, SMS, Email). secret_key phải được mã hóa (encrypted) khi lưu.';

-- =====================================================
-- TABLE 16: user_backup_codes (Recovery Codes)
-- Mã khôi phục dự phòng cho 2FA.
-- =====================================================

CREATE TABLE user_backup_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash VARCHAR(255) UNIQUE NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP,
    used_ip VARCHAR(45),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_backup_codes_user_unused ON user_backup_codes(user_id, is_used);

COMMENT ON TABLE user_backup_codes IS 'Backup codes cho 2FA (8-10 codes, hash bằng BCrypt/SHA256, dùng 1 lần).';

-- =====================================================
-- TABLE 17: api_keys (Public API Authentication)
-- Quản lý API Keys cho External Applications.
-- =====================================================

CREATE TABLE api_keys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    key_prefix VARCHAR(16) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    scopes TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    revoked_at TIMESTAMP,
    revoked_by UUID REFERENCES users(id),

    CONSTRAINT chk_apikey_active_revoked CHECK (is_active = FALSE OR revoked_at IS NULL),
    CONSTRAINT chk_apikey_scopes CHECK (scopes IS NULL OR cardinality(scopes) > 0)
);

CREATE INDEX idx_api_keys_workspace_active ON api_keys(workspace_id, is_active);
CREATE INDEX idx_api_keys_prefix ON api_keys(key_prefix);
CREATE INDEX idx_api_keys_expires ON api_keys(expires_at) WHERE expires_at IS NOT NULL;

COMMENT ON TABLE api_keys IS 'API Keys cho external integrations. key_hash = bcrypt/argon2. Key chỉ hiển thị 1 lần khi tạo.';

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_workspaces_updated_at BEFORE UPDATE ON workspaces FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_groups_updated_at BEFORE UPDATE ON user_groups FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_permissions_updated_at BEFORE UPDATE ON permissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workspace_users_updated_at BEFORE UPDATE ON workspace_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_2fa_updated_at BEFORE UPDATE ON user_two_factor_auth FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- SEED DATA
-- =====================================================

-- 1. Seed Workspaces
INSERT INTO workspaces (name, code, status) VALUES
('System Workspace', 'SYS', 'active'),
('NextX Corporation', 'NEXTX', 'trial');

-- 2. Seed Workspace IAM Settings (mỗi workspace 1 bản ghi)
INSERT INTO workspace_iam_settings (workspace_id, enable_ip_whitelist)
SELECT id, FALSE FROM workspaces;

-- 3. Seed Users
INSERT INTO users (email, full_name, status, email_verified, two_factor_enabled) VALUES
('admin@system.com', 'System Admin', 'active', TRUE, FALSE),
('boss@nextx.com', 'Mr Boss', 'active', TRUE, FALSE);

-- 4. Seed User Groups
INSERT INTO user_groups (name, code, level, workspace_id, description, status)
SELECT 'System Administrators', 'sys_admin', 1, w.id, 'Root Admin', 'active'
FROM workspaces w WHERE w.code = 'SYS';

INSERT INTO user_groups (name, code, level, workspace_id, description, status)
SELECT 'Directors', 'directors', 1, w.id, 'Company Directors', 'active'
FROM workspaces w WHERE w.code = 'NEXTX';

-- 5. Seed Permissions
INSERT INTO permissions (name, code, resource, action, category, is_system) VALUES
('View Users', 'user.view', 'user', 'view', 'User Management', TRUE),
('Create Users', 'user.create', 'user', 'create', 'User Management', TRUE),
('Update Users', 'user.update', 'user', 'update', 'User Management', TRUE),
('Delete Users', 'user.delete', 'user', 'delete', 'User Management', TRUE);

-- 6. Permission Assign (all permissions to all groups)
INSERT INTO group_permissions (group_id, permission_id)
SELECT g.id, p.id FROM user_groups g CROSS JOIN permissions p;

-- 7. Workspace Users
INSERT INTO workspace_users (user_id, workspace_id, is_default, status)
SELECT u.id, w.id, TRUE, 'active'
FROM users u, workspaces w
WHERE u.email = 'admin@system.com' AND w.code = 'SYS';

INSERT INTO workspace_users (user_id, workspace_id, is_default, status)
SELECT u.id, w.id, TRUE, 'active'
FROM users u, workspaces w
WHERE u.email = 'boss@nextx.com' AND w.code = 'NEXTX';

-- 8. Workspace User Groups (gán group cho user qua junction table)
INSERT INTO workspace_user_groups (workspace_user_id, group_id)
SELECT wu.id, ug.id
FROM workspace_users wu
JOIN users u ON u.id = wu.user_id
JOIN workspaces w ON w.id = wu.workspace_id
JOIN user_groups ug ON ug.workspace_id = w.id
WHERE u.email = 'admin@system.com' AND w.code = 'SYS' AND ug.code = 'sys_admin';

INSERT INTO workspace_user_groups (workspace_user_id, group_id)
SELECT wu.id, ug.id
FROM workspace_users wu
JOIN users u ON u.id = wu.user_id
JOIN workspaces w ON w.id = wu.workspace_id
JOIN user_groups ug ON ug.workspace_id = w.id
WHERE u.email = 'boss@nextx.com' AND w.code = 'NEXTX' AND ug.code = 'directors';

SELECT 'IAM Database v7.0 Migration Completed' as status;
