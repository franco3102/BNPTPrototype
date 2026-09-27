-- ============================================================
-- BNPT IPDR Vector Filtering Engine - Database Schema (MySQL 8)
-- ============================================================
-- Struktur mendukung:
--   1. Autentikasi user + role (Admin, Maker, Checker, Viewer)
--   2. Permission granular PER HALAMAN dan PER AKSI (view/create/edit/delete)
--   3. Override permission per-user di atas default role
--   4. MSISDN Whitelist Management (kuota, masking, status)
--   5. Scheduled Change Management (alur approval 7 tahap)
--   6. SFTP Delivery log
--   7. Audit trail semua aksi penting (maker-checker accountability)
--
-- Engine: InnoDB (wajib untuk foreign key)
-- Charset: utf8mb4 (aman untuk semua karakter, termasuk emoji/simbol)
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
-- 1. ROLES  (Admin, Maker, Checker, Viewer, dst.)
-- ------------------------------------------------------------
CREATE TABLE roles (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(50)  NOT NULL UNIQUE,
  description   VARCHAR(255) NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 2. USERS
-- ------------------------------------------------------------
CREATE TABLE users (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(150) NOT NULL,
  username        VARCHAR(100) NOT NULL UNIQUE,
  email           VARCHAR(150) NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  role_id         INT UNSIGNED NOT NULL,
  status          ENUM('active','inactive') NOT NULL DEFAULT 'active',
  last_login_at   DATETIME NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 3. PAGES  (representasi tiap halaman/menu di portal)
-- ------------------------------------------------------------
CREATE TABLE pages (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  page_key    VARCHAR(50)  NOT NULL UNIQUE,   -- 'dashboard', 'whitelist', 'change-mgmt', 'processing', 'sftp', 'users'
  page_name   VARCHAR(150) NOT NULL,
  sort_order  INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 4. PERMISSIONS  (kombinasi unik page + action)
--    Inilah yang memberi granularitas PER HALAMAN + PER TOMBOL
-- ------------------------------------------------------------
CREATE TABLE permissions (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  page_id     INT UNSIGNED NOT NULL,
  action      ENUM('view','create','edit','delete') NOT NULL,
  UNIQUE KEY uq_permission (page_id, action),
  CONSTRAINT fk_permissions_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 5. ROLE_PERMISSIONS  (default hak akses per role)
-- ------------------------------------------------------------
CREATE TABLE role_permissions (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_id        INT UNSIGNED NOT NULL,
  permission_id  INT UNSIGNED NOT NULL,
  UNIQUE KEY uq_role_permission (role_id, permission_id),
  CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 6. USER_PERMISSIONS  (override per user, di atas default role)
--    is_allowed = 1 -> grant eksplisit meski role tidak punya
--    is_allowed = 0 -> revoke eksplisit meski role punya
--    tidak ada baris -> ikut default role_permissions
-- ------------------------------------------------------------
CREATE TABLE user_permissions (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id        INT UNSIGNED NOT NULL,
  permission_id  INT UNSIGNED NOT NULL,
  is_allowed     TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_user_permission (user_id, permission_id),
  CONSTRAINT fk_up_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_up_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 7. MSISDN_WHITELIST
-- ------------------------------------------------------------
CREATE TABLE msisdn_whitelist (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  msisdn          VARCHAR(20)  NOT NULL,          -- nomor asli, disimpan terenkripsi di level aplikasi
  msisdn_masked   VARCHAR(20)  NOT NULL,          -- '+62 812-****-0456' untuk ditampilkan di UI
  status          ENUM('active','pending','removal') NOT NULL DEFAULT 'pending',
  effective_date  DATE NULL,
  requester_id    INT UNSIGNED NOT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_msisdn (msisdn),
  CONSTRAINT fk_whitelist_requester FOREIGN KEY (requester_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_whitelist_status ON msisdn_whitelist(status);

-- ------------------------------------------------------------
-- 8. CHANGE_REQUESTS  (Scheduled Change Management - 7 status)
-- ------------------------------------------------------------
CREATE TABLE change_requests (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  request_code     VARCHAR(30) NOT NULL UNIQUE,        -- 'WLR-20260923-0012'
  change_type      ENUM('add','remove') NOT NULL,
  payload          JSON NOT NULL,                      -- daftar id/nomor MSISDN yang terdampak
  status           ENUM('draft','submitted','under_review','approved',
                         'scheduled','applying','active','rejected')
                   NOT NULL DEFAULT 'draft',
  scheduled_at     DATETIME NULL,                       -- jadwal eksekusi
  applied_at       DATETIME NULL,
  maker_id         INT UNSIGNED NOT NULL,
  checker_id       INT UNSIGNED NULL,
  rejection_reason VARCHAR(255) NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_change_maker FOREIGN KEY (maker_id) REFERENCES users(id),
  CONSTRAINT fk_change_checker FOREIGN KEY (checker_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_change_status ON change_requests(status);
CREATE INDEX idx_change_scheduled_at ON change_requests(scheduled_at);

-- ------------------------------------------------------------
-- 9. SFTP_DISPATCH_LOGS
-- ------------------------------------------------------------
CREATE TABLE sftp_dispatch_logs (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  batch_id         VARCHAR(40) NOT NULL UNIQUE,   -- 'BATCH-20260925-1400'
  dispatched_at    DATETIME NOT NULL,
  matched_records  INT UNSIGNED NOT NULL DEFAULT 0,
  file_size_bytes  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  destination      VARCHAR(255) NOT NULL,          -- 'sftp://sftp.bnpt.go.id/ipdr/inbound'
  status           ENUM('pending','delivered','failed') NOT NULL DEFAULT 'pending',
  duration_ms      INT UNSIGNED NULL,
  error_message    VARCHAR(255) NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------------------
-- 10. AUDIT_LOGS  (siapa melakukan apa, kapan - wajib untuk BNPT)
-- ------------------------------------------------------------
CREATE TABLE audit_logs (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      INT UNSIGNED NULL,               -- NULL jika aksi sistem otomatis
  action       VARCHAR(100) NOT NULL,           -- 'APPROVE_CHANGE_REQUEST', 'LOGIN', 'DELETE_USER', dll
  target_type  VARCHAR(50) NULL,                -- 'change_request', 'msisdn_whitelist', 'user'
  target_id    VARCHAR(50) NULL,
  detail       JSON NULL,
  ip_address   VARCHAR(45) NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX idx_audit_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_target ON audit_logs(target_type, target_id);

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- SEED DATA - Roles, Pages, Permissions, default Role-Permissions
-- ============================================================

INSERT INTO roles (name, description) VALUES
  ('Admin',   'Akses penuh ke seluruh halaman dan aksi'),
  ('Maker',   'Bisa membuat/mengajukan perubahan whitelist, tidak bisa approve'),
  ('Checker', 'Mereview dan menyetujui/menolak perubahan yang diajukan Maker'),
  ('Viewer',  'Hanya bisa melihat, tidak ada aksi create/edit/delete');

INSERT INTO pages (page_key, page_name, sort_order) VALUES
  ('dashboard',    'Dashboard',                        1),
  ('whitelist',    'MSISDN Whitelist Management',      2),
  ('change-mgmt',  'Scheduled Change Management',      3),
  ('processing',   'IPDR Processing Monitoring',       4),
  ('sftp',         'SFTP Delivery Monitoring',         5),
  ('users',        'User Management',                  6);

-- Generate permission per halaman x per aksi (view/create/edit/delete)
INSERT INTO permissions (page_id, action)
SELECT p.id, a.action
FROM pages p
CROSS JOIN (
  SELECT 'view' AS action UNION ALL SELECT 'create' UNION ALL SELECT 'edit' UNION ALL SELECT 'delete'
) a;

-- Admin: semua permission
INSERT INTO role_permissions (role_id, permission_id)
SELECT (SELECT id FROM roles WHERE name = 'Admin'), id FROM permissions;

-- Maker: view semua halaman + create di whitelist & change-mgmt
INSERT INTO role_permissions (role_id, permission_id)
SELECT (SELECT id FROM roles WHERE name = 'Maker'), pm.id
FROM permissions pm
JOIN pages pg ON pg.id = pm.page_id
WHERE pm.action = 'view'
   OR (pg.page_key IN ('whitelist', 'change-mgmt') AND pm.action = 'create');

-- Checker: view semua halaman + edit di change-mgmt (approve/reject)
INSERT INTO role_permissions (role_id, permission_id)
SELECT (SELECT id FROM roles WHERE name = 'Checker'), pm.id
FROM permissions pm
JOIN pages pg ON pg.id = pm.page_id
WHERE pm.action = 'view'
   OR (pg.page_key = 'change-mgmt' AND pm.action = 'edit');

-- Viewer: view semua halaman saja
INSERT INTO role_permissions (role_id, permission_id)
SELECT (SELECT id FROM roles WHERE name = 'Viewer'), id
FROM permissions WHERE action = 'view';
